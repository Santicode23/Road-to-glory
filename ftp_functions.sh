#!/usr/bin/env bash

configurarFTP(){
    echo "Instalando servicio FTP..."
    sudo apt-get install vsftpd -y
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
    fi
    
    if ! sudo grep -q "^write_enable=.*" /etc/vsftpd.conf; then
        sudo mount --bind /home/servidorftp/publico /acceso_anonimo/publico
        echo "write_enable=YES" | sudo tee -a /etc/vsftpd.conf
        echo "anon_root=/acceso_anonimo" | sudo tee -a /etc/vsftpd.conf
    fi

    # Configurar acceso de usuarios locales
    for param in "local_enable=YES" "write_enable=YES" "chroot_local_user=YES" "allow_writeable_chroot=YES"; do
        if ! sudo grep -q "^$param" /etc/vsftpd.conf; then
            echo "$param" | sudo tee -a /etc/vsftpd.conf
        fi
    done
    
    # Reiniciar el servicio para aplicar los cambios
    sudo systemctl restart vsftpd
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

    # Solo permitir los grupos 'reprobados' y 'recursadores'
    if [[ "$nombreGrupo" != "reprobados" && "$nombreGrupo" != "recursadores" ]]; then
        echo "Solo se permiten los grupos 'reprobados' y 'recursadores'."
        return 1
    fi

    if grupoExiste "$nombreGrupo"; then
        echo "El grupo '$nombreGrupo' ya existe."
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

    # Solo permitir los grupos 'reprobados' y 'recursadores'
    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Solo se pueden asignar los grupos 'reprobados' o 'recursadores'."
        return 1
    fi

    if ! usuarioExiste "$usuario"; then
        echo "El usuario '$usuario' no existe."
        return 1
    fi
    if ! grupoExiste "$grupo"; then
        echo "El grupo '$grupo' no existe."
        return 1
    fi
    
    # Obtener todos los grupos del usuario y evitar que tenga más de uno
    gruposUsuario=$(id -Gn "$usuario" | tr ' ' '\n' | grep -Ev "^(users|general|$usuario)$")
    if [[ -n "$gruposUsuario" ]]; then
        echo "El usuario '$usuario' ya pertenece a '$gruposUsuario'. Use la opción para cambiar de grupo."
        return 1
    fi

    sudo usermod -g "$grupo" "$usuario"
    sudo adduser "$usuario" "$grupo"
    sudo chmod 770 "/home/servidorftp/grupos/$grupo"
    sudo mkdir -p "/home/$usuario/$grupo"
    sudo mount --bind "/home/servidorftp/grupos/$grupo" "/home/$usuario/$grupo"
    sudo chown "$usuario:$grupo" "/home/$usuario/$grupo"
    
    echo "Grupo '$grupo' asignado correctamente a '$usuario'."
}


cambiarGrupoUsuario(){
    read -p "Ingrese el usuario a cambiar de grupo: " usuario

    if ! usuarioExiste "$usuario"; then
        echo "El usuario '$usuario' no existe."
        return 1
    fi

    # Detectar el grupo actual del usuario
    grupo_actual=""
    usuario_path="/home/$usuario"

    if [[ -d "$usuario_path/reprobados" ]]; then
        grupo_actual="reprobados"
    elif [[ -d "$usuario_path/recursadores" ]]; then
        grupo_actual="recursadores"
    else
        echo "El usuario no tiene grupo asignado."
        return 1
    fi

    # Pedir el nuevo grupo
    read -p "Ingrese el nuevo grupo: " nuevoGrupo
    if ! grupoExiste "$nuevoGrupo"; then
        echo "El grupo '$nuevoGrupo' no existe."
        return 1
    fi

    if [[ "$grupo_actual" == "$nuevoGrupo" ]]; then
        echo "El usuario ya pertenece a '$nuevoGrupo'."
        return 1
    fi

    # Desmontar la carpeta del grupo anterior si está montada
    if mountpoint -q "$usuario_path/$grupo_actual"; then
        echo "Desmontando carpeta de grupo anterior: $grupo_actual"
        sudo fuser -k "$usuario_path/$grupo_actual" || true
        sudo umount -l "$usuario_path/$grupo_actual"
    fi

    # Remover al usuario del grupo anterior
    sudo deluser "$usuario" "$grupo_actual"

    # Asignar al usuario el nuevo grupo
    sudo usermod -g "$nuevoGrupo" "$usuario"
    sudo adduser "$usuario" "$nuevoGrupo"

    # Asegurar que la carpeta del nuevo grupo existe y asignar permisos
    sudo mkdir -p "$usuario_path/$nuevoGrupo"
    sudo chown "$usuario:$nuevoGrupo" "$usuario_path/$nuevoGrupo"
    sudo chmod 770 "$usuario_path/$nuevoGrupo"

    # Montar la carpeta del nuevo grupo
    echo "Montando carpeta del nuevo grupo: $nuevoGrupo"
    sudo mount --bind "/home/servidorftp/grupos/$nuevoGrupo" "$usuario_path/$nuevoGrupo"

    # Actualizar permisos de archivos
    sudo chown -R "$usuario:$nuevoGrupo" "$usuario_path"
    sudo chmod -R 770 "$usuario_path"

    # Reiniciar servicio FTP para aplicar cambios
    sudo systemctl restart vsftpd

    echo "El usuario '$usuario' ahora pertenece a '$nuevoGrupo'."
}

usuarioExiste(){
    local usuario="$1"
    echo "[DEBUG] Verificando usuario: $usuario"
    
    if id "$usuario" &>/dev/null; then
        echo "Usuario '$usuario' existe."
        return 0
    else
        echo "Usuario '$usuario' NO existe."
        echo "[DEBUG] Lista de usuarios disponibles:"
        awk -F: '{print $1}' /etc/passwd  # Muestra los usuarios actuales
        return 1
    fi
}

grupoExiste(){
    local grupo="$1"
    echo "[DEBUG] Verificando grupo: $grupo"

    if getent group "$grupo" > /dev/null 2>&1; then
        echo "Grupo '$grupo' existe."
        return 0
    else
        echo "Grupo '$grupo' NO existe."
        echo "[DEBUG] Lista de grupos disponibles:"
        getent group | awk -F: '{print $1}'  # Muestra los grupos actuales
        return 1
    fi
}
