get_domain() {
    read -p "Ingrese el nombre del dominio: " DOMAIN
    echo $DOMAIN
}

get_server_ip() {
    read -p "Ingrese la dirección IP del servidor DNS: " SERVER_IP
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
        addresses: [8.8.8.8, 1.1.1.1]" | sudo tee /etc/netplan/50-cloud-init.yaml > /dev/null
    sudo netplan apply
}


install_bind() {
    sudo apt-get install -y bind9 bind9utils bind9-doc dnsutils
}

configure_bind() {
    local domain=$1
    local server_ip=$2
    local zone_file="/etc/bind/db.$domain"
    local rev_zone_file="/etc/bind/db.$(echo $server_ip | awk -F. '{print $3"."$2"."$1}')"

    echo "zone \"$domain\" {\n    type master;\n    file \"$zone_file\";\n};\n\nzone \"192.in-addr.arpa\" {\n    type master;\n    file \"$rev_zone_file\";\n};" | sudo tee -a /etc/bind/named.conf.local

    echo "\$TTL 604800\n@   IN  SOA $domain. root.$domain. (\n        2\n        604800\n        86400\n        2419200\n        604800 )\n@    IN  NS  $domain.\n@    IN  A   $server_ip\nwww  IN  CNAME   $domain." | sudo tee $zone_file

    echo "\$TTL 604800\n@   IN  SOA $domain. root.$domain. (\n        2\n        604800\n        86400\n        2419200\n        604800 )\n@   IN  NS  $domain.\n$(echo $server_ip | awk -F. '{print $4}') IN  PTR   $domain." | sudo tee $rev_zone_file
    
    sudo systemctl restart bind9
}


restart_bind() {
    sudo systemctl restart bind9
    echo "Servicio BIND9 reiniciado correctamente."
}