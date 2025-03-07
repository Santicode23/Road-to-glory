#!/usr/bin/env bash

configurarFTP(){
    echo "Instalando servicio FTP..."
    sudo apt-get install vsftpd -y
    echo "Servicio FTP instalado correctamente."
    
    configurarVsftpd
    inicializarDirectorios
}

inicializarDirectorios(){
   sudo mkdir -p /home/servidorftp/{grupos,usuarios,publico}
    
    sudo chown root:root /home/servidorftp
    sudo chmod 751 /home/servidorftp
    sudo chmod 770 /home/servidorftp/{grupos,usuarios}
    sudo chmod 755 /home/servidorftp/publico
    echo "Directorios FTP inicializados con permisos adecuados."
}

configurarVsftpd(){
    echo "Configurando vsftpd..."
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.backup
    sudo bash -c 'cat > /etc/vsftpd.conf <<EOF
listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
user_sub_token=$USER
local_root=/home/\$USER
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
EOF'
    sudo systemctl restart vsftpd
    echo "vsftpd configurado correctamente."
}

habilitarAnonimo(){
    if [ ! -d "/acceso_anonimo" ]; then
        sudo mkdir /acceso_anonimo
    fi

    if [ ! -d "/acceso_anonimo/publico" ]; then
        sudo mkdir /acceso_anonimo/publico
    fi

    if ! sudo grep -q "^anonymous_enable=YES" /etc/vsftpd.conf; then
        sudo sed -i 's/^anonymous_enable=.*/anonymous_enable=YES/g' /etc/vsftpd.conf
        sudo service vsftpd restart
    fi
    
    if ! sudo grep -q "^write_enable=.*" /etc/vsftpd.conf; then
        sudo mount --bind /home/servidorftp/publico /acceso_anonimo/publico
        echo "write_enable=YES" | sudo tee -a /etc/vsftpd.conf
        echo "anon_root=/acceso_anonimo" | sudo tee -a /etc/vsftpd.conf
        sudo service vsftpd restart
    fi
}

