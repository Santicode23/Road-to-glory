# Solicitar datos al usuario
echo "Introduce la subred"
read SUBRED
echo "Introduce el rango de inicio de las direcciones IP "
read RANGO_INICIO
echo "Introduce el rango final de las direcciones IP "
read RANGO_FINAL

# Variables de configuración
INTERFAZ="enpOs8"  
MASCARA="255.255.255.0"
RUTEADOR="192.168.1.1"
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
