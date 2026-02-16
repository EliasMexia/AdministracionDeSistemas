#!/bin/bash

# 1. CARGAR FUNCIONES
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$DIR/functions_linuxDNS.sh" ]; then
    source "$DIR/functions_linuxDNS.sh"
else
    echo "ERROR: No encuentro functions_linux.sh"
    exit 1
fi

# 2. VERIFICACIÓN INICIAL
check_root

# 3. BUCLE INFINITO (MENÚ)
while true; do
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "   GESTOR UNIFICADO (DHCP & DNS)        "
    echo -e "${CYAN}========================================${NC}"
    echo -e "${YELLOW}--- SERVIDOR DHCP ---${NC}"
    echo "1. Instalar Servidor DHCP"
    echo "2. Configurar Scope (Red + DHCP)"
    echo "3. Monitorear clientes (Leases)"
    echo "4. Desinstalar DHCP"
    echo -e "${YELLOW}--- SERVIDOR DNS (BIND9) ---${NC}"
    echo "5. Instalar Servidor DNS"
    echo "6. Gestor ABC: Agregar nuevo Dominio"
    echo "7. Gestor ABC: Eliminar Dominio"
    echo "8. Validar Sintaxis y Pruebas DNS"
    echo "9. Desinstalar DNS"
    echo -e "${YELLOW}--- SISTEMA ---${NC}"
    echo "10. Verificar estado de los servicios"
    echo "11. Salir"
    echo -e "${CYAN}========================================${NC}"
    read -p "Selecciona una opción: " OPCION

    case $OPCION in
        1) instalar_dhcp ;;
        2) configurar_scope ;;
        3) monitorear_clientes ;;
        4) desinstalar_dhcp ;;
        5) instalar_dns ;;
        6) agregar_dominio ;;
        7) eliminar_dominio ;;
        8) validar_dns ;;
        9) desinstalar_dns ;;
        10) verificar_estado ;;
        11) 
           log_ok "Saliendo del gestor..."
           exit 0 
           ;;
        *) 
           log_error "Opción inválida." 
           sleep 1
           ;;
    esac
done