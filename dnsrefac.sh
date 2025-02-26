#!/bin/bash

# Importar módulos
source validateDns.sh
source configDns.sh

# Leer entradas
DOMAIN=$(get_domain)
SERVER_IP=$(get_server_ip)

# Validar entradas
validate_domain $DOMAIN
validate_ip $SERVER_IP

# Configurar red
configure_network $SERVER_IP

# Instalar BIND9
install_bind

# Configurar DNS
configure_bind $DOMAIN $SERVER_IP

# Reiniciar servicio DNS
restart_bind

echo "Configuración completada exitosamente."
