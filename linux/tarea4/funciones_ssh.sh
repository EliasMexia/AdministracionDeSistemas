#!/bin/bash
# ==========================================
# funciones_ssh.sh - Instalacion de SSH
# ==========================================

configurar_ssh() {
    clear
    echo "[INFO] --- CONFIGURACION DE SSH Y RED DE ADMINISTRACION ---"
    
    # 1. Instalar OpenSSH y el Firewall (UFW)
    echo "[INFO] Instalando OpenSSH y dependencias de firewall..."
    apt-get update -y > /dev/null
    apt-get install -y openssh-server ufw > /dev/null
    systemctl enable ssh
    
    # 2. Configurar Reglas de Firewall
    echo "[INFO] Abriendo puerto 22..."
    ufw allow 22/tcp > /dev/null
    
    # 3. Configurar IP Estatica en enp0s9 (Adaptador 3)
    echo "[INFO] Configurando IP 192.168.99.1 en la red itnet (enp0s9)..."
    
    # Limpiar cualquier error o duplicado de intentos anteriores
    sed -i '/enp0s9/d' /etc/network/interfaces
    sed -i '/192.168.99.1/d' /etc/network/interfaces
    sed -i '/netmask 255.255.255.0/d' /etc/network/interfaces
    sed -i '/Red de Administracion/d' /etc/network/interfaces
    
    # Inyectar configuracion limpia
    echo -e "\n# Red de Administracion (itnet)\nauto enp0s9\niface enp0s9 inet static\naddress 192.168.99.1\nnetmask 255.255.255.0" >> /etc/network/interfaces
    
    # Aplicar la IP en caliente sin reiniciar todo el servicio de red
    ip link set enp0s9 down 2>/dev/null
    ip addr flush dev enp0s9 2>/dev/null
    ip link set enp0s9 up
    ip addr add 192.168.99.1/24 dev enp0s9
    
    systemctl restart ssh
    
    echo "[OK] SSH configurado con exito."
    echo "[OK] IP de Administracion asignada: 192.168.99.1"
    read -p "Presiona Enter para continuar..."
}