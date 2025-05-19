#!/bin/bash

instalar_docker() {

    echo "=== INSTALANDO DOCKER ==="
    sudo apt update
    # paquetes para que apt pueda usar paquetes a traves de http
    sudo apt install apt-transport-https ca-certificates curl software-properties-common

    # clave GPG para el repositorio oficial de docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Agregando el repositorio de docker a las fuentes apt
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

    # Actualizando paquetes desde la BD de docker
    sudo apt update

    # Cambiando al repositorio de docker en lugar de predeterminado
    apt-cache policy docker-ce

    # Instalar docker
    sudo apt install docker-ce

    # Comprobando
    sudo systemctl status docker
}

# OPCIONAL
agg_usuario_a_docker(){

    sudo usermod -aG docker lilc
    su - lilc
    id -nG
}

instalar_apache() {
    echo "== BUSCANDO IMAGEN DE APACHE =="
    sudo docker search httpd
    echo "== INSTALANDO APACHE =="
    sudo docker pull httpd
    echo "== CORRIENDO APACHE =="
    sudo docker run -d --name miapache -p 8080:80 httpd
}

modificar_apache() {
    mkdir -p apache_custom
    cd apache_custom || exit

    cat > index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>APACHE</title>
</head>
<body>
    <h1>HALA MADRID</h1>
</body>
</html>
EOF

    cat > Dockerfile <<EOF
FROM httpd:latest
COPY index.html /usr/local/apache2/htdocs/index.html
EOF

    sudo docker build -t apache_modi .
    sudo docker run -d -p 8081:80 --name apache_custom apache_modi
}

conectar_contenedores() {
    sudo docker network create postgres_net

    # Levantar el primer contenedor postgreSQL
    docker run -d \
    --name postgress1 \
    --network postgres_net \
    -e POSTGRES_USER=usuario \
    -e POSTGRES_PASSWORD=clave123 \
    -e POSTGRES_DB=bd1 \
    postgres:latest

    # Segundo contenedor postgreSQL
    docker run -d \
    --name postgress2 \
    --network postgres_net \
    -e POSTGRES_USER=usuario \
    -e POSTGRES_PASSWORD=clave123 \
    -e POSTGRES_DB=bd2 \
    postgres:latest

    # Probando la conexion
    # Entrando a postgres1
    # sudo docker exec -it postgres1 bash
}

instalar_docker
instalar_apache
modificar_apache
conectar_contenedores
