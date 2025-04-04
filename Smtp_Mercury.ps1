# Verificar que el script se ejecuta como administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Por favor, ejecuta este script como administrador."
    exit
}

# Verificacion de conectividad antes de continuar
Write-Host "Verificando conexion a internet y acceso a fuentes de descarga..."
$testUrls = @(
    "https://github.com",
    "https://downloads.apache.org"
)
foreach ($url in $testUrls) {
    try {
        Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 10 | Out-Null
        Write-Host "Conexion exitosa a $url"
    } catch {
        Write-Host "ERROR: No se pudo establecer conexion con $url"
        Write-Host "Verifica tu conexion a internet antes de continuar."
        exit 1
    }
}

# Configuracion
$JAMES_VERSION = "3.6.0"
$JAMES_URL = "https://downloads.apache.org/james/server/apache-james-${JAMES_VERSION}-app.zip"
$INSTALL_DIR = "C:\James"
$JAVA_MSI_URL = "https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_windows_hotspot.msi"
$JAVA_INSTALL_DIR = "C:\Program Files\Eclipse Adoptium\jdk-17"
$DOMAIN = "reprobados.com"
$CLI_TIMEOUT = 30
$bridgeIP = "192.168.100.160"

# Descargar e instalar Java (MSI silencioso)
Write-Host "Descargando e instalando OpenJDK 17 Temurin..."
Invoke-WebRequest -Uri $JAVA_MSI_URL -OutFile "$env:TEMP\openjdk.msi"
Start-Process "msiexec.exe" -ArgumentList "/i `"$env:TEMP\openjdk.msi`" /qn INSTALLDIR=`"$JAVA_INSTALL_DIR`"" -Wait

# Configurar JAVA_HOME y PATH
$env:JAVA_HOME = "$JAVA_INSTALL_DIR"
[Environment]::SetEnvironmentVariable("JAVA_HOME", $env:JAVA_HOME, [EnvironmentVariableTarget]::Machine)
$env:Path += ";$env:JAVA_HOME\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)

# Descargar y extraer James
Write-Host "Descargando Apache James Server $JAMES_VERSION..."
Invoke-WebRequest -Uri $JAMES_URL -OutFile "$env:TEMP\james.zip"
Expand-Archive -Path "$env:TEMP\james.zip" -DestinationPath $INSTALL_DIR -Force
$JAMES_DIR = "$INSTALL_DIR\apache-james-${JAMES_VERSION}-app"
$CLI = "$JAMES_DIR\bin\james-cli.bat"

# Iniciar James en segundo plano
Write-Host "Iniciando Apache James y esperando $CLI_TIMEOUT segundos..."
Start-Process -NoNewWindow -FilePath "$JAMES_DIR\bin\james.bat"
Start-Sleep -Seconds $CLI_TIMEOUT

# Configurar dominio y usuario
Write-Host "Agregando dominio $DOMAIN y usuario de prueba..."
& $CLI AddDomain $DOMAIN
& $CLI AddUser "prueba@$DOMAIN" "12345"

# Aplicar reglas de firewall (nuevas reglas solicitadas)
Write-Host "Aplicando reglas de firewall SMTP, POP3, IMAP y HTTP..."
New-NetFirewallRule -DisplayName "SMTP (25)" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
New-NetFirewallRule -DisplayName "POP3 (110)" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
New-NetFirewallRule -DisplayName "IMAP (143)" -Direction Inbound -Protocol TCP -LocalPort 143 -Action Allow
New-NetFirewallRule -DisplayName "HTTP (80)" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# Registrar James como servicio
Write-Host "Registrando Apache James como servicio..."
sc.exe create ApacheJames binPath= "cmd /c start /min $JAMES_DIR\bin\james.bat" start= auto
sc.exe description ApacheJames "Apache James Mail Server"
Start-Service ApacheJames

# Resumen final
Write-Host "Instalacion completa"
Write-Host "Dominio configurado: $DOMAIN"
Write-Host "Usuario creado: prueba@$DOMAIN con contrasena 12345"
Write-Host "Direccion IP del servidor (adaptador puente): $bridgeIP"
Write-Host "Puertos abiertos: SMTP 25, POP3 110, IMAP 143, HTTP 80"
Write-Host "Puedes probar la conexion desde otra maquina con Thunderbird o SquirrelMail."
