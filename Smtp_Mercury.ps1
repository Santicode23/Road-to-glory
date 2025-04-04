# Verificar que el script se ejecuta como administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Por favor, ejecuta este script como administrador."
    exit
}

# VERIFICACIÓN DE CONECTIVIDAD ANTES DE CONTINUAR
Write-Host "Verificando conexión a internet y acceso a fuentes de descarga..."
$testUrls = @(
    "https://github.com",
    "https://downloads.apache.org"
)
foreach ($url in $testUrls) {
    try {
        Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 10 | Out-Null
        Write-Host "Conexión exitosa a $url"
    } catch {
        Write-Host "ERROR: No se pudo establecer conexión con $url" -ForegroundColor Red
        Write-Host "Verifica tu conexión a internet antes de continuar."
        exit 1
    }
}

# CONFIGURACIÓN
$JAMES_VERSION = "3.6.0"
$JAMES_URL = "https://downloads.apache.org/james/server/apache-james-${JAMES_VERSION}-app.zip"
$INSTALL_DIR = "C:\James"
$JAVA_MSI_URL = "https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_windows_hotspot.msi"
$JAVA_INSTALL_DIR = "C:\Program Files\Eclipse Adoptium\jdk-17"
$DOMAIN = "reprobados.com"
$CLI_TIMEOUT = 30

# DESCARGAR E INSTALAR JAVA (MSI silencioso)
Write-Host "Descargando e instalando OpenJDK 17 (Temurin)..."
Invoke-WebRequest -Uri $JAVA_MSI_URL -OutFile "$env:TEMP\openjdk.msi"
Start-Process "msiexec.exe" -ArgumentList "/i `"$env:TEMP\openjdk.msi`" /qn INSTALLDIR=`"$JAVA_INSTALL_DIR`"" -Wait

# Configurar JAVA_HOME y PATH
$env:JAVA_HOME = "$JAVA_INSTALL_DIR"
[Environment]::SetEnvironmentVariable("JAVA_HOME", $env:JAVA_HOME, [EnvironmentVariableTarget]::Machine)
$env:Path += ";$env:JAVA_HOME\bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)

# DESCARGAR Y EXTRAER JAMES
Write-Host "Descargando Apache James Server $JAMES_VERSION..."
Invoke-WebRequest -Uri $JAMES_URL -OutFile "$env:TEMP\james.zip"
Expand-Archive -Path "$env:TEMP\james.zip" -DestinationPath $INSTALL_DIR -Force
$JAMES_DIR = "$INSTALL_DIR\apache-james-${JAMES_VERSION}-app"
$CLI = "$JAMES_DIR\bin\james-cli.bat"

# INICIAR JAMES EN SEGUNDO PLANO
Write-Host "Iniciando Apache James (esperando $CLI_TIMEOUT segundos para estabilizar)..."
Start-Process -NoNewWindow -FilePath "$JAMES_DIR\bin\james.bat"
Start-Sleep -Seconds $CLI_TIMEOUT

# CONFIGURAR DOMINIO Y USUARIO
Write-Host "Agregando dominio $DOMAIN y usuario de prueba..."
& $CLI AddDomain $DOMAIN
& $CLI AddUser "prueba@$DOMAIN" "12345"

# ABRIR PUERTOS EN EL FIREWALL
Write-Host "Abriendo puertos SMTP (25), POP3 (110) e IMAP (143) en el firewall..."
$ports = @(25, 110, 143)
foreach ($port in $ports) {
    New-NetFirewallRule -DisplayName "Apache James Port $port" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow -Profile Any -ErrorAction SilentlyContinue
}

# REGISTRAR JAMES COMO SERVICIO
Write-Host "Registrando Apache James como servicio..."
sc.exe create ApacheJames binPath= "cmd /c start /min $JAMES_DIR\bin\james.bat" start= auto
sc.exe description ApacheJames "Apache James Mail Server"
Start-Service ApacheJames

# OBTENER IP DEL PRIMER ADAPTADOR DE RED ACTIVO (puente)
$bridgeIP = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.InterfaceAlias -notmatch "Loopback" -and
        $_.IPAddress -notlike "169.*" -and
        $_.PrefixOrigin -eq 'Dhcp'
    } | Sort-Object InterfaceIndex | Select-Object -First 1).IPAddress

# RESUMEN FINAL
Write-Host "INSTALACIÓN COMPLETA"
Write-Host "Dominio configurado: $DOMAIN"
Write-Host "Usuario creado: prueba@$DOMAIN con contraseña 12345"
Write-Host "Dirección IP del servidor (adaptador puente): $bridgeIP"
Write-Host "Puertos abiertos: SMTP(25), POP3(110), IMAP(143)"
Write-Host "Puedes probar la conexión desde otra máquina con Thunderbird o SquirrelMail."
