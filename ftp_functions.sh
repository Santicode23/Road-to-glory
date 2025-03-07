#!/usr/bin/env bash

configurarFTP(){
    echo "Instalando servicio FTP..."
    sudo apt-get install -y vsftpd
    echo "Servicio FTP instalado correctamente."
    
    configurarVsftpd
    inicializarDirectorios
    sudo systemctl restart vsftpd
}

configurarVsftpd(){
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    sudo sed -i 's/^#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd.conf
    sudo sed -i 's/^chroot_local_user=NO/chroot_local_user=YES/g' /etc/vsftpd.conf
    echo "allow_writeable_chroot=YES" | sudo tee -a /etc/vsftpd.conf
    echo "local_root=/home/servidorftp/usuarios/\$USER" | sudo tee -a /etc/vsftpd.conf
}

inicializarDirectorios(){
    sudo mkdir -p /home/servidorftp/{grupos,usuarios,publico}
    sudo chmod -R 755 /home/servidorftp/publico
    sudo chown -R root:root /home/servidorftp/publico
}

validarNombre(){
    local nombre="$1"
    local limite="$2"
    if [[ -z "$nombre" || ! "$nombre" =~ ^[a-zA-Z0-9_-]+$ || ${#nombre} -gt $limite ]]; then
        return 1
    fi
    return 0
}

agregarGrupo(){
    local nombreGrupo="$1"
    if ! validarNombre "$nombreGrupo" 15; then
        echo "Nombre de grupo inválido"
        return 1
    fi
    if getent group "$nombreGrupo" > /dev/null; then
        echo "El grupo '$nombreGrupo' ya existe."
        return 1
    fi
    sudo groupadd "$nombreGrupo"
    sudo mkdir -p /home/servidorftp/grupos/$nombreGrupo
    sudo chown root:"$nombreGrupo" /home/servidorftp/grupos/$nombreGrupo
    sudo chmod 770 /home/servidorftp/grupos/$nombreGrupo
    echo "Grupo '$nombreGrupo' creado correctamente."
}

agregarUsuario(){
    local nombreUsuario="$1"
    if ! validarNombre "$nombreUsuario" 20; then
        echo "Nombre de usuario inválido"
        return 1
    fi
    if id "$nombreUsuario" &>/dev/null; then
        echo "El usuario '$nombreUsuario' ya existe."
        return 1
    fi
    sudo adduser --home /home/servidorftp/usuarios/$nombreUsuario --shell /usr/sbin/nologin "$nombreUsuario"
    sudo mkdir -p /home/servidorftp/usuarios/$nombreUsuario/{personal,publico}
    sudo chmod 700 /home/servidorftp/usuarios/$nombreUsuario/personal
    sudo chmod 755 /home/servidorftp/usuarios/$nombreUsuario/publico
    sudo chown -R "$nombreUsuario":"$nombreUsuario" /home/servidorftp/usuarios/$nombreUsuario
    sudo mount --bind /home/servidorftp/publico /home/servidorftp/usuarios/$nombreUsuario/publico
    echo "Usuario '$nombreUsuario' agregado correctamente."
}

asignarGrupoUsuario(){
    local usuario="$1"
    local grupo="$2"
    if ! id "$usuario" &>/dev/null; then
        echo "El usuario '$usuario' no existe."
        return 1
    fi
    if ! getent group "$grupo" > /dev/null; then
        echo "El grupo '$grupo' no existe."
        return 1
    fi
    sudo adduser "$usuario" "$grupo"
    sudo mkdir -p /home/servidorftp/usuarios/$usuario/$grupo
    sudo chown "$usuario":"$grupo" /home/servidorftp/usuarios/$usuario/$grupo
    sudo chmod 770 /home/servidorftp/usuarios/$usuario/$grupo
    sudo mount --bind /home/servidorftp/grupos/$grupo /home/servidorftp/usuarios/$usuario/$grupo
    echo "Grupo '$grupo' asignado correctamente a '$usuario'."
}

cambiarGrupoUsuario(){
    local usuario="$1"
    local nuevoGrupo="$2"
    if ! id "$usuario" &>/dev/null; then
        echo "El usuario '$usuario' no existe."
        return 1
    fi
    if ! getent group "$nuevoGrupo" > /dev/null; then
        echo "El grupo '$nuevoGrupo' no existe."
        return 1
    fi
    grupoAnterior=$(id -Gn "$usuario" | tr ' ' '\n' | grep -Ev "^(users|general|$usuario)$")
    if [[ -n "$grupoAnterior" ]]; then
        echo "El usuario pertenece actualmente a '$grupoAnterior'. Eliminándolo..."
        if mountpoint -q "/home/servidorftp/usuarios/$usuario/$grupoAnterior"; then
            sudo umount "/home/servidorftp/usuarios/$usuario/$grupoAnterior"
        fi
        sudo deluser "$usuario" "$grupoAnterior"
        sudo rm -rf "/home/servidorftp/usuarios/$usuario/$grupoAnterior"
    fi
    sudo adduser "$usuario" "$nuevoGrupo"
    sudo mkdir -p "/home/servidorftp/usuarios/$usuario/$nuevoGrupo"
    sudo mount --bind "/home/servidorftp/grupos/$nuevoGrupo" "/home/servidorftp/usuarios/$usuario/$nuevoGrupo"
    sudo chown "$usuario":"$nuevoGrupo" "/home/servidorftp/usuarios/$usuario/$nuevoGrupo"
    echo "Grupo cambiado exitosamente a '$nuevoGrupo'."
}

reiniciarFTP(){
    sudo systemctl restart vsftpd
    echo "Servicio FTP reiniciado."
}
