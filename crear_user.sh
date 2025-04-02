#!/bin/bash
# correo/crear_user.sh

source "./solicitar_contra.sh"

crear_user(){
    local user="$1"
    
    # Crear el usuario con su directorio home
    echo "Creando usuario $user..."
    sudo useradd -m -s /bin/bash $user

    solicitar_contra "$user"
    
    sudo usermod -m -d /var/www/html/$user $user
    sudo mkdir -p /var/www/html/$user
}