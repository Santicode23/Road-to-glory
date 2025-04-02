# !/bin/bash
# correo/verificar_servicio.sh


verificar_servicio (){
    local servicio="$1"

    # Verificar si el paquete está instalado
    if dpkg -l | grep -q "^ii  $servicio"; then
        return 0 # Servicio instalado
    fi
    return 1 # No esta instalado
}

