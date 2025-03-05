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
    echo "5- Salir"
    read -p "Ingrese una opción: " seleccion

    case $seleccion in
        1) read -p "Ingrese el nombre del grupo: " nuevoGrupo; agregarGrupo "$nuevoGrupo";;
        2) read -p "Ingrese el nombre de usuario: " nuevoUsuario; agregarUsuario "$nuevoUsuario";;
        3) read -p "Ingrese el nombre de usuario: " usuario; read -p "Ingrese el nombre del grupo: " grupo; asignarGrupoUsuario "$usuario" "$grupo";;
        4) cambiarGrupoUsuario;;
        5) opcion=false;;
    esac
done
