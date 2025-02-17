# Función para validar la dirección IP
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                echo "IP inválida: fuera de rango"
                exit 1
            fi
        done
    else
        echo "Formato de IP inválido"
        exit 1
    fi
}

# Solicitar datos al usuario
echo "Introduce la subred"
read SUBRED
echo "Introduce el rango de inicio de las direcciones IP "
read RANGO_INICIO
echo "Introduce el rango final de las direcciones IP "
read RANGO_FINAL
# Solicitar la IP del servidor DHCP
read -p "Ingrese la dirección IP del servidor DHCP: " SERVER_IP
validate_ip $SERVER_IP

#Fijar la IP
echo "network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses: [$SERVER_IP/24]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
echo "Fijando la IP $SERVER_IP"

#Aplicar cambios
sudo netplan apply
echo "Aplicando cambios"

# Variables de configuración
INTERFAZ="enp0s8"  
MASCARA="255.255.255.0"
RUTEADOR="192.168.0.1"
DNS="8.8.8.8, 8.8.4.4"
TIEMPO_CONCESION="600" 

# Actualizar paquetes
apt update -y

# Instalar el servidor DHCP si no está instalado
if ! dpkg -l | grep -q isc-dhcp-server; then
    apt install isc-dhcp-server -y
fi

# Configurar la interfaz de red para el DHCP
sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$INTERFAZ\"/" /etc/default/isc-dhcp-server

# Configurar el archivo dhcpd.conf
cat <<EOL > /etc/dhcp/dhcpd.conf
option domain-name "local";
option domain-name-servers $DNS;
default-lease-time $TIEMPO_CONCESION;
max-lease-time $(($TIEMPO_CONCESION * 2));

subnet $SUBRED netmask $MASCARA {
    range $RANGO_INICIO $RANGO_FINAL;
    option routers $RUTEADOR;
    option subnet-mask $MASCARA;
    option domain-name-servers $DNS;
}
EOL

# Reiniciar el servicio DHCP
systemctl restart isc-dhcp-server
systemctl enable isc-dhcp-server

# Verificar el estado del servicio
echo "Estado del servicio DHCP:"
systemctl status isc-dhcp-server --no-pager
