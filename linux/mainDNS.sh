#!/bin/bash


# Cargar el archivo de funciones
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$DIR/functions_linuxDNS.sh" ]; then
    source "$DIR/functions_linuxDNS.sh"
else
    echo "Error: No se encontró functions_linuxDNS.sh en el directorio $DIR"
    exit 1
fi

# --- SUBMENÚ DHCP ---
submenu_dhcp() {
    while true; do
        clear
        echo "=================================================="
        echo "             SUBMENÚ: CONFIGURAR DHCP             "
        echo "=================================================="
        echo "1. Instalar Servidor DHCP"
        echo "2. Configurar Scope (Red + DHCP)"
        echo "3. Monitorear clientes (Leases)"
        echo "4. Desinstalar DHCP"
        echo "5. Volver al Menú Principal"
        echo "=================================================="
        read -p "Selecciona una opción: " OPCION_DHCP

        case $OPCION_DHCP in
            1) instalar_dhcp ;;
            2) configurar_scope ;;
            3) monitorear_clientes ;;
            4) desinstalar_dhcp ;;
            5) break ;;
            *) echo "Opción no válida."; sleep 1 ;;
        esac
    done
}

# --- SUBMENÚ DNS ---
submenu_dns() {
    while true; do
        clear
        echo "=================================================="
        echo "             SUBMENÚ: CONFIGURAR DNS              "
        echo "=================================================="
        echo "1. Instalar Servidor DNS (BIND9)"
        echo "2. Gestor ABC: Agregar nuevo Dominio"
        echo "3. Gestor ABC: Eliminar Dominio"
        echo "4. Gestor ABC: Listar Dominios Activos"
        echo "5. Validar Sintaxis y Pruebas DNS"
        echo "6. Desinstalar DNS"
        echo "7. Volver al Menú Principal"
        echo "=================================================="
        read -p "Selecciona una opción: " OPCION_DNS

        case $OPCION_DNS in
            1) instalar_dns ;;
            2) agregar_dominio ;;
            3) eliminar_dominio ;;
            4) listar_dominios ;;
            5) validar_dns ;;
            6) desinstalar_dns ;;
            7) break ;;
            *) echo "Opción no válida."; sleep 1 ;;
        esac
    done
}

# --- MENÚ PRINCIPAL ---
while true; do
    clear
    echo "=================================================="
    echo "         GESTOR UNIFICADO (DHCP & DNS)            "
    echo "=================================================="
    echo "1. Configurar DHCP"
    echo "2. Configurar DNS"
    echo "3. Verificar estado de los servicios"
    echo "4. Salir"
    echo "=================================================="
    read -p "Selecciona una opción: " OPCION_MAIN

    case $OPCION_MAIN in
        1) submenu_dhcp ;;
        2) submenu_dns ;;
        3) verificar_servicios ;;
        4) echo -e "\nSaliendo del Gestor. ¡Hasta pronto!\n"; exit 0 ;;
        *) echo "Opción no válida."; sleep 1 ;;
    esac
done