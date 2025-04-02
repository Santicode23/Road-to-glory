#!/bin/bash
# correo/conf_dns.sh

source "./verificar_servicio.sh"

conf_dns(){
    local ip="$1"
    local dominio="$2"
    #Instalar bind9

    echo "Instalando bind9"
    sudo apt-get install bind9 bind9utils bind9-doc -y
    sudo apt-get install dnsutils -y

    #Editar named.conf.local para las zonas
    echo "Configurando zonas"
    sudo tee -a /etc/bind/named.conf.local > /dev/null <<EOF
    zone "$dominio" {
        type master;
        file "/etc/bind/db.$dominio";
    };

    zone "$(echo $ip | awk -F. '{print $3"."$2"."$1}').in-addr.arpa" {
        type master;
        file "/etc/bind/db.$(echo $ip | awk -F. '{print $3"."$2"."$1}')";
    };
EOF

#Crear zona directa
echo "Creando zona directa"
sudo tee /etc/bind/db.$dominio > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     $dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@           IN      NS      $dominio.
servidor    IN      A       $ip
@           IN      A       $ip
www         IN      CNAME   $dominio.
EOF

#Crear zona inversa
echo "Creando zona inversa"
sudo tee /etc/bind/db.$(echo $ip | awk -F. '{print $3"."$2"."$1}') > /dev/null <<EOF
\$TTL    604800
@       IN      SOA     $dominio. root.$dominio. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $dominio.
$(echo $ip | awk -F. '{print $4}')     IN      PTR     $dominio.
EOF

    #Editar resolv.conf para fijar la IP en el servidor DNS
    sudo sed -i "/^search /c\search $dominio" /etc/resolv.conf    #Utilizo sed -i para modificar especificamente esa linea
    sudo sed -i "/^nameserver /c\nameserver $ip" /etc/resolv.conf
    echo "Fijando la IP $ip para el servidor DNS"

    #Reiniciar bind9
    echo "Reiniciando bind9"
    sudo systemctl restart bind9
    echo "Configuración finalizada :)"
}
