#!/usr/bin/env bash

configurarFTP(){
    echo "Instalando servicio FTP..."
    sudo apt-get install vsftpd
    clear
    echo "Servicio FTP instalado correctamente."
    
    inicializarDirectorios
}

inicializarDirectorios(){
    if [ -d "/home/servidorftp" ]; then
        echo "El directorio FTP ya existe."
    else
        sudo mkdir /home/servidorftp
    fi

    for carpeta in "grupos" "usuarios" "publico"; do
        if [ ! -d "/home/servidorftp/$carpeta" ]; then
            sudo mkdir /home/servidorftp/$carpeta
        fi
    done
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
    local limite=20
    if [ -n "$nombreGrupo" ] && [ ${#nombreGrupo} -le $limite ]; then
        return 1
    else
        return 0
    fi
}

validarUsuario(){
    local nombreUsuario="$1"
    local limite=20
    if [ -n "$nombreUsuario" ] && [ ${#nombreUsuario} -le $limite ]; then
        return 1
    else
        return 0
    fi
}

agregarGrupo(){
    local nombreGrupo="$1"
    if validarGrupo "$nombreGrupo"; then
        echo "Nombre de grupo inválido"
        while validarGrupo "$nombreGrupo"; do
            read -p "Ingrese nuevamente el nombre del grupo: " nombreGrupo
        done
    fi

    if grupoExiste "$nombreGrupo"; then
        echo "El grupo ya existe"
        while grupoExiste "$nombreGrupo"; do
            read -p "Ingrese nuevamente el nombre del grupo: " nombreGrupo
        done
    fi

    sudo groupadd $nombreGrupo
    sudo mkdir /home/servidorftp/grupos/$nombreGrupo
    sudo chgrp $nombreGrupo /home/servidorftp/grupos/$nombreGrupo
    echo "Grupo creado correctamente."
}

agregarUsuario(){
    local nombreUsuario="$1"
    if validarUsuario "$nombreUsuario"; then
        echo "Nombre de usuario inválido"
        while validarUsuario "$nombreUsuario"; do
            read -p "Ingrese nuevamente el nombre del usuario: " nombreUsuario
        done
    fi

    if usuarioExiste "$nombreUsuario"; then
        echo "El usuario ya existe"
        while usuarioExiste "$nombreUsuario"; do
            read -p "Ingrese nuevamente el nombre del usuario: " nombreUsuario
        done
    fi

    sudo adduser $nombreUsuario
    sudo mkdir -p /home/$nombreUsuario/{personal,publico}
    sudo mkdir /home/servidorftp/usuarios/$nombreUsuario
    sudo chmod 700 /home/$nombreUsuario/personal /home/servidorftp/usuarios/$nombreUsuario
    sudo chmod 777 /home/servidorftp/publico
    sudo chown $nombreUsuario /home/servidorftp/usuarios/$nombreUsuario
    sudo chown $nombreUsuario /home/$nombreUsuario/personal
    sudo mount --bind /home/servidorftp/usuarios/$nombreUsuario /home/$nombreUsuario/personal
    sudo mount --bind /home/servidorftp/publico /home/$nombreUsuario/publico
    echo "Usuario creado exitosamente."
}

asignarGrupoUsuario(){
    local usuario="$1"
    local grupo="$2"
    sudo adduser $usuario $grupo
    sudo chmod 774 /home/servidorftp/grupos/$grupo
    sudo mkdir /home/$usuario/$grupo
    sudo mount --bind /home/servidorftp/grupos/$grupo /home/$usuario/$grupo
    echo "Grupo asignado correctamente."
}

cambiarGrupoUsuario(){
    read -p "Ingrese el usuario a cambiar de grupo: " usuario
    read -p "Ingrese el nuevo grupo: " nuevoGrupo
    grupoAnterior=$(groups "$usuario" | awk '{print $5}')
    sudo umount /home/$usuario/$grupoAnterior || { echo "Error al desmontar directorio."; exit 1; }
    sudo deluser $usuario $grupoAnterior
    sudo adduser $usuario $nuevoGrupo
    sudo mv /home/$usuario/$grupoAnterior /home/$usuario/$nuevoGrupo
    sudo mount --bind /home/servidorftp/grupos/$nuevoGrupo /home/$usuario/$nuevoGrupo
    sudo chgrp $nuevoGrupo /home/$usuario/$nuevoGrupo
    echo "Grupo cambiado exitosamente."
}

usuarioExiste(){
    local usuario="$1"
    id "$usuario" &> /dev/null
    return $?
}

grupoExiste(){
    local grupo="$1"
    getent group "$grupo" > /dev/null 2>&1
    return $?
}
