#!/bin/bash

# Verificar que se ejecute como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root" 
    exit 1
fi

# Función para cambiar de grupo a un usuario FTP
cambiar_user_grupo() {
    local FTP_USER NEW_GROUP

    # Pedir el nombre del usuario
    echo "Ingrese el nombre del usuario que desea cambiar de grupo:"
    read FTP_USER

    # Verificar si el usuario existe
    if ! id "$FTP_USER" &>/dev/null; then
        echo "Error: El usuario '$FTP_USER' no existe."
        return 1
    fi

    # Pedir el nuevo grupo
    echo "Seleccione el nuevo grupo:"
    echo "1) Reprobados"
    echo "2) Recursadores"
    read opc

    case $opc in
        1)
            NEW_GROUP="reprobados"
            ;;
        2)
            NEW_GROUP="recursadores"
            ;;
        *)
            echo "Error: Opción inválida."
            return 1
            ;;
    esac

    GROUPS_DIR="/home/ftp/grupos"
    USER_DIR="/home/ftp/users/$FTP_USER"
    CURRENT_GROUP=$(ls "$USER_DIR" | grep -E "reprobados|recursadores")

    if [[ "$CURRENT_GROUP" == "$NEW_GROUP" ]]; then
        echo "El usuario ya pertenece al grupo "$NEW_GROUP"...."
        return
    fi

    if [[ -z "$CURRENT_GROUP" ]]; then
        echo "No se encontró un grupo asignado en la carpeta del usuario."
        exit 1
    fi

    echo "Cambiando de grupo $CURRENT_GROUP a $NEW_GROUP para $FTP_USER..."
    sudo gpasswd -d $FTP_USER $CURRENT_GROUP
    sudo usermod -aG $NEW_GROUP $FTP_USER
    sudo fuser -k "$USER_DIR/$CURRENT_GROUP"
    # Desmontar la carpeta actual
    sudo umount "$USER_DIR/$CURRENT_GROUP"

    # Renombrar la carpeta
    sudo mv "$USER_DIR/$CURRENT_GROUP" "$USER_DIR/$NEW_GROUP"

    # Montar la nueva carpeta del grupo
    sudo mount --bind "/home/ftp/grupos/$NEW_GROUP" "$USER_DIR/$NEW_GROUP"

    echo "Cambio de grupo completado para $FTP_USER."
}

# Variables principales
FTP_ROOT="/home/ftp"
PUBLIC_DIR="$FTP_ROOT/publica"
USERS_DIR="$FTP_ROOT/users"
GROUPS_DIR="$FTP_ROOT/grupos"
VSFTPD_CONF="/etc/vsftpd.conf"

#Verificar si ya está instalado
if systemctl list-unit-files | grep -q "vsftpd"; then
    echo "vsftpd ya está instalado."
else
    echo "Instalando vsftpd..."
    sudo apt update && sudo apt install -y vsftpd 
    sudo groupadd reprobados
    sudo groupadd recursadores
    sudo groupadd ftpusers   
sudo sed -i 's/^anonymous_enable=.*/anonymous_enable=YES/' /etc/vsftpd.conf
sudo sed -i 's/^#\(local_enable=YES\)/\1/' /etc/vsftpd.conf
sudo sed -i 's/^#\(write_enable=YES\)/\1/' /etc/vsftpd.conf
sudo sed -i 's/^#\(chroot_local_user=YES\)/\1/' /etc/vsftpd.conf
sudo tee -a $VSFTPD_CONF > /dev/null <<EOF
allow_writeable_chroot=YES
anon_root=$FTP_ROOT/anon
EOF
fi

# Preguntar si se desea cambiar de grupo a un usuario
read -p "¿Desea cambiar el grupo de un usuario FTP? (s/n): " RESPUESTA
if [[ "$RESPUESTA" == "s" || "$RESPUESTA" == "S" ]]; then
    cambiar_user_grupo
fi

