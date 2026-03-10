#!/bin/bash

# ==========================================
# 1. UTILIDADES Y VALIDACIONES
# ==========================================
instalar_dependencias_base() {
    echo "Actualizando índices e instalando dependencias base (UFW, curl, net-tools)..."
    apt-get update -qq
    apt-get install -y -q ufw curl net-tools gawk
}

puerto_en_uso() {
    local puerto=$1
    # ss revisa si hay algún socket escuchando en ese puerto
    if ss -tuln | grep -q ":$puerto "; then
        return 0 # Verdadero (Ocupado)
    else
        return 1 # Falso (Libre)
    fi
}

seleccionar_version() {
    local paquete=$1
    # Consulta dinámica extraída con awk, filtrada y ordenada para eliminar duplicados
    mapfile -t versiones < <(apt-cache madison "$paquete" | awk '{print $3}' | sort -Vu)
    
    if [ ${#versiones[@]} -eq 0 ]; then
        echo "No se encontraron versiones para $paquete."
        return
    fi

    echo "Versiones encontradas para $paquete (Estable / Desarrollo):"
    select ver in "${versiones[@]}"; do
        if [[ -n "$ver" ]]; then
            echo "$ver"
            break
        else
            echo "Selección inválida."
        fi
    done
}

configurar_firewall() {
    local puerto=$1
    echo "Configurando UFW para permitir el puerto $puerto..."
    ufw allow "$puerto"/tcp > /dev/null
    ufw --force enable > /dev/null
}

crear_index() {
    local ruta=$1
    local servicio=$2
    local version=$3
    local puerto=$4
    
    echo "<h1>Servidor: $servicio - Versión: $version - Puerto: $puerto</h1>" > "$ruta/index.html"
}

# ==========================================
# 2. FUNCIONES DE INSTALACIÓN Y HARDENING
# ==========================================

instalar_apache() {
    local version=$1
    local puerto=$2
    
    echo "Instalando Apache2 ($version) de forma silenciosa..."
    apt-get install -y -q apache2="$version" apache2-bin="$version" apache2-data="$version"
    
    echo "Cambiando puerto a $puerto..."
    sed -i "s/Listen .*/Listen $puerto/g" /etc/apache2/ports.conf
    sed -i "s/<VirtualHost \*:.*>/<VirtualHost \*:$puerto>/g" /etc/apache2/sites-available/000-default.conf
    
    echo "Aplicando Hardening a Apache..."
    # Ocultar versiones
    sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-available/security.conf
    sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-available/security.conf
    
    # Habilitar headers de seguridad
    a2enmod headers > /dev/null
    echo "Header always append X-Frame-Options SAMEORIGIN" >> /etc/apache2/conf-available/security.conf
    echo "Header always append X-Content-Type-Options nosniff" >> /etc/apache2/conf-available/security.conf
    
    crear_index "/var/www/html" "Apache2" "$version" "$puerto"
    chown -R www-data:www-data /var/www/html
    chmod -R 750 /var/www/html
    
    configurar_firewall "$puerto"
    systemctl restart apache2
    echo "Apache configurado y asegurado exitosamente."
}

instalar_nginx() {
    local version=$1
    local puerto=$2
    
    echo "Instalando Nginx ($version) de forma silenciosa..."
    apt-get install -y -q nginx="$version" nginx-common="$version" nginx-core="$version"
    
    echo "Cambiando puerto a $puerto..."
    sed -i "s/listen 80 default_server;/listen $puerto default_server;/g" /etc/nginx/sites-available/default
    sed -i "s/listen \[::\]:80 default_server;/listen \[::\]:$puerto default_server;/g" /etc/nginx/sites-available/default
    
    echo "Aplicando Hardening a Nginx..."
    # Desactivar tokens (ocultar versión)
    sed -i 's/# server_tokens off;/server_tokens off;/g' /etc/nginx/nginx.conf
    
    # Headers de seguridad
    sed -i '/server_name _;/a \ \ \ \ add_header X-Frame-Options SAMEORIGIN;\n \ \ \ \ add_header X-Content-Type-Options nosniff;' /etc/nginx/sites-available/default
    
    crear_index "/var/www/html" "Nginx" "$version" "$puerto"
    chown -R www-data:www-data /var/www/html
    chmod -R 750 /var/www/html
    
    configurar_firewall "$puerto"
    systemctl restart nginx
    echo "Nginx configurado y asegurado exitosamente."
}

instalar_tomcat() {
    local version=$1
    local puerto=$2
    
    echo "Instalando Tomcat9 ($version) de forma silenciosa..."
    apt-get install -y -q tomcat9="$version"
    
    echo "Cambiando puerto a $puerto..."
    sed -i "s/port=\"8080\"/port=\"$puerto\"/g" /etc/tomcat9/server.xml
    
    echo "Aplicando Hardening a Tomcat..."
    # Eliminar header de versión de servidor en Tomcat
    sed -i "s/port=\"$puerto\"/port=\"$puerto\" server=\"Apache Tomcat\"/g" /etc/tomcat9/server.xml
    
    crear_index "/var/lib/tomcat9/webapps/ROOT" "Tomcat" "$version" "$puerto"
    chown -R tomcat:tomcat /var/lib/tomcat9/webapps
    chmod -R 750 /var/lib/tomcat9/webapps
    
    configurar_firewall "$puerto"
    systemctl restart tomcat9
    echo "Tomcat configurado y asegurado exitosamente."
}