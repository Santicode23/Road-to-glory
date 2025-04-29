function validar_ip {
    param (
        [string]$ip
    )

    $regex = "^((25[0-4]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|1?[0-9][0-9]?)\.(25[0-4]|2[0-4][0-9]|1?[0-9][0-9]?))$"
    
    return $ip -match $regex
}

function validar_dominio {
    param (
        [string]$dominio
    )

    $regex = '^(?:[a-zA-Z0-9-]{4,}\.)+(com|net|edu|blog|mx|tech|site)$'

    return $dominio -match $regex
}

Write-Host "Bienvenido a la configuración de tu servidor DNS"

# Pedir dominio hasta que sea válido
do{
    $dominio = Read-Host "Introduce el nombre de dominio que deseas configurar"
    if (-not(validar_dominio $dominio)) {
        Write-Output "Dominio no válido."
    } else {
        Write-Output "Dominio valido. $dominio"
    }
} until (validar_dominio $dominio)

# Pedir IP hasta que sea válida
do {
    $ip = Read-Host "Introduce la dirección IP de tu servidor DNS"
    if (-not(validar_ip $ip)) {
        Write-Output "IP no válida."
        break
    } else {
        Write-Output "IP valida: $ip"
    }
} until (validar_ip $ip)

$partes = $ip -split "\."
$partes[3] = "0"
$IPScope = ($partes[0..2] -join ".") + ".0/24"
$NetworkID = ($partes[2..0] -join ".") + ".in-addr.arpa.dns"
Write-Host "Dirección IP separada por partes" -ForegroundColor Green
#Fijar IP
Write-Host "Fijando IP..." -ForegroundColor Green
New-NetIPAddress -IPAddress $ip -InterfaceAlias "Ethernet 2" -PrefixLength 24

#Instalar servidor DNS
Write-Host "Instalando servidor DNS..." -ForegroundColor Green
Install-WindowsFeature -Name DNS -IncludeManagementTools

#Configurar zona principal
Write-Host "Configurando zona principal..." -ForegroundColor Green
Add-DnsServerPrimaryZone -Name $dominio -ZoneFile "$dominio.dns" -DynamicUpdate None -PassThru 

#Configurar zona inversa
Write-Host "Configurando zona inversa..." -ForegroundColor Green
Add-DnsServerPrimaryZone -NetworkID $IPScope -ZoneFile $NetworkID -DynamicUpdate None -PassThru

#Crear registro A para dominio principal
Write-Host "Creando registro A para dominio principal: $dominio" -ForegroundColor Green
Add-DnsServerResourceRecordA -Name "@" -ZoneName $dominio -IPv4Address $ip -CreatePtr -PassThru

#Crear registro para www
Write-Host "Creando registro A para www.$dominio" -ForegroundColor Green
Add-DnsServerResourceRecordA -Name "www" -ZoneName $dominio -IPv4Address $ip -CreatePtr -PassThru

#Configurar máquina como servidor DNS
Write-Host "Configurando máquina como servidor DNS..." -ForegroundColor Green
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $ip
Set-DnsClientServerAddress -InterfaceAlias "Ethernet 2" -ServerAddresses $ip

#Reiniciar servicio DNS
Write-Host "Reiniciando servicio DNS..." -ForegroundColor Green
Restart-Service -Name DNS

#Habilitar pruebas ping 
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -Direction Inbound -Action Allow

Write-Host "Configuración finalizada. Puedes probar tu servidor DNS :)" -ForegroundColor Green
