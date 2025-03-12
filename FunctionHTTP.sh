#!/bin/bash

# Variables globales (compartidas entre las funciones)
servicio=""
version=""
puerto=""
versions=()

paquete_instalado() {
    dpkg -l | grep -qw "$1"
}

instalar_dependencias() {
    echo "Verificando e instalando dependencias necesarias para Apache, Tomcat y Nginx en Ubuntu..."

    sudo apt-get update -y

    # Dependencias generales
    for paquete in build-essential wget curl tar; do
        if paquete_instalado "$paquete"; then
            echo "$paquete ya está instalado."
        else
            sudo apt-get install -y "$paquete"
        fi
    done

    # Dependencias específicas de Apache
    for paquete in libapr1-dev libaprutil1-dev libpcre3 libpcre3-dev; do
        if paquete_instalado "$paquete"; then
            echo "$paquete ya está instalado."
        else
            sudo apt-get install -y "$paquete"
        fi
    done

    # Dependencias específicas de NGINX
    for paquete in libssl-dev zlib1g-dev; do
        if paquete_instalado "$paquete"; then
            echo "$paquete ya está instalado."
        else
            sudo apt-get install -y "$paquete"
        fi
    done

    # Dependencia de Tomcat (Java)
    if paquete_instalado "default-jdk"; then
        echo "default-jdk ya está instalado."
    else
        sudo apt-get install -y default-jdk
    fi

    # Configurar JAVA_HOME automáticamente si no está en /etc/environment
    if ! grep -q "JAVA_HOME" /etc/environment; then
        java_home_path=$(readlink -f $(which java) | sed "s:/bin/java::")
        echo "JAVA_HOME=\"$java_home_path\"" | sudo tee -a /etc/environment > /dev/null
        source /etc/environment
        echo "JAVA_HOME configurado automáticamente como: $JAVA_HOME"
    else
        echo "JAVA_HOME ya está configurado."
    fi

    echo "Verificación e instalación de dependencias completada."
}

# Función para seleccionar el servicio
seleccionar_servicio() {
    echo "Seleccione el servicio que desea instalar:"
    echo "1.- Apache"
    echo "2.- Tomcat"
    echo "3.- Nginx"
    read -p "Opción: " opcion

    case $opcion in
        1)
            servicio="Apache"
            obtener_versiones_apache
            ;;
        2)
            servicio="Tomcat"
            obtener_versiones_tomcat
            ;;
        3)
            servicio="Nginx"
            obtener_versiones_nginx
            ;;
        *)
            echo "Opción no válida. Intente de nuevo."
            ;;
    esac
}

# Función para seleccionar la versión de un servicio ya seleccionado
seleccionar_version() {
    if [[ -z "$servicio" ]]; then
        echo "Debe seleccionar un servicio antes de elegir la versión."
        return
    fi

    echo "Seleccione la versión de $servicio:"
    echo "1.- Versión Estable (LTS): ${versions[0]}"
    echo "2.- Versión de Desarrollo: ${versions[1]}"
    read -p "Opción: " opcion

    case $opcion in
        1)
            version=${versions[0]}
            echo "Versión seleccionada: $version"
            ;;
        2)
            version=${versions[1]}
            echo "Versión seleccionada: $version"
            ;;
        *)
            echo "Opción no válida."
            ;;
    esac
}

# Función para verificar si un puerto está en la lista de restringidos
es_puerto_restringido() {
    local puerto=$1
    local puertos_restringidos=(1 7 9 11 13 15 17 19 20 21 22 23 25 37 42 43 53 69 77 79 87 95 101 102 103 104 109 110 111 113 115 117 118 119 123 135 137 139 143 161 177 179 389 427 443 445 465 512 513 514 515 526 530 531 532 540 548 554 556 563 587 601 636 989 990 993 995 1723 2049 6667)

    for p in "${puertos_restringidos[@]}"; do
        if [[ "$puerto" -eq "$p" ]]; then
            return 0  # El puerto está restringido
        fi
    done
    return 1  # El puerto no está en la lista de restringidos
}

# Función para verificar si un puerto está en uso
verificar_puerto_en_uso() {
    local puerto=$1
    if ss -tuln 2>/dev/null | grep -q "LISTEN.*:$puerto "; then
        return 0  # Puerto en uso
    else
        return 1  # Puerto libre
    fi
}

