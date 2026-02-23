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
    echo "Minimiza esta ventana y conectate desde tu maquina fisica con:"
    echo -e "\n   \e[1;36mssh root@$IP_ACTUAL\e[0m\n"
    echo "Despues vuelve a ejecutar ./main.sh y elige la opcion 2."
    echo "======================================================="
    exit 0

elif [ "$MODO" == "2" ]; then
    # Revisar si se esta ejecutando desde SSH
    if [ -z "$SSH_CLIENT" ] && [ -z "$SSH_TTY" ]; then
        echo -e "\e[31m[AVISO] No estas conectado por SSH.\e[0m"
        read -p "Presiona Enter para continuar de todos modos..."
    fi

    # Ciclo del menu principal
    while true; do
        clear
        echo "========================================="
        echo " PANEL CENTRAL (SSH)   "
        echo "========================================="
        echo "1) Estado del Sistema"
        echo "2) DHCP"
        echo "3) DNS"
        echo "4) Validar Red"
        echo "5) Salir"
        echo "========================================="
        read -p "Elige una opcion [1-5]: " OPCION

        case $OPCION in
            1) menu_practica1 ;;
            2) 
               echo "--- DHCP ---"
               # instalar_dhcp
               # configurar_dhcp
               read -p "Enter para volver..."
               ;;
            3) 
               echo "--- DNS ---"
               # instalar_dns
               # agregar_dominio
               read -p "Enter para volver..."
               ;;
            4) validar_dns ;;
            5) echo "Saliendo..."; exit 0 ;;
            *) echo "Opcion invalida"; sleep 2 ;;
        esac
    done
else
    echo "Opcion no valida. Saliendo..."
    exit 1
fi