# input.ps1
function Get-Domain {
    param()
    return Read-Host "Ingrese el nombre del dominio"
}

function Get-ServerIP {
    param()
    return Read-Host "Ingrese la dirección IP de la máquina virtual"
}

# configure_network.ps1
function Configure-Network {
    param([string]$IPDestino)
    New-NetIPAddress -IPAddress $IPDestino -InterfaceAlias "Ethernet 2" -PrefixLength 24
    Write-Host "Configurando máquina como servidor DNS..."
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $IPDestino
    New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -Direction Inbound -Action Allow
}

# install_dns.ps1
function Install-DNSServer {
    if (-not (Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue).Installed) {
        Install-WindowsFeature -Name DNS -IncludeManagementTools
        Write-Host "Función DNS instalada correctamente." -ForegroundColor Green
    }
}

# configure_dns.ps1
function Configure-DNS {
    param([string]$Dominio, [string]$IPDestino)
    $NombreZona = "$Dominio.dns"
    $partes = $IPDestino -split "\."
    $partes[3] = "0"
    $IPScope = ($partes[0..2] -join ".") + ".0/24"
    $NetworkID = ($partes[2..0] -join ".") + ".in-addr.arpa.dns"
    
    Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile $NombreZona -DynamicUpdate None -PassThru
    Write-Host "Zona primaria creada: $Dominio" -ForegroundColor Green
    Add-DnsServerPrimaryZone -NetworkID $IPScope -ZoneFile $NetworkID -DynamicUpdate None -PassThru
    Add-DnsServerResourceRecordA -Name "@" -ZoneName $Dominio -IPv4Address $IPDestino -CreatePtr -PassThru
    Write-Host "Registro A agregado para $Dominio con IP $IPDestino" -ForegroundColor Green
    Add-DnsServerResourceRecordA -Name "www" -ZoneName $Dominio -IPv4Address $IPDestino -CreatePtr -PassThru
    Write-Host "Registro A agregado para www.$Dominio con IP $IPDestino" -ForegroundColor Green
}

# restart_dns.ps1
function Restart-DNS {
    Restart-Service DNS
    Write-Host "Servicio DNS reiniciado correctamente." -ForegroundColor Green
}