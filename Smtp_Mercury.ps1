# Asegurar ejecución como administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Por favor, ejecuta este script como administrador." -ForegroundColor Red
    exit
}

# CONFIGURACIÓN
$JAMES_VERSION = "3.6.0"
$JAMES_URL = "https://downloads.apache.org/james/server/apache-james-${JAMES_VERSION}-app.zip"
$INSTALL_DIR = "C:\James"
$JAVA_VERSION = "17"
$JAVA_MSI_URL = "https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_windows_hotspot.msi"
$JAVA_INSTALL_DIR = "C:\Program Files\Eclipse Adoptium\jdk-17"
$DOMAIN = "reprobados.com"
$CLI_TIMEOUT = 30

# DESCARGAR E INSTALAR JAVA (MSI silencioso)
Write-Host "Descargando e instalando OpenJDK 17 (Temurin)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $JAVA_MSI_URL -OutFile "$env:TEMP\openjdk.msi"
Start-Process "msiexec.exe" -ArgumentList "/i `"$env:TEMP\openjdk.msi`" /qn INSTALLDIR=`"$JAVA_INSTALL_DIR`"" -Wait

# CONFIGURAR JAVA EN VARIABLES DE ENTORNO
$env:JAVA_HOME = "$JAVA_INSTALL_DIR"
[Environment]::SetEnvironmentVariable("JAVA_HOME", $env:JAVA_HOME, [EnvironmentVariableTarget]::Machine)
$env:Path += ";$env:JAVA_HOME\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)

# DESCARGAR Y EXTRAER JAMES
Write-Host "Descargando Apache James Server $JAMES_VERSION..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $JAMES_URL -OutFile "$env:TEMP\james.zip"
Expand-Archive -Path "$env:TEMP\james.zip" -DestinationPath $INSTALL_DIR -Force

$JAMES_DIR = "$INSTALL_DIR\apache-james-${JAMES_VERSION}-app"
$CLI = "$JAMES_DIR\bin\james-cli.bat"

# INICIAR JAMES EN SEGUNDO PLANO
Write-Host "Iniciando Apache James por primera vez (espera $CLI_TIMEOUT segundos)..." -ForegroundColor Cyan
Start-Process -NoNewWindow -FilePath "$JAMES_DIR\bin\james.bat"
Start-Sleep -Seconds $CLI_TIMEOUT

# CREAR DOMINIO Y USUARIO DE PRUEBA
Write-Host "Configurando dominio $DOMAIN y usuario prueba..." -ForegroundColor Cyan
& $CLI AddDomain $DOMAIN
& $CLI AddUser "prueba@$DOMAIN" "12345"

# CREAR REGLAS DE FIREWALL
Write-Host "Configurando puertos de firewall (SMTP, POP3, IMAP)..." -ForegroundColor Cyan
$ports = @(25, 110, 143)
foreach ($port in $ports) {
    New-NetFirewallRule -DisplayName "Apache James Port $port" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow -Profile Any -ErrorAction SilentlyContinue
}

# REGISTRAR COMO SERVICIO
Write-Host "Registrando Apache James como servicio..." -ForegroundColor Cyan
sc.exe create ApacheJames binPath= "cmd /c start /min $JAMES_DIR\bin\james.bat" start= auto
sc.exe description ApacheJames "Apache James Mail Server"

Start-Service ApacheJames

# DETECTAR IP DEL ADAPTADOR PUENTE
$bridgeIP = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.InterfaceAlias -notmatch "Loopback" -and
        $_.IPAddress -notlike "169.*" -and
        $_.PrefixOrigin -eq 'Dhcp'
    }).IPAddress

# RESUMEN FINAL
Write-Host "INSTALACIÓN COMPLETA" -ForegroundColor Green
Write-Host "Dominio configurado: $DOMAIN"
Write-Host "Usuario creado: prueba@$DOMAIN / 12345"
Write-Host "Dirección IP del servidor (adaptador puente): $bridgeIP"
Write-Host "Puertos habilitados: SMTP(25), POP3(110), IMAP(143)"
Write-Host "Puedes probar con Thunderbird o SquirrelMail desde otra máquina Linux." -ForegroundColor Yellow
