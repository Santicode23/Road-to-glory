# Importar módulos
. .\

# Leer entradas
$Dominio = Get-Domain
$IPDestino = Get-ServerIP

# Validar entradas
Validate-Domain $Dominio
Validate-IP $IPDestino

# Configurar red
Configure-Network $IPDestino

# Instalar función de DNS Server
Install-DNSServer

# Configurar DNS
Configure-DNS $Dominio $IPDestino

# Reiniciar servicio DNS
Restart-DNS

Write-Host "Configuración completada exitosamente." -ForegroundColor Green