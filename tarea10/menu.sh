#!/bin/bash

# ==========================================
# Menu Principal - Practica 10
# ==========================================

# Cargar las funciones desde el archivo externo
if [ -f "./functionsDockers.sh" ]; then
    source ./functionsDockers.sh
else
    echo "Error critico: No se encuentra el archivo funciones.sh en el directorio actual."
    exit 1
fi

pausa() {
    echo ""
    read -p "Presiona Enter para continuar..."
}

while true; do
    clear
    echo "=========================================="
    echo "   MENU AUTOMATIZADO - SYSADMIN TAREA 10  "
    echo "=========================================="
    echo "OPCIONES DE DESPLIEGUE:"
    echo "1. Instalar dependencias base (Docker)"
    echo "2. Preparar Red y Volumenes"
    echo "3. Desplegar Servidor Web (Nginx Seguro)"
    echo "4. Desplegar Servidor BD (PostgreSQL)"
    echo "5. Desplegar Servidor FTP"
    echo "6. Desplegar TODO (Opciones 2 a 5 juntas)"
    echo "------------------------------------------"
    echo "OPCIONES DE PRUEBAS Y VALIDACION:"
    echo "7. Prueba 10.1 (Persistencia de BD)"
    echo "8. Prueba 10.2 (Aislamiento de Red)"
    echo "9. Prueba 10.3 (Archivos compartidos FTP/Web)"
    echo "10. Prueba 10.4 (Limites de Recursos CPU/RAM)"
    echo "11. Ejecutar todas las pruebas en secuencia"
    echo "------------------------------------------"
    echo "0. Salir"
    echo "=========================================="
    read -p "Selecciona una opcion (0-11): " opcion
    echo ""

    case $opcion in
        1) instalar_docker; pausa ;;
        2) preparar_red_volumenes; pausa ;;
        3) desplegar_web; pausa ;;
        4) desplegar_db; pausa ;;
        5) desplegar_ftp; pausa ;;
        6) 
            preparar_red_volumenes
            desplegar_web
            desplegar_db
            desplegar_ftp
            echo ""
            echo "Toda la infraestructura ha sido validada y desplegada."
            pausa 
            ;;
        7) prueba_persistencia; pausa ;;
        8) prueba_aislamiento; pausa ;;
        9) prueba_ftp_web; pausa ;;
        10) prueba_recursos; pausa ;;
        11)
            prueba_persistencia
            prueba_aislamiento
            prueba_ftp_web
            prueba_recursos
            pausa
            ;;
        0) echo "Saliendo del asistente..."; exit 0 ;;
        *) echo "Opcion no valida. Intenta de nuevo con un numero del 0 al 11."; pausa ;;
    esac
done
