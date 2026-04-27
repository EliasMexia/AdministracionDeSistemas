#!/bin/bash

validarUsuarioFTP() {
    local username=$1
    local longitudMaxima=15

    if [[ -z "$username" ]]; then
        echo "La cadena no puede estar vacía. Inténtalo de nuevo."
        return 1
    fi

    if [[ "$username" =~ ^[0-9] ]]; then
        echo "El username no puede comenzar con un número."
        return 1
    fi

    if [[ "$username" =~ [^a-zA-Z0-9_] ]]; then
        echo "El username contiene caracteres no permitidos."
        return 1
    fi

    if [[ ${#username} -gt $longitudMaxima ]]; then
        echo "La cadena no puede exceder los $longitudMaxima caracteres. Inténtalo de nuevo."
        return 1
    fi

    if id "$username" &>/dev/null; then
        echo "El usuario '$username' ya existe. Por favor, elija otro nombre de usuario."
        return 1
    fi

    # CORRECCIÓN: Se cambió $nombre_usuario por $username
    if [[ "$username" =~ [[:space:]] ]]; then
        echo "El username no puede contener espacios."
        return 1
    fi

    return 0
}

agregarUsuarioFTP() {
    echo -n "¿Cuántos usuarios deseas agregar al servidor FTP? "
    read num_usuarios

    for ((i=1; i<=num_usuarios; i++)); do
        echo "--- Creando usuario $i de $num_usuarios ---"
        while true; do
            echo -n "Ingrese el username: "
            read username

            if validarUsuarioFTP "$username"; then
                echo -n "Seleccione el grupo 1) reprobados 2) recursadores: "
                read grupo_opcion

                if [ "$grupo_opcion" == "1" ]; then
                    grupo="reprobados"
                elif [ "$grupo_opcion" == "2" ]; then
                    grupo="recursadores"
                else
                    echo "Opción inválida. Vuelva a intentar."
                    continue
                fi
                
                sudo useradd -m -d /srv/ftp/autenticados/$username -s /bin/bash -G "$grupo" "$username"
                sudo passwd "$username"

                # Estructura de carpetas requerida
                sudo mkdir -p /srv/ftp/autenticados/$username/{general,"$grupo",$username}
                sudo chown "$username":"$username" /srv/ftp/autenticados/$username
                sudo chown "$username":"$username" /srv/ftp/autenticados/$username/$username
                sudo chmod 750 /srv/ftp/autenticados/$username
                sudo chmod 700 /srv/ftp/autenticados/$username/$username

                # Bind Mounts
                sudo mount --bind /srv/ftp/grupos/general /srv/ftp/autenticados/$username/general
                sudo mount --bind /srv/ftp/grupos/"$grupo" /srv/ftp/autenticados/$username/"$grupo"
                
                # Persistencia en fstab
                echo "/srv/ftp/grupos/general /srv/ftp/autenticados/$username/general none bind 0 0" | sudo tee -a /etc/fstab > /dev/null
                echo "/srv/ftp/grupos/$grupo /srv/ftp/autenticados/$username/$grupo none bind 0 0" | sudo tee -a /etc/fstab > /dev/null

                # Permisos ACL
                sudo setfacl -m u:$username:rwx /srv/ftp/autenticados/$username
                sudo setfacl -m u:$username:rwx /srv/ftp/grupos/general
                sudo setfacl -m u:$username:rwx /srv/ftp/grupos/"$grupo"

                echo "✅ Usuario $username creado correctamente en el grupo $grupo."
                break # Sale del while para pasar al siguiente usuario del for
            fi
        done
    done
}

cambiarGrupoFTP() {
    echo -n "Ingrese el nombre del usuario al que desea cambiar de grupo: "
    read username

    if ! id "$username" &>/dev/null; then
        echo "El usuario no existe."
        return 1
    fi

    echo -n "Seleccione el NUEVO grupo 1) reprobados 2) recursadores: "
    read grupo_opcion

    if [ "$grupo_opcion" == "1" ]; then
        nuevo_grupo="reprobados"
        viejo_grupo="recursadores"
    elif [ "$grupo_opcion" == "2" ]; then
        nuevo_grupo="recursadores"
        viejo_grupo="reprobados"
    else
        echo "Opción inválida."
        return 1
    fi

    # 1. Desmontar la carpeta del grupo viejo y quitarla de fstab
    sudo umount /srv/ftp/autenticados/$username/$viejo_grupo 2>/dev/null
    # Se usa sed para borrar la linea exacta del fstab que contiene la ruta vieja
    sudo sed -i "\|/srv/ftp/autenticados/$username/$viejo_grupo|d" /etc/fstab
    sudo rm -rf /srv/ftp/autenticados/$username/$viejo_grupo

    # 2. Cambiar el grupo en el sistema
    sudo gpasswd -d $username $viejo_grupo 2>/dev/null
    sudo usermod -aG $nuevo_grupo $username

    # 3. Crear, montar y persistir la nueva carpeta
    sudo mkdir -p /srv/ftp/autenticados/$username/$nuevo_grupo
    sudo mount --bind /srv/ftp/grupos/$nuevo_grupo /srv/ftp/autenticados/$username/$nuevo_grupo
    echo "/srv/ftp/grupos/$nuevo_grupo /srv/ftp/autenticados/$username/$nuevo_grupo none bind 0 0" | sudo tee -a /etc/fstab > /dev/null

    # 4. Actualizar ACLs
    sudo setfacl -m u:$username:rwx /srv/ftp/grupos/$nuevo_grupo

    echo "El usuario $username ha sido movido al grupo $nuevo_grupo exitosamente."
}

eliminarUsuarioFTP() {
    echo -n "Ingrese el username que desea eliminar: "
    read username

    if ! id "$username" &>/dev/null; then
        echo "El usuario no existe."
        return 1
    fi

    # Determinar a qué grupo pertenece para desmontar
    if id -nG "$username" | grep -qw "reprobados"; then
        grupo="reprobados"
    else
        grupo="recursadores"
    fi

    echo "Limpiando montajes y archivos de sistema..."
    # 1. Desmontar los directorios antes de borrar al usuario
    sudo umount /srv/ftp/autenticados/$username/general 2>/dev/null
    sudo umount /srv/ftp/autenticados/$username/$grupo 2>/dev/null

    # 2. Eliminar de fstab TODAS las entradas de este usuario para no corromper el arranque
    sudo sed -i "\|/srv/ftp/autenticados/$username|d" /etc/fstab

    # 3. Eliminar usuario y su directorio base (-r borra la carpeta home/chroot)
    sudo userdel -r "$username"

    echo "El usuario $username ha sido eliminado completamente del servidor FTP."
}
