#!/bin/bash
# Script para unir Linux Mint a un dominio Active Directory

# 1. Instalar los paquetes necesarios
sudo apt update 
sudo apt install -y realmd sssd sssd-tools libnss-sss libpam-sss \
oddjob oddjob-mkhomedir adcli samba-common-bin krb5-user packagekit

# 2. Descubrir el dominio
echo "Descubriendo el dominio..."
realm discover diadelnino.com

# 3. Unir al dominio (reemplaza 'Administrador')
sudo realm join --user=Administrador diadelnino.com

# 4. Checar si el dominio fue unido correctamente
sudo realm list

# 5. Permitir que todos los usuarios del dominio puedan iniciar sesión
sudo realm permit --all

# 6. Configurar LightDM para permitir ingreso manual
echo "Configurando LightDM para inicio de sesión manual..."
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
sudo mkdir -p "$(dirname $LIGHTDM_CONF)"
if ! grep -Fxq "greeter-show-manual-login=true" "$LIGHTDM_CONF"; then
    echo -e "\n[Seat:*]\ngreeter-show-manual-login=true" | sudo tee -a "$LIGHTDM_CONF"
fi

# 7. Habilitar mkhomedir en PAM
echo "Configurando pam_mkhomedir..."
PAM_LINE="session required pam_mkhomedir.so skel=/etc/skel umask=0077"
if ! grep -Fxq "$PAM_LINE" /etc/pam.d/common-session; then
    echo "$PAM_LINE" | sudo tee -a /etc/pam.d/common-session
fi

# 8. Reiniciar servicios para aplicar cambios
sudo systemctl restart sssd
sudo systemctl restart lightdm

echo "El equipo está unido al dominio"
