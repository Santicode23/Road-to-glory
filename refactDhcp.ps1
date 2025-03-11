# Importar módulos
."$PSScriptRoot\configDhcp.ps1"
."$PSScriptRoot\validateDhcp.ps1"

# Leer entradas
$Subred = Get-Subnet
$RangoInicio = Get-RangeStart
$RangoFinal = Get-RangeEnd
$Mascara = "255.255.255.0"
$Gateway = Get-Gateway
$DNS = Get-DNS
$IPDestino = Get-ServerIP

# Validar entradas
Validate-IP $IPDestino

# Configurar red
Configure-Network $IPDestino

# Instalar servidor DHCP
Install-DHCP

# Configurar DHCP
Configure-DHCP $Subred $RangoInicio $RangoFinal $Mascara $Gateway $DNS

# Reiniciar servicio DHCP
Restart-DHCP

Write-Host "Configuración completada exitosamente." -ForegroundColor Green