#!/bin/bash

# Se carga el archivo de funciones locales
source ./http_functions.sh

# Validar que somos root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo)."
  exit 1
fi

instalar_dependencias_base

while true; do
    echo "========================================="
    echo "   Aprovisionamiento HTTP Multi-Versión  "
    echo "========================================="
    echo "1. Apache2"
    echo "2. Nginx"
    echo "3. Tomcat"
    echo "4. Salir"
    read -p "Selecciona el servicio a instalar (1-4): " opcion

    if [[ "$opcion" == "4" ]]; then
        echo "Saliendo del instalador..."
        break
    fi

    # Mapeo de la selección al nombre del servicio
    case $opcion in
        1) servicio="apache2" ;;
        2) servicio="nginx" ;;
        3) servicio="tomcat9" ;; # Usamos tomcat9 como base en repositorios Debian
        *) echo "Opción inválida."; continue ;;
    esac

    # Validar puerto con expresiones regulares (solo números)
    read -p "Ingresa el puerto de escucha (ej. 80, 8080): " puerto
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ "$puerto" -lt 1 ] || [ "$puerto" -gt 65535 ]; then
        echo "Error: El puerto debe ser un número válido entre 1 y 65535."
        continue
    fi

    if puerto_en_uso "$puerto"; then
        echo "Error: El puerto $puerto ya está ocupado por otro servicio."
        continue
    fi

    echo "Consultando versiones disponibles en los repositorios de Debian..."
    version_elegida=$(seleccionar_version "$servicio")

    if [[ -z "$version_elegida" ]]; then
        echo "No se seleccionó una versión válida. Cancelando..."
        continue
    fi

    # Ejecutar la instalación silenciosa según el servicio
    case $servicio in
        "apache2") instalar_apache "$version_elegida" "$puerto" ;;
        "nginx")   instalar_nginx "$version_elegida" "$puerto" ;;
        "tomcat9") instalar_tomcat "$version_elegida" "$puerto" ;;
    esac

    read -p "¿Deseas instalar otro servicio? (s/n): " continuar
    if [[ "$continuar" != "s" && "$continuar" != "S" ]]; then
        break
    fi
done