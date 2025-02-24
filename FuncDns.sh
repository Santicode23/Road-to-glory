# Función para validar la dirección IP
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                echo "IP inválida: fuera de rango"
                exit 1
            fi
        done
    else
        echo "Formato de IP inválido"
        exit 1
    fi
}

# Función para validar el dominio
validate_domain() {
    local domain=$1
    local regex='^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$'
    if ! [[ $domain =~ $regex ]]; then
        echo "Dominio inválido"
        exit 1
    fi
}