#!/bin/bash
# Archivo: main.sh
# Descripción: Script principal y punto de entrada único (Práctica 4)

# --- 1. IMPORTACIÓN DE LIBRERÍAS (MODULARIZACIÓN) ---
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/funciones_core.sh"
source "$DIR/funciones_practica1.sh"
source "$DIR/funciones_ssh.sh"
source "$DIR/funciones_dhcp.sh"
source "$DIR/funciones_dns.sh"

# --- 2. VALIDACIONES DE SEGURIDAD ---
check_root

# --- 3. HITO CRÍTICO (Práctica 4): Habilitar SSH al arranque ---
configurar_ssh

# --- 4. INTEGRACIÓN DE SUBMENÚS ---
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

# --- 5. MENÚ PRINCIPAL ---
while true; do
    clear
    echo "=================================================="
    echo "         GESTOR UNIFICADO (DHCP, DNS, SSH)        "
    echo "=================================================="
    echo "1. Práctica 1: Estado del Sistema"
    echo "2. Práctica 2: Configurar DHCP"
    echo "3. Práctica 3: Configurar DNS"
    echo "4. Verificar estado de los servicios (DHCP/DNS)"
    echo "5. Salir"
    echo "=================================================="
    read -p "Selecciona una opción: " OPCION_MAIN

    case $OPCION_MAIN in
        1) verificar_estado ;;
        2) submenu_dhcp ;;
        3) submenu_dns ;;
        4) verificar_servicios ;;
        5) echo -e "\nSaliendo del Gestor. ¡Hasta pronto!\n"; exit 0 ;;
        *) echo "Opción no válida."; sleep 1 ;;
    esac
done