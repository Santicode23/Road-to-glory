# Detener el servicio SSH si está en ejecución
Stop-Service sshd -Force -ErrorAction SilentlyContinue

# Eliminar reglas de firewall asociadas
Get-NetFirewallRule -Name "SSH" -ErrorAction SilentlyContinue | Remove-NetFirewallRule

# Eliminar archivos de configuración previos
$sshConfigPath = "$env:ProgramData\ssh"
if (Test-Path $sshConfigPath) {
    Remove-Item -Path $sshConfigPath -Recurse -Force
    Write-Host "Archivos de configuración eliminados."
}

# Verificar si OpenSSH ya está instalado
$sshFeature = Get-WindowsFeature -Name OpenSSH-Server

if ($sshFeature.Installed -eq $false) {
    # Instalar OpenSSH Server
    Write-Host "Instalando OpenSSH Server..."
    Add-WindowsFeature -Name OpenSSH-Server

    # Iniciar y habilitar el servicio
    Write-Host "Iniciando y configurando OpenSSH..."
    Start-Service sshd
    Set-Service -Name sshd -StartupType Automatic

    # Configurar el firewall para permitir SSH
    Write-Host "Configurando el firewall para permitir conexiones SSH..."
    New-NetFirewallRule -Name "SSH" -DisplayName "SSH" -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow

    Write-Host "Instalación y configuración de OpenSSH Server completada."
} else {
    Write-Host "OpenSSH Server ya está instalado."
}
