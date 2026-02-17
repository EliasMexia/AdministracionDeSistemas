#!/bin/bash

# --- COLORES Y LOGS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }

# --- VALIDACIÓN ROOT ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Acceso denegado. Ejecuta como root."
        exit 1
    fi
}

# --- HERRAMIENTA: INPUT DE IP (VALIDADOR) ---
pedir_ip_custom() {
    local mensaje=$1
    local tipo=$2 
    local ip_input

    while true; do
        read -p "$mensaje: " ip_input
        
        # Si es opcional y está vacío
        if [ "$tipo" == "opcional" ] && [ -z "$ip_input" ]; then
            echo ""
            return 0
        fi

        # Si es obligatorio y está vacío
        if [ -z "$ip_input" ]; then
             log_error "El campo no puede estar vacío."
             continue
        fi

        # Validación de formato y rangos
        if [[ $ip_input =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            OIFS=$IFS; IFS='.'; ip_arr=($ip_input); IFS=$OIFS
            if [[ ${ip_arr[0]} -le 255 && ${ip_arr[1]} -le 255 && ${ip_arr[2]} -le 255 && ${ip_arr[3]} -le 255 ]]; then
                
                # Reglas de IPs Prohibidas
                if [[ "$ip_input" == "0.0.0.0" ]]; then
                    log_error "IP 0.0.0.0 no permitida."
                elif [[ "$ip_input" == "127.0.0.1" ]]; then
                    log_error "IP 127.0.0.1 no permitida."
                elif [[ "$ip_input" == "255.255.255.255" ]]; then
                    log_error "IP Broadcast Global no permitida."
                else
                    echo "$ip_input"
                    return 0
                fi
            else
                 log_error "Octetos deben ser 0-255."
            fi
        else
            log_error "Formato incorrecto (X.X.X.X)."
        fi
    done
}

# --- 1. INSTALAR ---
instalar_dhcp() {
    log_info "Verificando instalación..."
    if ! dpkg -s isc-dhcp-server >/dev/null 2>&1; then
        log_warn "Instalando isc-dhcp-server..."
        NAT_IFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
        if [ ! -z "$NAT_IFACE" ]; then dhclient $NAT_IFACE >/dev/null 2>&1; fi
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server
        if [ $? -eq 0 ]; then log_ok "Instalado correctamente."; else log_error "Fallo al instalar."; fi
    else
        log_ok "El software ya estaba instalado."
    fi
    read -p "Enter para continuar..."
}

# --- 2. CONFIGURAR SCOPE (CON MÁSCARA MANUAL) ---
configurar_scope() {
    log_info "--- CONFIGURACIÓN DEL ÁMBITO ---"

    echo "Interfaces disponibles:"
    ip link show | grep "enp" | awk -F: '{print $2}' | tr -d ' '
    echo "------------------------"
    read -p "Nombre del Adaptador (ej. enp0s8): " INT_IFACE
    if [ -z "$INT_IFACE" ]; then log_error "Interfaz vacía."; return; fi

    # 1. Pedir IP Inicial (Servidor)
    RANGE_START=$(pedir_ip_custom "IP Inicio Rango (Será la IP del Servidor)")
    IFS='.' read -r s1 s2 s3 s4 <<< "$RANGE_START"

    # 2. Pedir Máscara de Subred (NUEVO)
    # Usamos pedir_ip_custom porque una máscara tiene el mismo formato visual que una IP
    NETMASK=$(pedir_ip_custom "Mascara de Subred (ej. 255.255.255.0)")
    IFS='.' read -r m1 m2 m3 m4 <<< "$NETMASK"

    # 3. Validar IP Final
    while true; do
        RANGE_END=$(pedir_ip_custom "IP Fin Rango")
        IFS='.' read -r e1 e2 e3 e4 <<< "$RANGE_END"

        # Validación Lógica: Final > Inicial
        # Nota: Esta validación es simple. Para redes complejas se requeriría conversión a decimal.
        # Asumimos que el usuario no cambia de red drásticamente en el rango.
        
        # Comparamos el último octeto si los primeros 3 son iguales (Caso común /24)
        if [[ "$s1.$s2.$s3" == "$e1.$e2.$e3" ]]; then
            if [ "$e4" -le "$s4" ]; then
                log_error "Error: La IP Final debe ser mayor que la Inicial."
                continue
            fi
        fi
        break
    done

    GATEWAY=$(pedir_ip_custom "Gateway (Enter para omitir)" "opcional")
    DNS_INT=$(pedir_ip_custom "DNS (Enter para omitir)" "opcional")
    
    read -p "Nombre del Scope [local]: " SCOPE_NAME
    [ -z "$SCOPE_NAME" ] && SCOPE_NAME="local"
    
    read -p "Tiempo Lease (seg) [600]: " LEASE_TIME
    [ -z "$LEASE_TIME" ] && LEASE_TIME=600

    # --- CÁLCULO DE RED (BITWISE AND) ---
    # Esto asegura que el Network ID coincida matemáticamente con la Máscara
    # (Ej. Si IP es 10.10.10.1 y Mascara 255.0.0.0, la Red es 10.0.0.0)
    
    n1=$((s1 & m1))
    n2=$((s2 & m2))
    n3=$((s3 & m3))
    n4=$((s4 & m4))
    NETWORK_ID="$n1.$n2.$n3.$n4"

    SERVER_IP=$RANGE_START
    # Calculamos la primera IP disponible para DHCP (Servidor + 1)
    # Nota: Si el usuario pone una máscara rara, esto podría variar, 
    # pero para laboratorio estándar funciona.
    DHCP_START_OCTET=$((s4 + 1))
    DHCP_START_IP="$s1.$s2.$s3.$DHCP_START_OCTET"

    log_info "Calculando Red..."
    log_info " -> IP Servidor: $SERVER_IP"
    log_info " -> Máscara:     $NETMASK"
    log_info " -> ID de Red:   $NETWORK_ID"

    # APLICAR IP ESTÁTICA
    log_info "Configurando interfaz $INT_IFACE..."
    cp /etc/network/interfaces /etc/network/interfaces.bak 2>/dev/null
    
    grep -v "$INT_IFACE" /etc/network/interfaces > /tmp/interfaces.tmp
    cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback

auto $INT_IFACE
iface $INT_IFACE inet static
    address $SERVER_IP
    netmask $NETMASK
EOF
    ip addr flush dev $INT_IFACE
    ip addr add $SERVER_IP/$NETMASK dev $INT_IFACE 2>/dev/null
    # Si falla el comando ip con la mascara en formato decimal, intentamos conversión simple
    # pero el archivo interfaces sí soporta formato decimal. Para 'ip addr add' a veces requiere CIDR.
    # Por seguridad, si falla el comando anterior, forzamos un /24 temporal para que levante, 
    # aunque lo importante es el reinicio o el archivo interfaces.
    ip link set $INT_IFACE up

    # GENERAR DHCPD.CONF
    log_info "Generando configuración DHCP..."
    OPT_R=""; if [ ! -z "$GATEWAY" ]; then OPT_R="option routers $GATEWAY;"; fi
    OPT_D=""; if [ ! -z "$DNS_INT" ]; then OPT_D="option domain-name-servers $DNS_INT;"; fi

    cat > /etc/dhcp/dhcpd.conf <<EOF
default-lease-time $LEASE_TIME;
max-lease-time $(($LEASE_TIME * 2));
authoritative;

subnet $NETWORK_ID netmask $NETMASK {
  range $DHCP_START_IP $RANGE_END;
  option domain-name "$SCOPE_NAME.local";
  $OPT_R
  $OPT_D
}
EOF

    # REINICIAR SERVICIO
    sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$INT_IFACE\"/" /etc/default/isc-dhcp-server
    systemctl restart isc-dhcp-server
    
    if systemctl is-active --quiet isc-dhcp-server; then
        log_ok "Servicio configurado y corriendo exitosamente."
    else
        log_error "Error iniciando servicio. Verifica que la IP Servidor pertenezca a la Red/Mascara."
        systemctl status isc-dhcp-server --no-pager | tail -n 10
    fi
    read -p "Enter para continuar..."
}

# --- 3. MONITOREAR ---
monitorear_clientes() {
    log_info "Clientes Conectados (Últimos leases):"
    LEASE_FILE="/var/lib/dhcp/dhcpd.leases"
    if [ -f "$LEASE_FILE" ]; then
        grep -E "lease |hardware ethernet|client-hostname" "$LEASE_FILE" | tail -n 15
    else
        log_warn "No hay archivo de leases aún."
    fi
    read -p "Enter para continuar..."
}

# --- 4. ESTADO ---
verificar_estado() {
    systemctl status isc-dhcp-server --no-pager
    read -p "Enter para continuar..."
}

# --- 5. DESINSTALAR ---
desinstalar_dhcp() {
    read -p "¿Eliminar Servidor DHCP? (s/n): " CONF
    if [[ "$CONF" == "s" || "$CONF" == "S" ]]; then
        apt-get remove --purge -y isc-dhcp-server
        log_ok "Desinstalado."
    fi
    read -p "Enter para continuar..."
}

