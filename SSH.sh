# Verificar si SSH está instalado
if ! dpkg -l | grep -q "openssh-server"; then
    echo "Instalando OpenSSH Server..."
    sudo apt update
    sudo apt install -y openssh-server

    # Habilitar y arrancar el servicio SSH
    echo "Habilitando y arrancando SSH..."
    sudo systemctl enable ssh
    sudo systemctl start ssh
else
    echo "OpenSSH Server ya está instalado."
fi

# Configurar firewall para permitir SSH
echo "Configurando el firewall para permitir conexiones SSH..."
sudo ufw allow ssh

echo "Instalación y configuración de OpenSSH Server completada."
