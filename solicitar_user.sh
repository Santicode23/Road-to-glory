#!/bin/bash
# funciones/bash/entrada/solicitar_user.sh

source "./validar_user.sh"

solicitar_user(){
    while true; do
        read username
        [[ -z "$username" ]] && return

        if validar_user "$username"; then
            if validar_user_existente "$username"; then
                echo "$username"
                return
            else 
                 echo "Error: El usuario '$username' ya existe en el sistema." >&2
            fi
        else
            echo "Error: El nombre de usuario no tiene un formato válido" >&2
        fi   
    done
}