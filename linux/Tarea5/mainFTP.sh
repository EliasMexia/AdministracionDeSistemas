#!/bin/bash

source ./funciones_ftp.sh

echo "=================================================="
echo "  CONFIGURACIÓN INICIAL DEL SERVIDOR FTP (vsftpd) "
echo "=================================================="

# Instalar vsftpd y utilidades ACL
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1
apt-get install -y -qq sudo ufw vsftpd acl > /dev/null 2>&1


# Crear carpetas para FTP
echo " Creando directorios base para FTP..."
sudo mkdir -p /srv/ftp/{anon,autenticados,grupos/general,grupos/reprobados,grupos/recursadores}

# Configurar firewall (UFW)
echo "Configurando firewall (UFW) para FTP..."
sudo ufw allow 20/tcp > /dev/null 2>&1
sudo ufw allow 21/tcp > /dev/null 2>&1
sudo ufw allow 40000:50000/tcp > /dev/null 2>&1
sudo ufw reload > /dev/null 2>&1 # Recarga por si ya estaba activo
# Configuración vsftpd
echo "Configurando /etc/vsftpd.conf..."
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.original 2>/dev/null
sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
# Usuarios locales
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
listen=YES
listen_ipv6=NO
pam_service_name=vsftpd
user_sub_token=\$USER
chroot_local_user=YES
allow_writeable_chroot=YES
local_root=/srv/ftp/autenticados/\$USER

# Usuario anonimo
anonymous_enable=YES
anon_root=/srv/ftp/anon
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO

# Modo pasivo
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
EOF

# Crear grupos
echo " Creando grupos del sistema..."
sudo groupadd -f reprobados
sudo groupadd -f recursadores

# Permisos
echo " Configurando permisos y ACLs base..."
# Permisos para general (SGID activado con 2775 para herencia)
sudo chmod 2775 /srv/ftp/grupos/general
sudo chown root:ftp /srv/ftp/grupos/general
sudo setfacl -d -m u::rwx /srv/ftp/grupos/general
sudo setfacl -d -m g::r-x /srv/ftp/grupos/general
sudo setfacl -d -m o::r-x /srv/ftp/grupos/general

# Permisos de carpetas de grupos
sudo chmod 770 /srv/ftp/grupos/reprobados
sudo chown root:reprobados /srv/ftp/grupos/reprobados
sudo chmod 770 /srv/ftp/grupos/recursadores
sudo chown root:recursadores /srv/ftp/grupos/recursadores

# Montar carpeta general para anónimos
echo " Configurando acceso para usuarios anónimos..."
sudo mkdir -p /srv/ftp/anon/general

# Validaciones de idempotencia para no duplicar montajes
if ! mountpoint -q /srv/ftp/anon/general; then
    sudo mount --bind /srv/ftp/grupos/general /srv/ftp/anon/general
fi

if ! grep -q "/srv/ftp/anon/general" /etc/fstab; then
    echo "/srv/ftp/grupos/general /srv/ftp/anon/general none bind 0 0" | sudo tee -a /etc/fstab > /dev/null
fi

# Reiniciar FTP
echo " Reiniciando servicio vsftpd..."
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd

# Bucle principal del Menú ABC
while true; do
    echo ""
    echo "--- GESTOR DE USUARIOS FTP ---"
    echo "1. Agregar Usuarios"
    echo "2. Cambiar de Grupo"
    echo "3. Eliminar Usuario"
    echo "4. Salir"
    read -p "Elige una opción (1-4): " opcion

    case $opcion in
        1) agregarUsuarioFTP ;;
        2) cambiarGrupoFTP ;;
        3) eliminarUsuarioFTP ;;
        4) exit 0 ;;
        *) echo " Opción no válida. Intenta de nuevo." ;;
    esac
done