# Función para pedir un puerto y asegurarse de que esté libre y no restringido
preguntar_puerto() {
    while true; do
        read -p "Ingrese el puerto para el servicio (debe estar entre 1 y 65535): " puerto

        # Verificar si la entrada es un número y está dentro del rango válido
        if [[ "$puerto" =~ ^[0-9]+$ ]] && (( puerto >= 1 && puerto <= 65535 )); then
            # Verificar si el puerto está restringido
            if es_puerto_restringido "$puerto"; then
                echo "El puerto $puerto está en la lista de puertos restringidos. Intente con otro."
                continue
            fi

            # Verificar si el puerto está en uso
            if verificar_puerto_en_uso "$puerto"; then
                echo "El puerto $puerto está ocupado. Intente con otro."
            else
                echo "El puerto $puerto está disponible."
                break
            fi
        else
            echo "Entrada inválida. Ingrese un número de puerto entre 1 y 65535."
        fi
    done
}
# Función para habilitar un puerto en el firewall
habilitar_puerto_firewall() {
    local puerto=$1

    if [ -z "$puerto" ]; then
        echo "Error: No se proporcionó un puerto."
        return 1
    fi

    # Verificar si el firewall está activo
    if command -v ufw &> /dev/null; then
        if sudo ufw status | grep -q "$puerto"; then
            echo "El puerto $puerto ya está permitido en el firewall (UFW)."
        else
            sudo ufw allow "$puerto"/tcp
            echo "El puerto $puerto ha sido habilitado en el firewall (UFW)."
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if sudo firewall-cmd --list-ports | grep -q "$puerto/tcp"; then
            echo "El puerto $puerto ya está permitido en el firewall (firewalld)."
        else
            sudo firewall-cmd --add-port="$puerto"/tcp --permanent
            sudo firewall-cmd --reload
            echo "El puerto $puerto ha sido habilitado en el firewall (firewalld)."
        fi
    else
        echo "No se encontró un gestor de firewall compatible (UFW o firewalld)."
        return 1
    fi
}


comando_existente() {
    command -v "$1" > /dev/null 2>&1
}

proceso_instalacion() {
    if [[ -z "$servicio" || -z "$version" || -z "$puerto" ]]; then
        echo "Debe seleccionar el servicio, la versión y el puerto antes de proceder con la instalación."
        return
    fi

    # Validar dependencias
    if ! comando_existente "gcc" || ! comando_existente "make" || ! comando_existente "wget" || ! comando_existente "curl"; then
        echo "Faltan dependencias esenciales para la instalación."
        echo "Por favor, ejecute la opción 0 del menú (Instalar dependencias necesarias) antes de continuar."
        return 1
    fi

    echo "Iniciando instalación silenciosa de $servicio versión $version en el puerto $puerto..."

    case $servicio in
        "Apache")
            instalar_apache
            ;;
        "Tomcat")
            instalar_tomcat
            ;;
        "Nginx")
            instalar_nginx
            ;;
        *)
            echo "Servicio desconocido. No se puede proceder."
            return 1
            ;;
    esac

    echo "Instalación completada para $servicio versión $version en el puerto $puerto."

    # Limpiar variables globales
    unset servicio
    unset version
    unset puerto
}


