#!/bin/bash

# ==============================
# Configurar un servidor FTP con vsftpd
# ==============================

# Función para instalar vsftpd y dependencias
instalar_vsftpd() {
    echo "Instalando vsftpd y herramientas necesarias..."
    sudo apt update && sudo apt install -y vsftpd acl ufw
}

# Función para configurar vsftpd
configurar_vsftpd() {
    echo "Configurando vsftpd..."
    
    # Copia de seguridad del archivo original
    sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.bak

    # Configuración básica de vsftpd
    sudo bash -c 'cat > /etc/vsftpd.conf' <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
pam_service_name=vsftpd
user_sub_token=\$USER
chroot_local_user=YES
allow_writeable_chroot=YES
local_root=/srv/ftp/\$USER
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
ftpd_banner=Bienvenido al servidor FTP.
EOF

    echo "vsftpd configurado. Reiniciando servicio..."
    sudo systemctl restart vsftpd
    sudo systemctl enable vsftpd
}

# Función para crear la estructura de directorios FTP
crear_estructura_ftp() {
    FTP_ROOT="/srv/ftp"
    echo "Creando estructura de directorios FTP..."
    
    # Crear carpetas principales
    sudo mkdir -p $FTP_ROOT/{linux,windows}/{apache,tomcat,nginx}
    
    # Establecer permisos y propietarios
    sudo chmod -R 755 $FTP_ROOT
    sudo chown -R root:root $FTP_ROOT
    
    echo "Estructura de directorios creada con éxito."
}

# Función para crear usuarios FTP
crear_usuarios_ftp() {
    echo "Creando usuarios FTP..."

    # Crear usuario "linux"
    if ! id "linux" &>/dev/null; then
        sudo useradd -m -d /srv/ftp/linux -s /usr/sbin/nologin linux
        echo "linux:123" | sudo chpasswd
    fi
    
    # Crear usuario "windows"
    if ! id "windows" &>/dev/null; then
        sudo useradd -m -d /srv/ftp/windows -s /bin/bash windows
        echo "windows:123" | sudo chpasswd
    fi

    # Asignar permisos a sus respectivas carpetas
    sudo chown -R linux:linux /srv/ftp/linux
    sudo chmod -R 750 /srv/ftp/linux

    sudo chown -R windows:windows /srv/ftp/windows
    sudo chmod -R 750 /srv/ftp/windows

    echo "Usuarios FTP creados y permisos aplicados."
}

# Función para habilitar reglas de firewall para FTP
configurar_firewall() {
    echo "Configurando reglas de firewall para FTP..."
    sudo ufw allow 21/tcp
    sudo ufw allow 40000:50000/tcp
    sudo ufw enable
    echo "Reglas de firewall aplicadas."
}

# Función para configurar SSL en vsftpd
configurar_ssl_vsftpd() {
    echo "Configurando SSL en vsftpd..."
    
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

    echo "SSL configurado en vsftpd. Reiniciando servicio..."
    sudo systemctl restart vsftpd
}

# ==============================
# Ejecución del script
# ==============================
instalar_vsftpd
configurar_vsftpd
crear_estructura_ftp
crear_usuarios_ftp
configurar_firewall

read -p "¿Desea habilitar SSL en vsftpd? (s/n): " respuesta_ssl
if [[ "$respuesta_ssl" == "s" || "$respuesta_ssl" == "S" ]]; then
    configurar_ssl_vsftpd
fi

echo "Servidor FTP configurado con éxito."
