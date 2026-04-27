#!/bin/bash

# ==========================================
# Archivo de Funciones - Practica 10
# ==========================================

instalar_docker() {
    echo "Verificando instalacion de Docker..."
    if ! command -v docker &> /dev/null; then
        echo "Instalando Docker de forma silenciosa..."
        sudo apt-get update -qq > /dev/null 2>&1
        sudo apt-get install -y -qq docker.io > /dev/null 2>&1
        sudo systemctl enable --now docker > /dev/null 2>&1
        # Se agrega el usuario al grupo docker por seguridad
        sudo usermod -aG docker $USER
        echo "Docker instalado correctamente. NOTA: Si es la primera vez, ejecuta 'newgrp docker' al terminar el script para aplicar los permisos."
    else
        echo "Docker ya se encuentra instalado."
    fi
}

preparar_red_volumenes() {
    echo "Verificando red infra_red..."
    if ! docker network ls | grep -w "infra_red" &> /dev/null; then
        docker network create --driver bridge --subnet=172.20.0.0/16 infra_red > /dev/null
        echo "Red infra_red creada exitosamente."
    else
        echo "La red infra_red ya existe."
    fi

    echo "Verificando volumenes..."
    for vol in db_data web_content; do
        if ! docker volume ls | grep -w "$vol" &> /dev/null; then
            docker volume create "$vol" > /dev/null
            echo "Volumen $vol creado."
        else
            echo "El volumen $vol ya existe."
        fi
    done
}
desplegar_web() {
    echo "Preparando Servidor Web..."
    
    if ! docker images | grep -w "mi_web_seguro" &> /dev/null; then
        echo "Construyendo imagen personalizada mi_web_seguro de forma silenciosa..."
        cat << 'EOF' > Dockerfile_web
FROM nginx:alpine

# Ocultar version
RUN sed -i 's/http {/http {\n    server_tokens off;/g' /etc/nginx/nginx.conf
# Cambiar puerto
RUN sed -i 's/listen       80;/listen       8080;/g' /etc/nginx/conf.d/default.conf
# Eliminar directivas conflictivas de usuario y pid original
RUN sed -i '/user  nginx;/d' /etc/nginx/nginx.conf && \
    sed -i '/pid /d' /etc/nginx/nginx.conf

# Crear usuario y asignar permisos
RUN addgroup -g 1000 webgroup && \
    adduser -u 1000 -D -S -G webgroup webuser && \
    mkdir -p /var/lib/nginx /var/cache/nginx /var/log/nginx && \
    chown -R webuser:webgroup /var/cache/nginx /var/run /var/log/nginx /usr/share/nginx/html /etc/nginx/conf.d /var/lib/nginx /tmp

USER webuser
EXPOSE 8080

CMD ["nginx", "-g", "daemon off; pid /tmp/nginx.pid;"]
EOF
        docker build -t mi_web_seguro -f Dockerfile_web . > /dev/null 2>&1
        rm Dockerfile_web
    else
        echo "La imagen mi_web_seguro ya existe. Omitiendo construccion."
    fi

    if ! docker ps -a | grep -w "web_server" &> /dev/null; then
        echo "Desplegando contenedor web_server..."
        docker run -d --name web_server \
          --network infra_red \
          --memory="512m" \
          --cpus="0.5" \
          -p 8080:8080 \
          -v web_content:/usr/share/nginx/html \
          mi_web_seguro > /dev/null
        echo "Contenedor web_server en ejecucion."
    else
        echo "El contenedor web_server ya esta desplegado."
    fi
}

desplegar_db() {
    echo "Preparando Servidor de Base de Datos..."
    if ! docker ps -a | grep -w "db_server" &> /dev/null; then
        echo "Desplegando contenedor db_server..."
        docker run -d --name db_server \
          --network infra_red \
          -e POSTGRES_USER=admin \
          -e POSTGRES_PASSWORD=secreto \
          -e POSTGRES_DB=appdb \
          -v db_data:/var/lib/postgresql/data \
          postgres:15-alpine > /dev/null
        echo "Contenedor db_server en ejecucion."
    else
        echo "El contenedor db_server ya esta desplegado."
    fi
}

desplegar_ftp() {
    echo "Preparando Servidor FTP..."
    if ! docker ps -a | grep -w "ftp_server" &> /dev/null; then
        echo "Desplegando contenedor ftp_server..."
        docker run -d --name ftp_server \
          --network infra_red \
          -p 21:21 -p 21000-21010:21000-21010 \
          -e USERS="admin|password123" \
          -v web_content:/ftp/admin \
          delfer/alpine-ftp-server > /dev/null
        echo "Contenedor ftp_server en ejecucion."
    else
        echo "El contenedor ftp_server ya esta desplegado."
    fi
}

prueba_persistencia() {
    echo "--- Prueba 10.1: Persistencia de BD ---"
    echo "Creando tabla y registro de prueba en la base de datos..."
    docker exec db_server psql -U admin -d appdb -c "CREATE TABLE IF NOT EXISTS test (id serial PRIMARY KEY, dato VARCHAR(50));" > /dev/null 2>&1
    docker exec db_server psql -U admin -d appdb -c "INSERT INTO test (dato) VALUES ('este_dato_es_persistente');" > /dev/null 2>&1
    
    echo "Forzando eliminacion del contenedor db_server..."
    docker rm -f db_server > /dev/null 2>&1
    
    echo "Volviendo a levantar db_server desde la funcion principal..."
    desplegar_db > /dev/null
    
    echo "Esperando 3 segundos a que Postgres inicie correctamente..."
    sleep 3
    
    echo "Verificando si el registro persiste:"
    docker exec db_server psql -U admin -d appdb -c "SELECT * FROM test;"
    echo "----------------------------------------"
}

prueba_aislamiento() {
    echo "--- Prueba 10.2: Aislamiento de red ---"
    echo "Haciendo ping desde web_server hacia db_server (por nombre de contenedor)..."
    docker exec web_server ping -c 3 db_server
    echo "----------------------------------------"
}

prueba_ftp_web() {
    echo "--- Prueba 10.3: Permisos FTP y Servidor Web ---"
    
    echo "1. Creando un archivo HTML local en Debian..."
    echo "<h1>Este archivo fue subido mediante protocolo FTP real</h1>" > index_real.html
    
    echo "2. Conectando y subiendo archivo al servidor FTP local..."
    # Usamos curl con la bandera -T para subir un archivo por FTP usando las credenciales del contenedor
    curl -T index_real.html ftp://localhost --user admin:password123
    
    echo ""
    echo "3. Peticion web (curl) al puerto 8080 de Nginx para comprobar lectura:"
    curl -s http://localhost:8080/index_real.html
    echo ""
    
    # Limpieza del archivo temporal local
    rm index_real.html
    
    echo "----------------------------------------"
}

prueba_recursos() {
    echo "--- Prueba 10.4: Limites de recursos ---"
    echo "Ejecutando docker stats. Aqui podras validar el limite en la columna MEM LIMIT."
    docker stats --no-stream web_server db_server ftp_server
    echo "----------------------------------------"
}
