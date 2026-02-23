#!/bin/bash
# Archivo: funciones_dhcp.sh

instalar_dhcp() {
    log_info "Verificando instalación de DHCP..."
    if ! dpkg -s isc-dhcp-server >/dev/null 2>&1; then
        log_warn "Instalando isc-dhcp-server..."
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server
        if [ $? -eq 0 ]; then log_ok "Instalado correctamente."; else log_error "Fallo al instalar."; fi
    else
        log_ok "El software DHCP ya estaba instalado (Idempotencia)."
    fi
    read -p "Enter para continuar..."
}

configurar_scope() {
    log_info "--- CONFIGURACIÓN DEL ÁMBITO ---"
    echo "Interfaces disponibles:"
    ip link show | grep "enp" | awk -F: '{print $2}' | tr -d ' '
    echo "------------------------"
    read -p "Nombre del Adaptador (ej. enp0s8): " INT_IFACE
    if [ -z "$INT_IFACE" ]; then log_error "Interfaz vacía."; return; fi

    RANGE_START=$(pedir_ip_custom "IP Inicio Rango (Será la IP del Servidor)")
    IFS='.' read -r s1 s2 s3 s4 <<< "$RANGE_START"
    NETMASK=$(pedir_ip_custom "Mascara de Subred (ej. 255.255.255.0)")
    IFS='.' read -r m1 m2 m3 m4 <<< "$NETMASK"

    while true; do
        RANGE_END=$(pedir_ip_custom "IP Fin Rango")
        IFS='.' read -r e1 e2 e3 e4 <<< "$RANGE_END"
        if [[ "$s1.$s2.$s3" == "$e1.$e2.$e3" ]] && [ "$e4" -le "$s4" ]; then
            log_error "Error: La IP Final debe ser mayor que la Inicial."
            continue
        fi
        break
    done

    GATEWAY=$(pedir_ip_custom "Gateway (Enter para omitir)" "opcional")
    DNS_INT=$(pedir_ip_custom "DNS (Recomendado: IP Servidor)" "opcional")
    
    read -p "Nombre del Scope [local]: " SCOPE_NAME; [ -z "$SCOPE_NAME" ] && SCOPE_NAME="local"
    read -p "Tiempo Lease (seg) [600]: " LEASE_TIME; [ -z "$LEASE_TIME" ] && LEASE_TIME=600

    n1=$((s1 & m1)); n2=$((s2 & m2)); n3=$((s3 & m3)); n4=$((s4 & m4))
    NETWORK_ID="$n1.$n2.$n3.$n4"
    SERVER_IP=$RANGE_START
    DHCP_START_IP="$s1.$s2.$s3.$((s4 + 1))"

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
    ip link set $INT_IFACE up

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

    sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$INT_IFACE\"/" /etc/default/isc-dhcp-server
    systemctl restart isc-dhcp-server
    if systemctl is-active --quiet isc-dhcp-server; then log_ok "Corriendo exitosamente."; else log_error "Error iniciando."; fi
    read -p "Enter para continuar..."
}

monitorear_clientes() {
    log_info "Clientes Conectados:"
    LEASE_FILE="/var/lib/dhcp/dhcpd.leases"
    if [ -f "$LEASE_FILE" ]; then grep -E "lease |hardware ethernet|client-hostname" "$LEASE_FILE" | tail -n 15; else log_warn "Sin archivo de leases."; fi
    read -p "Enter para continuar..."
}

desinstalar_dhcp() {
    read -p "¿Eliminar Servidor DHCP? (s/n): " CONF
    if [[ "$CONF" == "s" || "$CONF" == "S" ]]; then apt-get remove --purge -y isc-dhcp-server; log_ok "Desinstalado."; fi
    read -p "Enter para continuar..."
}