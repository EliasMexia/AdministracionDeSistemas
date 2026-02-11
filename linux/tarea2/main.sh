#!/bin/bash

# 1. CARGAR FUNCIONES
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$DIR/functions_linux.sh" ]; then
    source "$DIR/functions_linux.sh"
else
    echo "ERROR: No encuentro functions_linux.sh"
    exit 1
fi

# 2. VERIFICACIÓN INICIAL
check_root

# 3. BUCLE INFINITO (MENÚ)
while true; do
    clear
    echo "========================================"
    echo "   GESTOR DHCP DEBIAN (LINUX)           "
    echo "========================================"
    echo "1. Instalar Servidor DHCP"
    echo "2. Configurar Scope (Red + DHCP)"
    echo "3. Monitorear clientes"
    echo "4. Verificar estado del servicio"
    echo "5. Desinstalar Servidor DHCP"
    echo "6. Salir"
    echo "========================================"
    read -p "Selecciona: " OPCION

    case $OPCION in
        1) instalar_dhcp ;;
        2) configurar_scope ;;
        3) monitorear_clientes ;;
        4) verificar_estado ;;
        5) desinstalar_dhcp ;;
        6) 
           log_ok "Saliendo..."
           exit 0 
           ;;
        *) 
           log_error "Opción inválida." 
           sleep 1
           ;;
    esac
done