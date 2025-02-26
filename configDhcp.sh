get_subnet() {
    read -p "Introduce la subred: " SUBRED
    echo $SUBRED
}

get_range_start() {
    read -p "Introduce el rango de inicio de las direcciones IP: " RANGO_INICIO
    echo $RANGO_INICIO
}

get_range_end() {
    read -p "Introduce el rango final de las direcciones IP: " RANGO_FINAL
    echo $RANGO_FINAL
}

get_server_ip() {
    read -p "Ingrese la dirección IP del servidor DHCP: " SERVER_IP
    echo $SERVER_IP
}

configure_network() {
    local ip=$1
    echo "network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
    enp0s8:
      addresses: [$ip/24]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
    sudo netplan apply
}

install_dhcp() {
    sudo apt update -y
    if ! dpkg -l | grep -q isc-dhcp-server; then
        sudo apt install isc-dhcp-server -y
    fi
}

configure_dhcp() {
    local subnet=$1
    local range_start=$2
    local range_end=$3
    local server_ip=$4
    local interfaz="enp0s8"
    local mascara="255.255.255.0"
    local ruteador="192.168.0.1"
    local dns="8.8.8.8, 8.8.4.4"
    local tiempo_concesion="600"
    
    sudo sed -i "s/INTERFACESv4=.*/INTERFACESv4=\"$interfaz\"/" /etc/default/isc-dhcp-server

    cat <<EOL | sudo tee /etc/dhcp/dhcpd.conf
option domain-name "local";
option domain-name-servers $dns;
default-lease-time $tiempo_concesion;
max-lease-time $(($tiempo_concesion * 2));

subnet $subnet netmask $mascara {
    range $range_start $range_end;
    option routers $ruteador;
    option subnet-mask $mascara;
    option domain-name-servers $dns;
}
EOL
}

restart_dhcp() {
    sudo systemctl restart isc-dhcp-server
    sudo systemctl enable isc-dhcp-server
    echo "Estado del servicio DHCP:"
    sudo systemctl status isc-dhcp-server --no-pager
}