validarGrupo(){
    local nombreGrupo="$1"
    local limite=15
    if [[ -z "$nombreGrupo" ]]; then
        echo "El nombre del grupo no puede estar vacío."
        return 1
    fi
    if [[ ! "$nombreGrupo" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "El nombre del grupo solo puede contener letras, números, guiones o guion bajo."
        return 1
    fi
    if [[ ${#nombreGrupo} -gt $limite ]]; then
        echo "El nombre del grupo no puede exceder los $limite caracteres."
        return 1
    fi
    return 0
}

validarUsuario(){
    local nombreUsuario="$1"
    local limite=20
    if [[ -z "$nombreUsuario" ]]; then
        echo "El nombre del usuario no puede estar vacío."
        return 1
    fi
    if [[ ! "$nombreUsuario" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "El nombre del usuario solo puede contener letras, números, guiones o guion bajo."
        return 1
    fi
    if [[ ${#nombreUsuario} -gt $limite ]]; then
        echo "El nombre del usuario no puede exceder los $limite caracteres."
        return 1
    fi
    return 0
}

agregarGrupo(){
    local nombreGrupo="$1"

    if ! validarGrupo "$nombreGrupo"; then
        echo "Nombre de grupo inválido"
        return 1
    fi

    if grupoExiste "$nombreGrupo"; then
        echo "El grupo '$nombreGrupo' ya existe. Elija otro nombre."
        return 1
    fi

    sudo groupadd "$nombreGrupo"
    sudo mkdir -p "/home/servidorftp/grupos/$nombreGrupo"
    sudo chgrp "$nombreGrupo" "/home/servidorftp/grupos/$nombreGrupo"
    sudo chmod 770 "/home/servidorftp/grupos/$nombreGrupo"
    echo "Grupo '$nombreGrupo' creado correctamente."
}

agregarUsuario(){
    local nombreUsuario="$1"

    if ! validarUsuario "$nombreUsuario"; then
        echo "Nombre de usuario inválido"
        return 1
    fi

    if usuarioExiste "$nombreUsuario"; then
        echo "El usuario '$nombreUsuario' ya existe. Elija otro nombre."
        return 1
    fi

    udo adduser "$nombreUsuario"
    sudo mkdir -p "/home/$nombreUsuario/$nombreUsuario"
    sudo mkdir -p "/home/$nombreUsuario/publico"
    sudo mkdir -p "/home/servidorftp/usuarios/$nombreUsuario"
    
    sudo chmod 700 "/home/$nombreUsuario/$nombreUsuario"
    sudo chmod 700 "/home/servidorftp/usuarios/$nombreUsuario"
    sudo chmod 755 "/home/$nombreUsuario/publico"
    
    sudo chown "$nombreUsuario":"$nombreUsuario" "/home/$nombreUsuario/$nombreUsuario"
    sudo chown "$nombreUsuario":"$nombreUsuario" "/home/servidorftp/usuarios/$nombreUsuario"
    sudo usermod -d "/home/$nombreUsuario" "$nombreUsuario"
    
    sudo mount --bind /home/servidorftp/usuarios/$nombreUsuario /home/$nombreUsuario/$nombreUsuario
    sudo mount --bind /home/servidorftp/publico /home/$nombreUsuario/publico
    echo "Usuario '$nombreUsuario' creado con acceso a su carpeta personal, pública y grupo."
}

asignarGrupoUsuario(){
    local usuario="$1"
    local grupo="$2"

    if ! usuarioExiste "$usuario"; then
        echo "El usuario '$usuario' no existe."
        return 1
    fi
    if ! grupoExiste "$grupo"; then
        echo "El grupo '$grupo' no existe."
        return 1
    fi
    
    gruposUsuario=$(id -Gn "$usuario" | tr ' ' '\n' | grep -Ev "^(users|$usuario)$")
    for g in $gruposUsuario; do
        sudo deluser "$usuario" "$g"
    done
    
    sudo adduser "$usuario" "$grupo"
    sudo mkdir -p "/home/$usuario/$grupo"
    sudo mount --bind "/home/servidorftp/grupos/$grupo" "/home/$usuario/$grupo"
    sudo chgrp "$grupo" "/home/$usuario/$grupo"
    sudo chmod 770 "/home/$usuario/$grupo"
    echo "Usuario '$usuario' asignado al grupo '$grupo' con acceso a su carpeta personal, pública y grupo."
}

cambiarGrupoUsuario(){
    read -p "Ingrese el usuario a cambiar de grupo: " usuario
    read -p "Ingrese el nuevo grupo: " nuevoGrupo

    if ! usuarioExiste "$usuario"; then
        echo "El usuario '$usuario' no existe."
        return 1
    fi
    if ! grupoExiste "$nuevoGrupo"; then
        echo "El grupo '$nuevoGrupo' no existe."
        return 1
    fi

    # Obtener el grupo actual del usuario
    grupoAnterior=$(id -Gn "$usuario" | tr ' ' '\n' | grep -Ev "^(users|general|$usuario)$")

    if [[ -n "$grupoAnterior" ]]; then
        echo "El usuario pertenece actualmente a '$grupoAnterior'. Eliminándolo..."

        # Desmontar la carpeta del grupo anterior si está montada
        if mountpoint -q "/home/$usuario/$grupoAnterior"; then
            sudo umount "/home/$usuario/$grupoAnterior"
        fi

        # Eliminar al usuario del grupo anterior
        sudo deluser "$usuario" "$grupoAnterior"

        # Eliminar la carpeta del grupo anterior si aún existe
        if [[ -d "/home/$usuario/$grupoAnterior" ]]; then
            sudo rm -rf "/home/$usuario/$grupoAnterior"
        fi
    fi

    # Asignar el usuario al nuevo grupo
    sudo adduser "$usuario" "$nuevoGrupo"
    sudo mkdir -p "/home/$usuario/$nuevoGrupo"
    sudo mount --bind "/home/servidorftp/grupos/$nuevoGrupo" "/home/$usuario/$nuevoGrupo"
    sudo chgrp "$nuevoGrupo" "/home/$usuario/$nuevoGrupo"

    echo "Grupo cambiado exitosamente a '$nuevoGrupo'."
}

usuarioExiste(){
    local usuario="$1"
    if id "$usuario" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

grupoExiste(){
    local grupo="$1"
    if getent group "$grupo" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}
