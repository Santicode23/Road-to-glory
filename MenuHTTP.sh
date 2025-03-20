#!/bin/bash

# Cargar funciones 
source ./FunctionHTTP.sh

mostrar_menu() {
    clear 
    echo "=================================="
    echo "        Instalador HTTP           "
    echo "=================================="
    echo "0. Instalar dependencias necesarias"
    echo "1. Seleccionar Servicio"
    echo "2. Seleccionar Version"
    echo "3. Configurar Puerto"
    echo "4. Proceder con la Instalacion"
    echo "5. Verificar servicios instalados"
    echo "6. Salir"
}


while true; do
    mostrar_menu
    read -p "Seleccione una opcion: " opcion_menu

    case $opcion_menu in
        0) 
            instalar_dependencias
            read -p "Presione Enter para continuar..."
            ;;
        1) 
            seleccionar_servicio
            read -p "Presione Enter para continuar..."
            ;;
        2) 
            seleccionar_version
            read -p "Presione Enter para continuar..."
            ;;
        3) 
            preguntar_puerto
            read -p "Presione Enter para continuar..."
            ;;
        4) 
            # Mostrar resumen antes de proceder
            echo "=================================="
            echo "      Resumen de la instalacion   "
            echo "=================================="
            echo "Servicio seleccionado: $servicio"
            echo "Version seleccionada: $version"
            echo "Puerto configurado: $puerto"
            echo "=================================="

            read -p "¿Desea proceder con la instalacion? (s/n): " confirmacion
            if [[ "$confirmacion" != "s" ]]; then
                echo "Instalación cancelada."
            else
                proceso_instalacion
            fi
            read -p "Presione Enter para continuar..."
            ;;
        5) 
            verificar_servicios
            read -p "Presione Enter para continuar..."
            ;;
        6) 
            echo "Saliendo..."
            exit 0
            ;;
        *) 
            echo "Opcion no valida. Intente de nuevo."
            read -p "Presione Enter para continuar..."
            ;;
    esac
done
