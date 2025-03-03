#!/bin/bash

# Definicion de variables
FTP_DIR="/srv/ftp"
GROUP_REPROBADOS="reprobados"
GROUP_RECURSADORES="recursadores"
FTP_USERS_DIR="/srv/ftp/users"
MOUNT_DIR="/mnt/ftp_mount"

# Funcion para instalar y configurar vsftpd
install_vsftpd() {
    echo "Instalando vsftpd..."
    apt update && apt install -y vsftpd
    systemctl enable vsftpd
    #Fijar la IP
    echo "network:
    version: 2
    renderer: networkd
    ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses: [192.169.0.10/24]
      gateway4: 192.168.0.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
    echo "Fijando la IP"
    sudo netplan apply
}

# Funcion para configurar vsftpd
configure_vsftpd() {
    echo "Configurando vsftpd..."
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    cat > /etc/vsftpd.conf <<EOL
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
anon_root=$FTP_DIR
chroot_local_user=YES
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
ssl_enable=YES
force_local_data_ssl=YES
force_local_logins_ssl=YES
rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
EOL
    systemctl restart vsftpd
}

# Funcion para abrir puertos en el firewall
configure_firewall() {
    echo "Abriendo puertos FTP en el firewall..."
    ufw allow 20/tcp
    ufw allow 21/tcp
    ufw allow 40000:50000/tcp
    ufw enable
    ufw reload
}

# Funcion para crear grupos y carpetas
setup_groups_and_dirs() {
    echo "Creando grupos y directorios..."
    groupadd -f $GROUP_REPROBADOS
    groupadd -f $GROUP_RECURSADORES
    mkdir -p $FTP_DIR/general $FTP_USERS_DIR
    mkdir -p $MOUNT_DIR/general $MOUNT_DIR/reprobados $MOUNT_DIR/recursadores
    chmod 755 $FTP_DIR/general
    chmod 770 $MOUNT_DIR/reprobados $MOUNT_DIR/recursadores
}

# Funcion para agregar un usuario
add_user() {
    echo "Ingrese el nombre del usuario:"
    read username
    echo "Ingrese la contraseña para $username:"
    read -s password
    useradd -m -s /bin/false $username
    echo "$username:$password" | chpasswd
    echo "Seleccione el grupo:"
    echo "1) Reprobados"
    echo "2) Recursadores"
    read group_choice
    if [[ "$group_choice" == "1" ]]; then
        usermod -aG $GROUP_REPROBADOS $username
    elif [[ "$group_choice" == "2" ]]; then
        usermod -aG $GROUP_RECURSADORES $username
    else
        echo "Opcion invalida. Usuario creado sin grupo."
    fi
    mkdir -p $FTP_USERS_DIR/$username
    mkdir -p $MOUNT_DIR/$username
    chown $username:$username $FTP_USERS_DIR/$username
    chmod 750 $FTP_USERS_DIR/$username
    mount --bind $FTP_USERS_DIR/$username $MOUNT_DIR/$username
    echo "Usuario $username creado y asignado correctamente."
}

# Funcion para cambiar de grupo a un usuario
change_user_group() {
    echo "Ingrese el nombre del usuario a modificar:"
    read username
    echo "Seleccione el nuevo grupo:"
    echo "1) Reprobados"
    echo "2) Recursadores"
    read new_group_choice
    if [[ "$new_group_choice" == "1" ]]; then
        usermod -g $GROUP_REPROBADOS $username
    elif [[ "$new_group_choice" == "2" ]]; then
        usermod -g $GROUP_RECURSADORES $username
    else
        echo "Opcion invalida."
    fi
    echo "Grupo de $username cambiado correctamente."
}

# Menu principal
main_menu() {
    while true; do
        echo "\nSeleccione una opcion:"
        echo "1) Instalar y configurar vsftpd"
        echo "2) Configurar firewall"
        echo "3) Crear grupos y directorios"
        echo "4) Agregar usuario"
        echo "5) Cambiar usuario de grupo"
        echo "6) Salir"
        read choice
        case $choice in
            1) install_vsftpd && configure_vsftpd ;;
            2) configure_firewall ;;
            3) setup_groups_and_dirs ;;
            4) add_user ;;
            5) change_user_group ;;
            6) exit 0 ;;
            *) echo "Opcion invalida." ;;
        esac
    done
}

main_menu