instalar_apache() {
    echo "Descargando e instalando Apache versión $version..."

    wget -q "https://downloads.apache.org/httpd/httpd-$version.tar.gz" -O "/tmp/httpd-$version.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar Apache $version."
        return 1
    fi

    tar -xzf "/tmp/httpd-$version.tar.gz" -C /tmp
    cd "/tmp/httpd-$version" || exit 1

    echo "Compilando Apache (esto puede tardar)..."
    ./configure --prefix=/usr/local/apache2 --enable-so > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar ./configure para Apache."
        return 1
    fi

    make > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make para Apache."
        return 1
    fi

    sudo make install > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make install para Apache."
        return 1
    fi

    # Configurar puerto sin preguntar
    sudo sed -i "s/Listen 80/Listen $puerto/" /usr/local/apache2/conf/httpd.conf

    # Iniciar Apache
    /usr/local/apache2/bin/apachectl start

    habilitar_puerto_firewall "$puerto"

    # Reemplazar el index.html de Apache con el código personalizado
    cat <<EOF | sudo tee /usr/local/apache2/htdocs/index.html > /dev/null
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PERO QUE DISTINGUIDO PEDRI</title>
    <style>
        body {
            text-align: center;
            background-color: #004c98;
            color: white;
            font-family: Arial, sans-serif;
        }
        h1 {
            margin-top: 20px;
            font-size: 28px;
            font-weight: bold;
        }
        marquee {
            margin-top: 50px;
        }
        img {
            width: 300px; /* Ajusta el tamaño de las imágenes */
            height: auto;
            border-radius: 10px;
            box-shadow: 0px 0px 10px rgba(255, 255, 255, 0.5);
            margin: 0 20px;
        }
    </style>
</head>
<body>
    <h1>PERO QUE DISTINGUIDO PEDRI</h1>
    <marquee behavior="scroll" direction="left" scrollamount="10">
        <img src="https://upload.wikimedia.org/wikipedia/en/4/47/FC_Barcelona_%28crest%29.svg" 
             alt="Escudo del FC Barcelona">
        <img src="https://pbs.twimg.com/media/E5ZP9L2X0Ak8gN2.jpg:large" 
             alt="Imagen del FC Barcelona">
        <img src="https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSbFMCtfPdNYbLQL0fCGC_ntQuypliAFhJmcg&s" 
             alt="Pedri Distinguido">
    </marquee>
</body>
</html>
EOF
}

instalar_tomcat() {
    echo "Descargando e instalando Tomcat versión $version..."

    # Determinar la versión mayor para construir la URL correctamente
    mayor=$(echo "$version" | cut -d'.' -f1)
    url="https://dlcdn.apache.org/tomcat/tomcat-$mayor/v$version/bin/apache-tomcat-$version.tar.gz"

    # Verificar que la URL existe antes de descargar
    echo "Intentando descargar desde: $url"
    wget --spider "$url"
    if [[ $? -ne 0 ]]; then
        echo "Error: No se encontró el archivo en la URL proporcionada."
        return 1
    fi

    # Descargar Tomcat
    wget -q "$url" -O "/tmp/tomcat-$version.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar Tomcat $version."
        return 1
    fi

    # Limpiar instalación previa (si existe)
    if [[ -d "/opt/tomcat" ]]; then
        echo "Eliminando instalación previa de Tomcat..."
        sudo rm -rf /opt/tomcat
    fi

    sudo mkdir -p /opt/tomcat
    sudo tar -xzf "/tmp/tomcat-$version.tar.gz" -C /opt/tomcat --strip-components=1

    # Configurar puerto sin preguntar (usa la variable global $puerto)
    sudo sed -i "s/Connector port=\"8080\"/Connector port=\"$puerto\"/" /opt/tomcat/conf/server.xml

    # Iniciar Tomcat
    /opt/tomcat/bin/startup.sh

    habilitar_puerto_firewall "$puerto"

    echo "Tomcat $version instalado y configurado en el puerto $puerto."
}

instalar_nginx() {
    echo "Descargando e instalando NGINX versión $version..."

    # Descargar el paquete
    wget -q "https://nginx.org/download/nginx-$version.tar.gz" -O "/tmp/nginx-$version.tar.gz"
    if [[ $? -ne 0 ]]; then
        echo "Error al descargar NGINX $version."
        return 1
    fi

    # Limpiar instalación previa (si existe)
    if [[ -d "/usr/local/nginx" ]]; then
        echo "Eliminando instalación previa de NGINX..."
        sudo rm -rf /usr/local/nginx
    fi

    # Descomprimir y compilar
    tar -xzf "/tmp/nginx-$version.tar.gz" -C /tmp
    cd "/tmp/nginx-$version" || exit 1

    echo "Compilando NGINX (esto puede tardar)..."
    ./configure --prefix=/usr/local/nginx > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar ./configure para NGINX."
        return 1
    fi

    make > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make para NGINX."
        return 1
    fi

    sudo make install > /dev/null
    if [[ $? -ne 0 ]]; then
        echo "Error al ejecutar make install para NGINX."
        return 1
    fi

    # Configurar puerto sin preguntar (usa la variable global $puerto)
    sudo sed -i "s/listen       80;/listen       $puerto;/" /usr/local/nginx/conf/nginx.conf

    # Iniciar NGINX
    /usr/local/nginx/sbin/nginx

    habilitar_puerto_firewall "$puerto"

    echo "NGINX $version instalado y configurado en el puerto $puerto."
}

