#!/bin/bash
# ==========================================
# PROYECTO INTEGRADOR - ADMINISTRACIÓN DE SISTEMAS
# ESTRUCTURA MODULAR PARA TAREAS 1, 2, 3 Y 4
# ==========================================

# 1. Carga de librerías
source ./funciones_core.sh
source ./funciones_practica1.sh
source ./funciones_dhcp.sh
source ./funciones_dns.sh
source ./funciones_ssh.sh

# 2. Validación de seguridad
check_root

# Función para limpieza total (Evita el doble menú en SSH)
limpiar_pantalla() {
    # Esta secuencia limpia el búfer y posiciona el cursor al inicio
    printf "\033c"
}

# --- SUBMENÚ: TAREA 1 (Diagnóstico) ---
menu_tarea1() {
    while true; do
        limpiar_pantalla
        echo "========================================="
        echo "   TAREA 1: DIAGNÓSTICO Y UTILIDADES    "
        echo "========================================="
        echo "1) Ver Estado General (Hostname, IP, Disco)"
        echo "2) Actualizar Repositorios"
        echo "3) Instalar Herramientas Base"
        echo "4) Volver al Menú Principal"
        read -p "Opción: " T1
        case $T1 in
            1) verificar_estado ;; 
            2) actualizar_repositorios ;; 
            3) instalar_herramientas_base ;; 
            4) break ;;
        esac
    done
}

# --- SUBMENÚ: TAREA 2 (DHCP) ---
menu_dhcp() {
    while true; do
        limpiar_pantalla
        echo "========================================="
        echo "   TAREA 2: GESTIÓN DE SERVIDOR DHCP    "
        echo "========================================="
        echo "1) Instalar Servidor DHCP"
        echo "2) Configurar Ámbito (Scope)"
        echo "3) Monitorear Clientes Conectados"
        echo "4) Desinstalar Servidor DHCP"
        echo "5) Volver al Menú de Red"
        read -p "Opción: " TDHCP
        case $TDHCP in
            1) instalar_dhcp ;; 
            2) configurar_scope ;; 
            3) monitorear_clientes ;; 
            4) desinstalar_dhcp ;; 
            5) break ;;
        esac
    done
}

# --- SUBMENÚ: TAREA 3 (DNS) ---
menu_dns() {
    while true; do
        limpiar_pantalla
        echo "========================================="
        echo "   TAREA 3: GESTIÓN DE SERVIDOR DNS     "
        echo "========================================="
        echo "1) Instalar BIND9"
        echo "2) Agregar Nuevo Dominio (ABC)"
        echo "3) Consultar Dominios Activos"
        echo "4) Eliminar Dominio"
        echo "5) Validar Configuración de Zonas"
        echo "6) Desinstalar BIND9"
        echo "7) Volver al Menú de Red"
        read -p "Opción: " TDNS
        case $TDNS in
            1) instalar_dns ;; 
            2) agregar_dominio ;; 
            3) listar_dominios ;; 
            4) eliminar_dominio ;; 
            5) validar_dns ;; 
            6) desinstalar_dns ;; 
            7) break ;;
        esac
    done
}

# --- MENÚ INTERMEDIO: SELECCIÓN DE SERVICIO ---
menu_servicios_red() {
    while true; do
        limpiar_pantalla
        echo "========================================="
        echo "   ¿QUÉ SERVICIO DESEA CONFIGURAR?      "
        echo "========================================="
        echo "1) DHCP (Tarea 2)"
        echo "2) DNS  (Tarea 3)"
        echo "3) Ver Status de ambos servicios"
        echo "4) Volver al Menú Principal"
        read -p "Seleccione [1-4]: " TS
        case $TS in
            1) menu_dhcp ;;
            2) menu_dns ;;
            3) verificar_servicios ;; 
            4) break ;;
        esac
    done
}

# =======================================================
# LÓGICA DE ENTRADA: MODO SERVIDOR VS MODO CLIENTE
# =======================================================
limpiar_pantalla
echo "======================================================="
echo "   SISTEMA DE ADMINISTRACIÓN - PROYECTO INTEGRADOR     "
echo "======================================================="
echo "S) Modo SERVIDOR (Activar SSH para acceso remoto)"
echo "C) Modo CLIENTE  (Acceder al panel de administración)"
echo "======================================================="
read -p "Seleccione el entorno [S/C]: " ENTORNO

if [[ "$ENTORNO" == "S" || "$ENTORNO" == "s" ]]; then
    limpiar_pantalla
    configurar_ssh 
    exit 0
elif [[ "$ENTORNO" == "C" || "$ENTORNO" == "c" ]]; then
    while true; do
        limpiar_pantalla
        echo "======================================================="
        echo "   PANEL CENTRAL DE CONTROL (Modo Cliente)            "
        echo "======================================================="
        echo "1) TAREA 1: Diagnóstico de Sistema"
        echo "2) TAREAS 2 y 3: Configuración de Red (DHCP/DNS)"
        echo "3) Salir"
        echo "======================================================="
        read -p "Opción: " MAIN_OPC
        case $MAIN_OPC in
            1) menu_tarea1 ;;
            2) menu_servicios_red ;;
            3) echo "Cerrando sesión..."; exit 0 ;;
            *) echo "Inválido"; sleep 1 ;;
        esac
    done
else
    echo "Opción inválida. Saliendo..."
    exit 1
fi