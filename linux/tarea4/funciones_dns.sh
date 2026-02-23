#!/bin/bash
# Archivo: funciones_dns.sh

instalar_dns() {
    log_info "Verificando instalación de BIND9 (DNS)..."
    verificar_ip_fija
    
    if ! dpkg -s bind9 >/dev/null 2>&1; then
        log_warn "Instalando BIND9 y utilidades (bind9, bind9utils, bind9-doc)..."
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9utils bind9-doc dnsutils
        if [ $? -eq 0 ]; then 
            log_ok "BIND9 instalado correctamente."
            # Asegurar que resolv.conf no estorbe localmente
            systemctl enable bind9
            systemctl start bind9
        else 
            log_error "Fallo al instalar BIND9."
        fi
    else
        log_ok "BIND9 ya está instalado (Idempotencia)."
    fi
    read -p "Enter para continuar..."
}

agregar_dominio() {
    log_info "--- GESTOR ABC: AGREGAR DOMINIO ---"
    read -p "Ingresa el nombre del dominio (ej. reprobados.com): " DOMINIO
    if [ -z "$DOMINIO" ]; then log_error "Dominio inválido."; return; fi

    ZONAS_CONF="/etc/bind/named.conf.local"
    ARCHIVO_ZONA="/var/cache/bind/db.$DOMINIO"

    if grep -q "zone \"$DOMINIO\"" "$ZONAS_CONF"; then
        log_warn "El dominio $DOMINIO ya existe en la configuración. (Idempotencia)"
        read -p "Enter para continuar..."
        return
    fi

    # =================================================================
    # CANDADO DE IP: IMPIDE GUARDAR HASTA QUE SEA 100% VALIDA
    while true; do
        read -p "Ingresa la IP que resolverá este dominio (ej. 55.55.55.55): " IP_SERVIDOR
        
        if [ -z "$IP_SERVIDOR" ]; then
            echo -e "\e[31m[ERROR] No puedes dejarlo vacío. Intenta de nuevo.\e[0m"
            continue
        fi

        if [[ "$IP_SERVIDOR" == "0.0.0.0" || "$IP_SERVIDOR" == "127.0.0.1" || "$IP_SERVIDOR" == "255.255.255.255" ]]; then
            echo -e "\e[31m[ERROR] IP $IP_SERVIDOR NO permitida. Escribe una IP real.\e[0m"
            continue
        fi

        if [[ $IP_SERVIDOR =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
            if [[ ${BASH_REMATCH[1]} -le 255 && ${BASH_REMATCH[2]} -le 255 && ${BASH_REMATCH[3]} -le 255 && ${BASH_REMATCH[4]} -le 255 ]]; then
                break 
            else
                echo -e "\e[31m[ERROR] Ningún número de la IP puede ser mayor a 255.\e[0m"
            fi
        else
            echo -e "\e[31m[ERROR] Formato inválido. Escribe 4 números separados por puntos.\e[0m"
        fi
    done
    # =================================================================

    log_info "1. Declarando Zona Directa en $ZONAS_CONF..."
    cat <<EOF >> "$ZONAS_CONF"
zone "$DOMINIO" {
    type master;
    file "$ARCHIVO_ZONA";
};
EOF

    log_info "2. Generando archivo de Zona Directa ($ARCHIVO_ZONA)..."
    cat <<EOF > "$ARCHIVO_ZONA"
\$TTL    604800
@       IN      SOA     ns1.$DOMINIO. admin.$DOMINIO. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMINIO.
@       IN      A       $IP_SERVIDOR
ns1     IN      A       $IP_SERVIDOR
www     IN      CNAME   $DOMINIO.
EOF

    # =================================================================
    # 3. CREACIÓN DE ZONA INVERSA (PTR) AUTOMÁTICA
    # =================================================================
    # Extraemos los octetos de la IP
    IFS='.' read -r ip1 ip2 ip3 ip4 <<< "$IP_SERVIDOR"
    
    # Invertimos los 3 primeros octetos para el estándar in-addr.arpa
    RED_INVERSA="${ip3}.${ip2}.${ip1}.in-addr.arpa"
    ARCHIVO_ZONA_INVERSA="/var/cache/bind/db.${ip1}.${ip2}.${ip3}"

    log_info "3. Declarando Zona Inversa ($RED_INVERSA)..."
    # Solo la declara en named.conf.local si no existe aún
    if ! grep -q "zone \"$RED_INVERSA\"" "$ZONAS_CONF"; then
        cat <<EOF >> "$ZONAS_CONF"
zone "$RED_INVERSA" {
    type master;
    file "$ARCHIVO_ZONA_INVERSA";
};
EOF
    fi

    log_info "4. Generando archivo PTR..."
    # Si el archivo inverso no existe, creamos su cabecera SOA
    if [ ! -f "$ARCHIVO_ZONA_INVERSA" ]; then
        cat <<EOF > "$ARCHIVO_ZONA_INVERSA"
\$TTL    604800
@       IN      SOA     ns1.$DOMINIO. admin.$DOMINIO. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      ns1.$DOMINIO.
EOF
    fi
    
    # Inyectamos el registro PTR apuntando el último octeto de la IP hacia el dominio
    # (Ojo: En BIND9 los dominios deben terminar con un punto final)
    if ! grep -q "^$ip4 .* PTR .* $DOMINIO\.$" "$ARCHIVO_ZONA_INVERSA"; then
        echo "$ip4      IN      PTR     $DOMINIO." >> "$ARCHIVO_ZONA_INVERSA"
    fi
    # =================================================================

    log_ok "Zonas (Directa/Inversa) y Registros (A, CNAME, PTR) creados exitosamente."
    systemctl restart bind9
    read -p "Enter para continuar..."
}

eliminar_dominio() {
    log_info "--- GESTOR ABC: ELIMINAR DOMINIO ---"
    ZONAS_CONF="/etc/bind/named.conf.local"
    
    echo "Dominios actuales configurados:"
    grep "zone " "$ZONAS_CONF" | awk -F'"' '{print "- "$2}'
    echo "--------------------------------"
    
    read -p "Ingresa el nombre exacto del dominio a eliminar: " DOMINIO
    if [ -z "$DOMINIO" ]; then return; fi

    ARCHIVO_ZONA="/var/cache/bind/db.$DOMINIO"

    if grep -q "zone \"$DOMINIO\"" "$ZONAS_CONF"; then
        
        sed -i "/zone \"$DOMINIO\" {/,/};/d" "$ZONAS_CONF"
        log_ok "Dominio borrado de $ZONAS_CONF."
        
        if [ -f "$ARCHIVO_ZONA" ]; then
            rm "$ARCHIVO_ZONA"
            log_ok "Archivo de zona físico eliminado."
        fi
        systemctl restart bind9
    else
        log_error "El dominio no existe en la configuración."
    fi
    read -p "Enter para continuar..."
}
# --- GESTOR ABC: LISTAR DOMINIOS ACTIVOS ---
listar_dominios() {
    log_info "--- GESTOR ABC: CONSULTA DE DOMINIOS ACTIVOS ---"
    
    # Verificamos si BIND9 existe
    if [ ! -f /etc/bind/named.conf.local ]; then
        log_error "El servidor BIND9 no está instalado o configurado."
        read -p "Enter para continuar..."
        return
    fi

    # Contamos cuántas zonas hay registradas
    TOTAL_DOMINIOS=$(grep -c "zone " /etc/bind/named.conf.local)
    
    if [ "$TOTAL_DOMINIOS" -eq 0 ]; then
        echo -e "\n[INFO] No hay ningún dominio registrado actualmente en el servidor."
    else
        echo -e "\n=================================================="
        printf "%-30s | %-15s\n" "DOMINIO" "IP DEL SERVIDOR"
        echo "-------------------------------+------------------"
        
        # Extraemos los dominios y buscamos su IP en su archivo de configuración
        grep "zone " /etc/bind/named.conf.local | awk -F'"' '{print $2}' | while read dominio; do
            archivo_zona=$(grep -A 2 "zone \"$dominio\"" /etc/bind/named.conf.local | grep "file" | awk -F'"' '{print $2}')
            
            if [ -f "$archivo_zona" ]; then
                # Busca el registro A principal (excluyendo el de www)
                ip=$(grep -w "A" "$archivo_zona" | grep -v "www" | head -n 1 | awk '{print $NF}')
                printf "%-30s | %-15s\n" "$dominio" "$ip"
            else
                printf "%-30s | %-15s\n" "$dominio" "[Error: Sin archivo]"
            fi
        done
        echo "=================================================="
    fi
    
    echo ""
    read -p "Enter para continuar..."
}

validar_dns() {
    log_info "--- MÓDULO DE PRUEBAS Y VALIDACIÓN ---"
    read -p "Ingresa el dominio a validar (ej. reprobados.com): " DOMINIO
    ARCHIVO_ZONA="/var/cache/bind/db.$DOMINIO"

    log_info "1. Verificando Sintaxis Global (named-checkconf)..."
    if named-checkconf; then 
        log_ok "Sintaxis del servidor correcta."
    else 
        log_error "Errores de sintaxis detectados."
    fi

    log_info "2. Verificando Zona Específica (named-checkzone)..."
    if [ -f "$ARCHIVO_ZONA" ]; then
        if named-checkzone "$DOMINIO" "$ARCHIVO_ZONA"; then
            log_ok "Archivo de zona válido."
        else
            log_error "Errores en el archivo de zona."
        fi
    else
        log_error "No se encontró el archivo $ARCHIVO_ZONA"
    fi

    log_info "3. Prueba de Resolución Local (nslookup y ping)..."
    # Forzamos a que pregunte al localhost para evitar que el DNS externo responda
    nslookup "$DOMINIO" 127.0.0.1
    echo "---------------------------"
    ping -c 2 "www.$DOMINIO"

    read -p "Enter para continuar..."
}

desinstalar_dns() {
    read -p "¿Eliminar Servidor DNS (BIND9) y todos sus archivos? (s/n): " CONF
    if [[ "$CONF" == "s" || "$CONF" == "S" ]]; then
        apt-get remove --purge -y bind9 bind9utils bind9-doc
        rm -rf /etc/bind
        rm -rf /var/cache/bind
        log_ok "DNS Desinstalado."
    fi
    read -p "Enter para continuar..."
}