# Función para obtener versiones de Apache HTTP Server
obtener_versiones_apache() {
    echo "Obteniendo versiones de Apache HTTP Server desde https://httpd.apache.org/download.cgi"

    # Descargar HTML de la página
    html=$(curl -s "https://httpd.apache.org/download.cgi")

    # Buscar versiones en formato httpd-X.Y.Z
    versions_raw=$(echo "$html" | grep -oP 'httpd-\d+\.\d+\.\d+' | sed 's/httpd-//')

    # Extraer la versión LTS (2.4.x) y la versión de desarrollo (2.5.x o superior si existe)
    version_lts=$(echo "$versions_raw" | grep '^2\.4' | head -n 1)
    version_dev=$(echo "$versions_raw" | grep '^2\.5' | head -n 1)

    # Si no encuentra desarrollo (no siempre hay), lo dejamos vacío o avisamos
    if [[ -z "$version_dev" ]]; then
        version_dev="No disponible"
    fi

    versions=("$version_lts" "$version_dev")

    echo "Versión estable (LTS): $version_lts"
    echo "Versión de desarrollo: $version_dev"
}

# Variables globales para almacenar las URLs dinámicas
tomcat_url_lts=""
tomcat_url_dev=""

# ========================
# Función para obtener las URLs de descarga de Tomcat
# ========================
obtener_urls_tomcat() {
    echo "Obteniendo URLs dinámicas de descarga desde el índice de Tomcat..."

    html=$(curl -s "https://tomcat.apache.org/index.html")

    # Extraer los enlaces de descarga de las versiones disponibles
    urls=$(echo "$html" | grep -oP 'https://tomcat.apache.org/download-\d+\.cgi')

    # Identificar la versión LTS y la versión de desarrollo
    tomcat_url_lts=""
    tomcat_url_dev=""

    while read -r url; do
        version_number=$(echo "$url" | grep -oP '\d+')

        # Consideramos que la versión estable (LTS) es la más baja numerada (actualmente Tomcat 10)
        if [[ "$version_number" -lt 11 ]]; then
            tomcat_url_lts="$url"
        fi

        # La versión de desarrollo (dev) es la más alta numerada (actualmente Tomcat 11)
        if [[ "$version_number" -eq 11 ]]; then
            tomcat_url_dev="$url"
        fi
    done <<< "$urls"

    echo "URL de la versión estable (LTS): $tomcat_url_lts"
    echo "URL de la versión de desarrollo: $tomcat_url_dev"
}

# ========================
# Función para obtener las últimas versiones de Tomcat (LTS y Dev)
# ========================
obtener_versiones_tomcat() {
    obtener_urls_tomcat  # Actualizamos las URLs dinámicamente antes de buscar versiones

    echo "Obteniendo versiones de Apache Tomcat desde las URLs detectadas..."

    # Obtener la última versión estable desde la página LTS
    html_lts=$(curl -s "$tomcat_url_lts")
    version_lts=$(echo "$html_lts" | grep -oP 'v\d+\.\d+\.\d+' | head -n 1 | sed 's/v//')

    # Obtener la última versión de desarrollo desde la página dev
    html_dev=$(curl -s "$tomcat_url_dev")
    version_dev=$(echo "$html_dev" | grep -oP 'v\d+\.\d+\.\d+' | head -n 1 | sed 's/v//')

    versions=("$version_lts" "$version_dev")

    echo "Versión estable (LTS): $version_lts"
    echo "Versión de desarrollo: $version_dev"
}


