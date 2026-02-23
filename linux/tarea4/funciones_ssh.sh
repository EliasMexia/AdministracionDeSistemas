#!/bin/bash
# Archivo: funciones_ssh.sh
# Descripción: Módulo para la instalación y configuración de SSH (Práctica 4)

function configurar_ssh() {
    echo "[*] Instalando y habilitando OpenSSH Server..."
    apt-get update -y > /dev/null 2>&1
    apt-get install openssh-server -y > /dev/null 2>&1
    systemctl enable ssh > /dev/null 2>&1
    systemctl start ssh > /dev/null 2>&1

    # Toma la primera IP disponible, que ahora sera la de tu Red NAT
    IP_NAT=$(hostname -I | awk '{print $1}')

    echo -e "\n======================================================="
    echo -e "\e[1;32m[+] SERVIDOR SSH LISTO EN LA RED NAT\e[0m"
    echo "======================================================="
    echo "Abre PowerShell en tu ClienteWin y conectate con:"
    echo -e "\n   \e[1;36mssh administrator@$IP_NAT\e[0m\n"
    echo "Una vez dentro, logueate como root (su -), corre ./main.sh"
    echo "y configura tu DHCP sobre el adaptador enp0s8."
    echo "======================================================="
}