#!/bin/bash

# Importar modulos
source validateDhcp.sh
source configDhcp.sh

# Leer entradas
SUBRED=$(get_subnet)
RANGO_INICIO=$(get_range_start)
RANGO_FINAL=$(get_range_end)
SERVER_IP=$(get_server_ip)

# Validar entradas
validate_ip $SERVER_IP

# Configurar red
configure_network $SERVER_IP

# Instalar servidor DHCP
install_dhcp

# Configurar DHCP
configure_dhcp $SUBRED $RANGO_INICIO $RANGO_FINAL $SERVER_IP

# Reiniciar servicio DHCP
restart_dhcp

echo "Configuración completada exitosamente."