obtener_versiones_nginx() {
    echo "Obteniendo versiones de NGINX desde https://nginx.org/en/download.html"

    html=$(curl -s "https://nginx.org/en/download.html")

    # Extraer la versión Mainline
    version_mainline=$(echo "$html" | grep -A5 "Mainline version" | grep -oP 'nginx-\d+\.\d+\.\d+' | head -n1 | sed 's/nginx-//')

    # Extraer solo el major.minor de Mainline (por ejemplo, 1.27)
    mainline_major_minor=$(echo "$version_mainline" | cut -d '.' -f1,2)

    # Extraer la versión Stable, pero asegurando que no sea de la misma rama major.minor que la Mainline
    version_stable=$(echo "$html" | grep -A5 "Stable version" | grep -oP 'nginx-\d+\.\d+\.\d+' | grep -v "${mainline_major_minor}\." | head -n1 | sed 's/nginx-//')

    # Guardar en el array global versions
    versions=("$version_stable" "$version_mainline")

    echo "Versión estable (LTS): $version_stable"
    echo "Versión de desarrollo (Mainline): $version_mainline"
}

verificar_servicios() {
    echo -e "\n=================================="
    echo "   Verificando servicios HTTP    "
    echo "=================================="

    # Verificar Apache
    if [[ -f "/usr/local/apache2/bin/httpd" || -f "/usr/sbin/apache2" || -f "/usr/sbin/httpd" ]]; then
        echo "Apache está instalado"
        apache_version=$(/usr/local/apache2/bin/httpd -v 2>/dev/null | grep "Server version" | awk '{print $3}')
        [[ -z "$apache_version" ]] && apache_version=$(/usr/sbin/apache2 -v 2>/dev/null | grep "Server version" | awk '{print $3}')
        [[ -z "$apache_version" ]] && apache_version=$(/usr/sbin/httpd -v 2>/dev/null | grep "Server version" | awk '{print $3}')
        
        apache_puertos=$(sudo ss -tlnp | grep httpd | awk '{print $4}' | grep -oE '[0-9]+$' | tr '\n' ', ')
        [[ -z "$apache_puertos" ]] && apache_puertos="No encontrado"
        
        echo "   Versión: ${apache_version:-No encontrada}"
        echo "   Puertos: ${apache_puertos%, }"
        echo "----------------------------------"
    fi

    # Verificar Nginx
    if [[ -f "/usr/local/nginx/sbin/nginx" || -f "/usr/sbin/nginx" || -f "/usr/local/sbin/nginx" ]]; then
        echo "Nginx está instalado"
        nginx_version=$(/usr/local/nginx/sbin/nginx -v 2>&1 | awk -F/ '{print $2}')
        [[ -z "$nginx_version" ]] && nginx_version=$(/usr/sbin/nginx -v 2>&1 | awk -F/ '{print $2}')
        [[ -z "$nginx_version" ]] && nginx_version=$(/usr/local/sbin/nginx -v 2>&1 | awk -F/ '{print $2}')
        
        # Buscar Nginx en cualquier puerto
        nginx_puertos=$(sudo ss -tlnp | grep -E 'nginx|/usr/local/nginx/sbin/nginx' | awk '{print $4}' | grep -oE '[0-9]+$' | tr '\n' ', ')
        [[ -z "$nginx_puertos" ]] && nginx_puertos="No encontrado"
        
        echo "   Versión: ${nginx_version:-No encontrada}"
        echo "   Puertos: ${nginx_puertos%, }"
        echo "----------------------------------"
    fi

    # Verificar Tomcat
    if [[ -d "/opt/tomcat" || -d "/usr/local/tomcat" ]]; then
        echo "Tomcat está instalado"
        tomcat_version=$(/opt/tomcat/bin/version.sh 2>/dev/null | grep "Server number" | awk '{print $3}')
        [[ -z "$tomcat_version" ]] && tomcat_version=$(/usr/local/tomcat/bin/version.sh 2>/dev/null | grep "Server number" | awk '{print $3}')

        tomcat_puertos=$(sudo ss -tlnp | grep java | awk '{print $4}' | grep -oE '[0-9]+$' | tr '\n' ', ')
        [[ -z "$tomcat_puertos" ]] && tomcat_puertos="No encontrado"

        echo "   Versión: ${tomcat_version:-No encontrada}"
        echo "   Puertos: ${tomcat_puertos%, }"
        echo "----------------------------------"
    fi

    # Si no se encontró ningún servicio
    if [[ -z "$(ps aux | grep -E 'nginx|httpd|apache2|tomcat|java' | grep -v grep)" ]]; then
        echo "No se detectaron servicios HTTP en ejecución."
    fi
}