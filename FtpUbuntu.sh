#!/usr/bin/env bash

source ./ftp_functions.sh
configurarFTP
habilitarAnonimo

echo "EL MEJOR FTP TARDE PERO SEGURO"

opcion=true
while $opcion; do
    echo "Seleccione una opción:"
    echo "1- Crear grupo"
    echo "2- Crear usuario"
    echo "3- Asignar usuario a grupo"
    echo "4- Cambiar grupo de usuario"
    echo "5- Listar usuarios"
    echo "6- Salir"
    read -p "Ingrese una opción: " seleccion

    case $seleccion in
        1)  
            while true; do
                read -p "Ingrese el nombre del grupo: " nuevoGrupo
                if ! validarGrupo "$nuevoGrupo"; then
                    echo "Nombre de grupo inválido. Intente de nuevo."
                    continue
                fi
                if grupoExiste "$nuevoGrupo"; then
                    echo "El grupo '$nuevoGrupo' ya existe. Elija otro nombre."
                    continue
                fi
                break
            done
            agregarGrupo "$nuevoGrupo"
            ;;
        2)  
            while true; do
                read -p "Ingrese el nombre de usuario: " nuevoUsuario
                if ! validarUsuario "$nuevoUsuario"; then
                    echo "Nombre de usuario inválido. Intente de nuevo."
                    continue
                fi
                if usuarioExiste "$nuevoUsuario"; then
                    echo "El usuario '$nuevoUsuario' ya existe. Elija otro nombre."
                    continue
                fi
                break
            done
            agregarUsuario "$nuevoUsuario"
            ;;
        3)  
            while true; do
                read -p "Ingrese el nombre de usuario: " usuario
                if ! usuarioExiste "$usuario"; then
                    echo "El usuario '$usuario' no existe. Inténtelo de nuevo."
                    continue
                fi
                read -p "Ingrese el nombre del grupo: " grupo
                if ! grupoExiste "$grupo"; then
                    echo "El grupo '$grupo' no existe. Inténtelo de nuevo."
                    continue
                fi
                break
            done
            asignarGrupoUsuario "$usuario" "$grupo"
            ;;
        4)  
            while true; do
                read -p "Ingrese el usuario a cambiar de grupo: " usuario
                if ! usuarioExiste "$usuario"; then
                    echo "El usuario '$usuario' no existe. Inténtelo de nuevo."
                    continue
                fi
                read -p "Ingrese el nuevo grupo: " nuevoGrupo
                if ! grupoExiste "$nuevoGrupo"; then
                    echo "El grupo '$nuevoGrupo' no existe. Inténtelo de nuevo."
                    continue
                fi
                break
            done
            cambiarGrupoUsuario "$usuario" "$nuevoGrupo"
            ;;
        5)
            echo "Usuarios registrados:"
            listarUsuarios
            ;;
        6)  
            opcion=false
            echo "Saliendo del programa..."
            ;;
        *)  
            echo "Opción inválida, intente de nuevo."
            ;;
    esac
done
