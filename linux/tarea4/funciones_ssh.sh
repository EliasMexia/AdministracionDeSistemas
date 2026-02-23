#!/bin/bash
# Archivo: funciones_ssh.sh
# Descripción: Módulo para la instalación y configuración de SSH (Práctica 4)

function configurar_ssh() {
    clear
    echo "==================================================="
    echo "       CONFIGURANDO SERVICIO SSH (Práctica 4)      "
    echo "==================================================="
    
    echo "[*] Actualizando repositorios e instalando OpenSSH Server..."
    apt-get update -y > /dev/null 2>&1
    apt-get install -y openssh-server > /dev/null 2>&1
    
    echo "[*] Habilitando el servicio SSH en el arranque (Boot)..."
    systemctl enable ssh
    
    echo "[*] Iniciando el servicio SSH..."
    systemctl start ssh
    
    echo "[+] SSH configurado correctamente."
    echo "[+] A partir de ahora debes conectarte con: ssh tu_usuario@$(hostname -I | awk '{print $1}')"
    echo "==================================================="
    sleep 4 # Pausa para que el usuario alcance a leer el mensaje
}