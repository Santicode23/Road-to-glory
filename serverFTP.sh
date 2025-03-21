#!/bin/bash

configurar_ftp() {
    # Copia de seguridad del archivo original
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    # Configuración básica de vsftpd
    sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
# Usuarios locales
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
listen=YES
listen_ipv6=NO
pam_service_name=vsftpd
user_sub_token=\$USER
chroot_local_user=YES
allow_writeable_chroot=YES
local_root=/srv/ftp/\$USER

# Usuario anonimo
anonymous_enable=NO
anon_root=/srv/ftp/anon
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO

# Modo pasivo
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
EOF

    sudo systemctl restart vsftpd
    sudo systemctl enable vsftpd
}

# Función para crear la estructura de directorios FTP
crear_carpetas() {
    FTP_ROOT="/srv/ftp"

    sudo mkdir -p $FTP_ROOT/{linux/windows}/{Apache,Tomcat,Nginx}
    
    sudo chmod -R 755 $FTP_ROOT
    sudo chown -R root:root $FTP_ROOT
}

# Función para crear usuarios FTP
crear_usuarios() {
    # Crear usuario "linux"
    if ! id "linux" &>/dev/null; then
        sudo useradd -m -d /srv/ftp/linux -s /bin/bash linux
        echo "linux:1234" | sudo chpasswd
    fi
    
    # Crear usuario "windows"
    if ! id "windows" &>/dev/null; then
        sudo useradd -m -d /srv/ftp/windows -s /bin/bash windows
        echo "windows:1234" | sudo chpasswd
    fi

    # Asignar permisos a sus respectivas carpetas
    sudo chown -R linux:linux /srv/ftp/linux
    sudo chmod -R 750 /srv/ftp/linux

    sudo chown -R windows:windows /srv/ftp/windows
    sudo chmod -R 750 /srv/ftp/windows
}

# Función para configurar SSL en vsftpd
configurar_ssl() {
    echo "Configurando SSL..."
    
    # Crear certificado autofirmado si no existe
    if [[ ! -f /etc/ssl/certs/vsftpd.pem ]]; then
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/vsftpd.pem \
            -out /etc/ssl/certs/vsftpd.pem \
            -subj "/C=MX/ST=Example/L=Example/O=Example/OU=FTP/CN=localhost"
    fi

    # Agregar configuración de SSL en vsftpd.conf
    sudo bash -c 'cat >> /etc/vsftpd.conf' <<EOF
ssl_enable=YES
rsa_cert_file=/etc/ssl/certs/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
force_local_logins_ssl=YES
force_local_data_ssl=YES
EOF

    sudo systemctl restart vsftpd
}

sudo apt install -y vsftpd 
configurar_ftp
crear_carpetas
crear_usuarios
sudo ufw allow 20/tcp
sudo ufw allow 21/tcp
sudo ufw allow 40000:50000/tcp
