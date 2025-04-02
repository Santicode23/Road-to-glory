#!/bin/bash
# funciones/bash/validacion/validar_user.sh

validar_user(){
    local user="$1"
    if [[ ! "$user" =~ ^[a-zA-Z0-9_]{3,16}$ ]]; then 
        return 1
    fi
    return 0
}

validar_user_existente(){
    if id "$1" &>/dev/null; then
        return 1
    fi
    return 0
}