# Solicitar datos
read -p "Ingrese el nombre del usuario FTP: " FTP_USER
read -p "Ingrese el grupo principal del usuario (ej: reprobados, recursadores): " FTP_GROUP

# Crear estructura de carpetas
echo "Creando estructura de directorios..."
sudo mkdir -p "$PUBLIC_DIR" "$USERS_DIR" "$GROUPS_DIR"
sudo mkdir -p "$GROUPS_DIR/reprobados"
sudo mkdir -p "$GROUPS_DIR/recursadores"
sudo mkdir -p "$FTP_ROOT/anon/publica"

# Asignar permisos a grupos
echo "Configurando permisos..."
sudo chmod 770 "$GROUPS_DIR/reprobados"
sudo chmod 770 "$GROUPS_DIR/recursadores"
sudo chown root:reprobados "$GROUPS_DIR/reprobados"
sudo chown root:recursadores "$GROUPS_DIR/recursadores"

# Permisos generales
sudo chmod 755 /home/ftp
sudo chmod 775 "$PUBLIC_DIR"
sudo chown root:ftpusers "$PUBLIC_DIR"

# Crear usuario FTP
echo "Creando usuario $FTP_USER..."
sudo useradd -m -d "$USERS_DIR/$FTP_USER" -s /usr/sbin/nologin "$FTP_USER"
sudo passwd "$FTP_USER"
sudo usermod -aG "$FTP_GROUP" "$FTP_USER"
sudo usermod -aG "ftpusers" "$FTP_USER"

# Crear carpetas del usuario
echo "Configurando carpetas para $FTP_USER..."
sudo mkdir -p "$USERS_DIR/$FTP_USER/publica"
sudo mkdir -p "$USERS_DIR/$FTP_USER/$FTP_GROUP"

# Enlazar carpetas con mount --bind
sudo mkdir -p "$USERS_DIR/$FTP_USER/$FTP_USER"
sudo chmod 700 "$USERS_DIR/$FTP_USER/$FTP_USER"
sudo chown -R "$FTP_USER:$FTP_USER" "$USERS_DIR/$FTP_USER/"
sudo mount --bind "$GROUPS_DIR/$FTP_GROUP" "$USERS_DIR/$FTP_USER/$FTP_GROUP"
sudo mount --bind "$PUBLIC_DIR" "$USERS_DIR/$FTP_USER/publica"
sudo mount --bind "$PUBLIC_DIR" "$FTP_ROOT/anon/publica"

# Agregar montajes persistentes a /etc/fstab
#echo "$USERS_DIR/$FTP_USER $USERS_DIR/$FTP_USER/$FTP_USER none bind 0 0" | sudo tee -a /etc/fstab
# echo "$GROUPS_DIR/$FTP_GROUP $USERS_DIR/$FTP_USER/$FTP_GROUP none bind 0 0" | sudo tee -a /etc/fstab
# echo "$PUBLIC_DIR $USERS_DIR/$FTP_USER/publica none bind 0 0" | sudo tee -a /etc/fstab

sudo chmod 750 "$USERS_DIR/$FTP_USER"
sudo chown -R "$FTP_USER:ftpusers" "$USERS_DIR/$FTP_USER"

# Asignar grupo al directorio correspondiente

# Configuración individual del usuario
echo "Configurando acceso para $FTP_USER..."
sudo passwd -u "$FTP_USER"
sudo usermod -s /bin/bash "$FTP_USER"

# Reiniciar servicio vsftpd
echo "Reiniciando servicio FTP..."
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd

# Asegurar configuración del sistema
echo "Configurando seguridad..."
sudo chmod 755 /home/ftp

# Abrir puertos en firewall
echo "Configurando firewall..."
sudo ufw allow 21/tcp
#Fijar la IP
echo "network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses: [18.0.0.10/24]
      nameservers:
        addresses: [8.8.8.8]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
echo "Fijando la IP"

#Aplicar cambios
sudo netplan apply
echo "Aplicando cambios"

echo "Configuración completa. Prueba acceder con un cliente FTP."
