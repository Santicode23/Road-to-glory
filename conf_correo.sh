#!/bin/bash
# correo/conf_correo.sh

conf_correo(){
    dominio="elhueso.com"
    ip="20.0.0.10"
    # Actualiza la lista de paquetes 
    sudo apt-get install apache2 -y
    
    sudo apt install software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt update
    sudo apt install php7.4 libapache2-mod-php7.4 php-mysql -y

    # Evitar la pantalla interactiva de configuración
    echo "postfix postfix/main_mailer_type select Internet Site" | sudo debconf-set-selections
    echo "postfix postfix/mailname string $dominio" | sudo debconf-set-selections

    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y postfix

    sudo apt install dovecot-imapd dovecot-pop3d -y
    sudo systemctl restart dovecot
    sudo apt install bsd-mailx -y

    # Modifica la configuración de redes permitidas en Postfix
    sudo sed -i "s/^mynetworks = .*/mynetworks = 127.0.0.0\/8 [::ffff:127.0.0.0]\/104 [::1]\/128 $(echo $ip | awk -F. '{print $1"."$2"."$3}').0\/24/" /etc/postfix/main.cf
    # Configura la entrega de correo en formato Maildir en Postfix
    echo "home_mailbox = Maildir/" | sudo tee -a /etc/postfix/main.cf
    echo "mailbox_command =" | sudo tee -a /etc/postfix/main.cf
    echo "smtpd_tls_auth_only = yes" >> /etc/postfix/main.cf
    # Habilitar la escucha en el puerto 587 (submission) para envío de correos con autenticación
    echo "submission inet n       -       n       -       -       smtpd" >> /etc/postfix/master.cf

    # Recarga y reinicia el servicio Postfix
    sudo systemctl reload postfix
    sudo systemctl restart postfix

    # Habilita la autenticación en texto plano en Dovecot
    sudo sed -i 's/^#disable_plaintext_auth = yes/disable_plaintext_auth = no/' /etc/dovecot/conf.d/10-auth.conf

    # Configura el formato de almacenamiento de correo en Dovecot
    sudo sed -i 's/^#   mail_location = maildir:~\/Maildir/    mail_location = maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
    sudo sed -i 's/^mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/#mail_location = mbox:~\/mail:INBOX=\/var\/mail\/%u/' /etc/dovecot/conf.d/10-mail.conf

    # Reinicia el servicio Dovecot
    sudo systemctl restart dovecot

    # Agrega registros de correo y reinicia BIND9
    echo "$dominio  IN  MX  10  correo.$dominio." | sudo tee -a /etc/bind/db.$dominio
    echo "pop3 IN  CNAME   servidor" | sudo tee -a /etc/bind/db.$dominio
    echo "smtp IN  CNAME   servidor" | sudo tee -a /etc/bind/db.$dominio
    sudo systemctl restart bind9

    #Abrir puertos
    sudo ufw allow 25/tcp
    sudo ufw allow 110/tcp
    sudo ufw allow 143/tcp
    sudo ufw allow 587/tcp
    sudo ufw reload


    sudo apt install unzip -y

    # Establecer rutas para los directorios de datos y archivos adjuntos
    data_directory="/var/www/html/squirrelmail/data/"
    attach_directory="/var/www/html/squirrelmail/attach/"

    # Ruta de instalación de SquirrelMail
    install_dir="/var/www/html/squirrelmail"

    cd /var/www/html/
    wget https://sourceforge.net/projects/squirrelmail/files/stable/1.4.22/squirrelmail-webmail-1.4.22.zip
    unzip squirrelmail-webmail-1.4.22.zip
    sudo mv squirrelmail-webmail-1.4.22 squirrelmail
    sudo chown -R www-data:www-data "$install_dir/"
    sudo chmod 755 -R "$install_dir/"

    # Modificar conf.pl para usar tu dominio y las rutas especificadas
    sudo sed -i "s/^\$domain.*/\$domain = '$dominio';/" $install_dir/config/config_default.php
    sudo sed -i "s|^\$data_dir.*| \$data_dir = '$data_directory';|" $install_dir/config/config_default.php
    sudo sed -i "s|^\$attachment_dir.*| \$attachment_dir = '$attach_directory';|" $install_dir/config/config_default.php
    sudo sed -i "s/^\$allow_server_sort.*/\$allow_server_sort = true;/" $install_dir/config/config_default.php

    echo -e "s\n\nq" | perl $install_dir/config/conf.pl

    # Reiniciar Apache para aplicar cambios
    sudo systemctl reload apache2
    sudo systemctl restart apache2

    echo "Instalación de SquirrelMail completada con configuración personalizada."
}
