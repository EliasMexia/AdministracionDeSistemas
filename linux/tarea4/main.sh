#!/bin/bash
# Script principal - Practica 4

# Importar modulos
source ./funciones_core.sh
source ./funciones_practica1.sh
source ./funciones_dhcp.sh
source ./funciones_dns.sh
source ./funciones_ssh.sh

# Validar permisos root
check_root

clear
echo "======================================================="
echo " MENU DE ADMINISTRACION "
echo "======================================================="
echo "1) Configurar Servidor (Ejecutar en Debian local)"
echo "2) Administrar Cliente (Ejecutar por SSH)"
echo "======================================================="
read -p "Elige una opcion [1-2]: " MODO

if [ "$MODO" == "1" ]; then
    clear
    echo "[*] Configurando servidor..."
    configurar_ssh
    
    IP_ACTUAL=$(hostname -I | awk '{print $1}')
    echo -e "\n======================================================="
    echo -e "\e[1;32m[+] SERVIDOR LISTO\e[0m"
    echo "======================================================="
    echo "Conectate desde tu maquina virtual Windows con:"
    echo -e "\n   \e[1;36mssh administrator@$IP_ACTUAL\e[0m\n"
    echo "Despues vuelve a ejecutar ./main.sh y elige la opcion 2."
    echo "======================================================="
    exit 0

elif [ "$MODO" == "2" ]; then
    while true; do
        clear
        echo "========================================="
        echo " PANEL CENTRAL (SSH)   "
        echo "========================================="
        echo "1) Estado del Sistema"
        echo "2) Gestionar DHCP"
        echo "3) Gestionar DNS"
        echo "4) Validar Servicios de Red"
        echo "5) Salir"
        echo "========================================="
        read -p "Elige una opcion [1-5]: " OPCION

        case $OPCION in
            1) menu_practica1 ;;
            2) 
               # Llamamos a las funciones reales de funciones_dhcp.sh
               instalar_dhcp
               configurar_dhcp
               read -p "Presiona Enter para volver..."
               ;;
            3) 
               # Llamamos a las funciones reales de funciones_dns.sh
               instalar_dns
               configurar_dns
               read -p "Presiona Enter para volver..."
               ;;
            4) 
               # Verificacion rapida de servicios
               echo "--- Estado de los servicios ---"
               systemctl status isc-dhcp-server --no-pager | grep "Active:"
               systemctl status bind9 --no-pager | grep "Active:"
               read -p "Presiona Enter para volver..."
               ;;
            5) echo "Saliendo..."; exit 0 ;;
            *) echo "Opcion invalida"; sleep 2 ;;
        esac
    done
else
    echo "Opcion no valida. Saliendo..."
    exit 1
fi