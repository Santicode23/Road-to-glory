# Verifica si el script se ejecuta como administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Por favor, ejecuta este script como administrador." -ForegroundColor Red
    exit
}

# VARIABLES
$JAMES_VERSION = "3.6.0"
$JAMES_URL = "https://downloads.apache.org/james/server/apache-james-${JAMES_VERSION}-app.zip"
$INSTALL_DIR = "C:\James"
$JAVA_URL = "https://download.oracle.com/java/17/latest/jdk-17_windows-x64_bin.exe"
$JAVA_INSTALL_PATH = "C:\Program Files\Java"
$DOMAIN = "reprobados.com"

# 1. INSTALAR JAVA
Write-Host "Descargando e instalando Java 17..." -ForegroundColor Cyan
Invoke-WebRequest $JAVA_URL -OutFile "$env:TEMP\java-installer.exe"
Start-Process "$env:TEMP\java-installer.exe" -ArgumentList "/s INSTALLDIR=`"$JAVA_INSTALL_PATH`"" -Wait

# Agregar Java al PATH
$env:JAVA_HOME = "$JAVA_INSTALL_PATH\jdk-17"
[Environment]::SetEnvironmentVariable("JAVA_HOME", $env:JAVA_HOME, [EnvironmentVariableTarget]::Machine)
$env:Path += ";$env:JAVA_HOME\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)

# 2. DESCARGAR Y EXTRAER APACHE JAMES
Write-Host "Descargando Apache James $JAMES_VERSION..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $JAMES_URL -OutFile "$env:TEMP\james.zip"
Expand-Archive -Path "$env:TEMP\james.zip" -DestinationPath $INSTALL_DIR -Force

# 3. CONFIGURAR JAMES PARA EL DOMINIO
$configPath = Join-Path $INSTALL_DIR "apache-james-${JAMES_VERSION}-app\conf"
$domainCmd = Join-Path $INSTALL_DIR "apache-james-${JAMES_VERSION}-app\bin\james-cli.bat"

Write-Host "Configurando dominio $DOMAIN..." -ForegroundColor Cyan
Start-Sleep -Seconds 10 # espera a que James arranque antes de ejecutar comandos

& $domainCmd AddDomain $DOMAIN
& $domainCmd AddUser prueba@$DOMAIN 12345

# 4. CONFIGURAR FIREWALL (SMTP 25, POP3 110, IMAP 143)
Write-Host "Configurando reglas de firewall..." -ForegroundColor Cyan
New-NetFirewallRule -DisplayName "Allow SMTP (25)" -Direction Inbound -LocalPort 25 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Allow POP3 (110)" -Direction Inbound -LocalPort 110 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Allow IMAP (143)" -Direction Inbound -LocalPort 143 -Protocol TCP -Action Allow

# 5. CREAR SERVICIO Y ARRANCARLO
$serviceScript = @"
sc create ApacheJames binPath= `"cmd /c start /min $INSTALL_DIR\apache-james-${JAMES_VERSION}-app\bin\james.bat`" start= auto
sc description ApacheJames "Apache James Mail Server"
"@
Invoke-Expression $serviceScript
Start-Service ApacheJames

# 6. VERIFICACIÓN
Write-Host "`n✅ Apache James instalado, configurado y corriendo como servicio." -ForegroundColor Green
Write-Host "✔️ Reglas de firewall aplicadas (SMTP, POP3, IMAP)." -ForegroundColor Green
Write-Host "Puedes conectarte desde otra VM con Thunderbird o SquirrelMail." -ForegroundColor Yellow
Write-Host "Servidor: la IP del adaptador puente (`$(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -like '*Ethernet*' -and $_.PrefixOrigin -eq 'Dhcp' }).IPAddress`)"
Write-Host "Usuario: prueba@$DOMAIN | Contraseña: 12345" -ForegroundColor Cyan
