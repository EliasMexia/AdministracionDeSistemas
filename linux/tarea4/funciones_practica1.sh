#!/bin/bash
# Archivo: funciones_practica1.sh

function verificar_estado() {
    echo "====================================="
    echo "     ESTADO DEL SISTEMA (Práctica 1) "
    echo "====================================="
    echo "[+] HOSTNAME:"; hostname
    echo "[+] IP:"; hostname -I | awk '{print $1}'
    echo "[+] DISCO:"; df -h | grep "/$"
    echo "====================================="
    read -p "Presiona Enter para continuar..."
}

# Si tuvieras más scripts de la práctica 1, los convertimos en funciones aquí abajo:
function actualizar_repositorios() {
    echo "Actualizando repositorios..."
    apt update -y
    read -p "Presiona Enter para continuar..."
}

function instalar_herramientas_base() {
    echo "Instalando herramientas base..."
    apt install -y nano curl wget net-tools
    read -p "Presiona Enter para continuar..."
}