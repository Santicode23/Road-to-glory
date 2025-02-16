# Solicitar datos al usuario
$Subred = Read-Host "Introduce la subred"
$RangoInicio = Read-Host "Introduce el rango de inicio de IP"
$RangoFinal = Read-Host "Introduce el rango final de IP"
$Mascara = "255.255.255.0"
$Gateway = Read-Host "Introduce la puerta de enlace"
$DNS = Read-Host "Introduce los servidores DNS"

# Instalar el rol DHCP si no está instalado
if (-not (Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue).Installed) {
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Write-Host "Rol DHCP instalado." -ForegroundColor Green
}

# Configurar el ámbito DHCP
$ScopeName = "Scope_Local"
$ScopeID = $Subred

Add-DhcpServerv4Scope -Name $ScopeName -StartRange $RangoInicio -EndRange $RangoFinal -SubnetMask $Mascara -State Active
Set-DhcpServerv4OptionValue -ScopeId $ScopeID -Router $Gateway -DnsServer $DNS

# Reiniciar el servicio DHCP
Restart-Service DHCPServer
Set-Service DHCPServer -StartupType Automatic

# Verificar el estado del servicio
Write-Host "Estado del servicio DHCP:" -ForegroundColor Green
Get-Service DHCPServer
