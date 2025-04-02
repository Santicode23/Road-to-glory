#!/bin/bash
# correo/solicitar_contra.sh

solicitar_contra(){
        local user="$1"
        while true; do
            read -s -p "Ingresa la contraseña para el usuario '$user': " contra1
            echo
            #Confirmar la contraseña
            read -s -p "Confirma la contraseña: " contra2
            echo

            #Verificar que la contraseña cumple con los requisitos
            if [[ "$contra1" != "$contra2" ]]; then
                echo "Las contraseñas no coinciden. Intenta de nuevo."
            elif [[ ${#contra1} -lt 5 || ! "$contra1" =~ [A-Z] || ! "$contra1" =~ [a-z] || ! "$contra1" =~ [0-9] || ! "$contra1" =~ [^a-zA-Z0-9] ]]; then
                echo "La contraseña no es válida. Debe tener al menos 5 caracteres, incluir una mayúscula, una minúscula, un número y un símbolo especial."
            else
                echo "Estableciendo la contraseña..."
                echo "$user:$contra1" | sudo chpasswd
                break
            fi
        done
}
