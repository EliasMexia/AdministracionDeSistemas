#!/bin/bash
# Archivo: funciones_core.sh
# Descripción: Utilidades globales, validadores y configuración de red base.

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
        
        if [ "$tipo" == "opcional" ] && [ -z "$ip_input" ]; then
            echo ""
            return 0
        fi

        if [ -z "$ip_input" ]; then
             log_error "El campo no puede estar vacío."
             continue
        fi

        if [[ $ip_input =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            OIFS=$IFS; IFS='.'; ip_arr=($ip_input); IFS=$OIFS
            if [[ ${ip_arr[0]} -le 255 && ${ip_arr[1]} -le 255 && ${ip_arr[2]} -le 255 && ${ip_arr[3]} -le 255 ]]; then
                if [[ "$ip_input" == "0.0.0.0" || "$ip_input" == "127.0.0.1" || "$ip_input" == "255.255.255.255" ]]; then
                    log_error "IP no permitida (0.0.0.0, 127.0.0.1 o Broadcast)."
                    continue
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

# --- VERIFICACIÓN DE IP ESTÁTICA ---
verificar_ip_fija() {
    log_info "Comprobando configuración de red..."
    if grep -q "inet static" /etc/network/interfaces; then
        log_ok "Se detectó configuración de IP estática en el sistema."
    else
        log_warn "El servidor NO tiene una IP estática configurada permanentemente."
        read -p "¿Deseas configurar una IP estática ahora? (s/n): " resp
        if [[ "$resp" == "s" || "$resp" == "S" ]]; then
            echo "Interfaces disponibles:"
            ip link show | grep "enp" | awk -F: '{print $2}' | tr -d ' '
            read -p "Nombre del Adaptador (ej. enp0s8): " INT_IFACE
            if [ -z "$INT_IFACE" ]; then log_error "Interfaz vacía."; return; fi
            
            IP_NUEVA=$(pedir_ip_custom "IP Estática del Servidor")
            MASCARA=$(pedir_ip_custom "Máscara de Subred (ej. 255.255.255.0)")
            GW=$(pedir_ip_custom "Gateway (Enter para omitir)" "opcional")

            cp /etc/network/interfaces /etc/network/interfaces.bak
            cat > /etc/network/interfaces <<EOF
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback

auto $INT_IFACE
iface $INT_IFACE inet static
    address $IP_NUEVA
    netmask $MASCARA
EOF
            if [ ! -z "$GW" ]; then echo "    gateway $GW" >> /etc/network/interfaces; fi
            
            ip addr flush dev $INT_IFACE
            ip addr add $IP_NUEVA/$MASCARA dev $INT_IFACE 2>/dev/null
            ip link set $INT_IFACE up
            log_ok "IP Estática $IP_NUEVA configurada correctamente."
        fi
    fi
}

# --- VERIFICAR ESTADO DE AMBOS SERVICIOS ---
verificar_servicios() {
    clear
    log_info "--- ESTADO DE LOS SERVICIOS ---"
    
    echo -n "1. Servidor DHCP (isc-dhcp-server): "
    if systemctl is-active --quiet isc-dhcp-server; then echo -e "\e[32m[CORRIENDO]\e[0m"; else echo -e "\e[31m[DETENIDO / NO INSTALADO]\e[0m"; fi
    
    echo -n "2. Servidor DNS (bind9): "
    if systemctl is-active --quiet bind9; then echo -e "\e[32m[CORRIENDO]\e[0m"; else echo -e "\e[31m[DETENIDO / NO INSTALADO]\e[0m"; fi
    
    echo "-------------------------------------"
    read -p "Enter para volver al menú..."
}