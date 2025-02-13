# Definir los parámetros que tendra la dns
$Dominio = Read-Host "Ingrese el nombre del dominio"
$NombreZona = "$Dominio.dns"
$IPDestino = Read-Host "Ingrese la dirección IP de la máquina virtual"

# Validar de la dirección IP impuesta por el servidor
if (-not ($IPDestino -match "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$")) {
    Write-Host "Error: La dirección IP ingresada no es válida." -ForegroundColor Red
    exit
}

$partes = $IPDestino -split "\."
$partes[3] = "0"
$IPScope = ($partes[0..2] -join ".") + ".0/24"
$NetworkID = ($partes[2..0] -join ".") + ".in-addr.arpa.dns"

New-NetIPAddress -IPAddress $IPDestino -InterfaceAlias "Ethernet 2" -PrefixLength 24

# Validación del dominio
if (-not ($Dominio -match "^(?:[a-zA-Z0-9]+\.)+[a-zA-Z]{2,}$")) {
    Write-Host "Error: El dominio ingresado no es válido." -ForegroundColor Red
    exit
}

# Validación del nombre del fichero de zona
if (-not ($NombreZona -match "^[a-zA-Z0-9._-]+\.dns$")) {
    Write-Host "Error: El nombre del fichero de zona no es válido." -ForegroundColor Red
    exit
}

# Instalar la función de DNS Server
if (-not (Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue).Installed) {
    Install-WindowsFeature -Name DNS -IncludeManagementTools
    Write-Host "Función DNS instalada correctamente." -ForegroundColor Green
}

# Crear la zona de búsqueda directa
Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile $NombreZona -DynamicUpdate None -PassThru
Write-Host "Zona primaria creada: $Dominio" -ForegroundColor Green

 #Configurar zona inversa
Write-Host "Configurando zona inversa..."
Add-DnsServerPrimaryZone -NetworkID $IPScope -ZoneFile $NetworkID -DynamicUpdate None -PassThru

# Agregar el registro A para el dominio
Add-DnsServerResourceRecordA -Name "@" -ZoneName $Dominio -IPv4Address $IPDestino -CreatePtr -PassThru
Write-Host "Registro A agregado para $Dominio con IP $IPDestino" -ForegroundColor Green

# Agregar el registro A para www.$Dominio
Add-DnsServerResourceRecordA -Name "www" -ZoneName $Dominio -IPv4Address $IPDestino -CreatePtr -PassThru
Write-Host "Registro A agregado para www.$Dominio con IP $IPDestino" -ForegroundColor Green

#Configurar máquina como servidor DNS
Write-Host "Configurando máquina como servidor DNS..."
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $IPDestino

# Reiniciar el servicio DNS
Restart-Service DNS
Write-Host "Servicio DNS reiniciado correctamente." -ForegroundColor Green

Write-Host "Configuración completada exitosamente." -ForegroundColor Cyan

#Habilitar pruebas ping 
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -Direction Inbound -Action Allow
