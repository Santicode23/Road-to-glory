validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    if [[ ! $ip =~ $regex ]]; then
        echo "Error: IP inválida"
        exit 1
    fi
}

validate_domain() {
    local domain=$1
    local regex='^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$'
    if [[ ! $domain =~ $regex ]]; then
        echo "Error: Dominio inválido"
        exit 1
    fi
}