# Verificar si el script se ejecuta como administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Este script debe ejecutarse como Administrador." -ForegroundColor Red
    exit 1
}

# Solicitar datos al usuario
$Subred = Read-Host "Introduce la subred (ejemplo: 192.168.1.0)"
$RangoInicio = Read-Host "Introduce el rango de inicio de IP (ejemplo: 192.168.1.100)"
$RangoFinal = Read-Host "Introduce el rango final de IP (ejemplo: 192.168.1.200)"
$Mascara = "255.255.255.0"
$Gateway = Read-Host "Introduce la puerta de enlace (ejemplo: 192.168.1.1)"
$DNS = Read-Host "Introduce los servidores DNS separados por comas (ejemplo: 8.8.8.8,8.8.4.4)"

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
Write-Host "Estado del servicio DHCP:" -ForegroundColor Cyan
Get-Service DHCPServer