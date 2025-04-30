#!/bin/bash

echo ""
echo "CONFIGURACION DEL CLIENTE LINUX (MINT) PARA PODERSE CONECTAR/LOGGEAR A ACTIVE DIRECTORY :)"

IP_ADSERVER="192.168.0.122"
DOMINIO_AD="pedimospizza.com"

sudo apt update

#Paquetes necesarios para integrar Ubuntu con AD
sudo apt install realmd sssd sssd-ad sssd-tools samba-common-bin adcli packagekit

#Configuramos el servidor NTP para que el equipo sincronice su hora con el controlador de dominio 
#(es obligatorio que tengan hora similar para que la autenticación funcione)
if grep -q "^[#]*NTP=" /etc/systemd/timesyncd.conf; then
    sudo sed -i "s/^[#]*NTP=.*/NTP=$IP_ADSERVER/" /etc/systemd/timesyncd.conf
else
    sudo sed -i "/^\[Time\]/a NTP=$IP_ADSERVER" /etc/systemd/timesyncd.conf
fi

#Cambiar el nameserver para que apunte al servidor AD
sudo sed -i "/^nameserver /c\nameserver $IP_ADSERVER" /etc/resolv.conf    
#Cambiar el dominio de búsqueda (search) para que poder resolver nombres sin poner el dominio completo
sudo sed -i "/^search /c\search $DOMINIO_AD" /etc/resolv.conf

#Buscamos información sobre el dominio, como su nombre real, controlador, y si podemos unir el cliente
sudo realm discover $DOMINIO_AD		

#Une el equipo al dominio usando el usuario Administrador
sudo realm join -v -U Administrador $DOMINIO_AD	        #pide la contraseña de ese usuario en AD. Si todo sale bien, el cliente se une al dominio.

#Información sobre el dominio al que nos unimos
sudo realm list		#deberia mostrar detalle del AD y el dominio
#Confirmacion de que sssd esta funcionando
sudo systemctl status sssd

#PARA CALAR SI DETECTA EL USUARIO: id paolar@renteria.com, debe salir algo asi: "root@adminus:/home/paolarus# id paolar@renteria.com
#uid=1182401103(paolar@renteria.com) gid=1182400513(usuarios del dominio@renteria.com) grupos=1182400513(usuarios del dominio@renteria.com)"

#es para que cuando un usuario del dominio inicie sesión por primera vez, se cree automáticamente su carpeta /home/usuario.
sudo pam-auth-update --enable mkhomedir

#Para que permita loggearse con el usuario y contraseña, estas líneas modifican la configuración de LightDM (el gestor de inicio de sesión gráfico)
grep -q "greeter-show-manual-login=true" /etc/lightdm/lightdm.conf || \
sudo sh -c "echo 'greeter-show-manual-login=true' >> /etc/lightdm/lightdm.conf"     #muestra el campo para escribir usuario y contraseña manualmente

grep -q "greeter-hide-users=true" /etc/lightdm/lightdm.conf || \
sudo sh -c "echo 'greeter-hide-users=true' >> /etc/lightdm/lightdm.conf"        #oculta la lista de usuarios locales

#REINICIO DEL CLIENTE
sudo reboot
