# ========================
# INSTALADOR COMPLETO
# Apache James + PHP + SquirrelMail + Reglas de Firewall + Java + Visual C++
# ========================

# ------------------------
# CONFIGURACION GENERAL
# ------------------------

$DOMAIN = "reprobados.com"
$bridgeIP = "192.168.100.160"
$JAMES_VERSION = "3.6.0"
$INSTALL_DIR = "C:\James"
$jdkBasePath = "C:\Java"

# ------------------------
# 1. VERIFICAR VISUAL C++
# ------------------------

Write-Host "Verificando Visual C++ Redistributable..."
$vcInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty |
    Where-Object { $_.DisplayName -match "Visual C\+\+ (2015|2017|2019|2022) Redistributable" }

if ($vcInstalled) {
    Write-Host "Visual C++ Redistributable ya está instalado."
} else {
    Write-Host "Falta Visual C++. Descargando e instalando..."
    $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
    Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
    Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -Wait
    Write-Host "Visual C++ Redistributable instalado correctamente."
}

# ------------------------
# 2. INSTALAR JAVA (Corretto JDK 21)
# ------------------------

Write-Host "Verificando Amazon Corretto JDK 21..."
$jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

if ($jdkInstallPath -and (Test-Path "$jdkInstallPath\bin\java.exe")) {
    Write-Host "Amazon Corretto JDK 21 ya está instalado en: $jdkInstallPath"
} else {
    Write-Host "Falta JDK 21. Descargando e instalando..."
    $jdkUrl = "https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.zip"
    $jdkZipPath = "$env:TEMP\Corretto21.zip"
    Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZipPath
    if (-Not (Test-Path $jdkBasePath)) { New-Item -ItemType Directory -Path $jdkBasePath | Out-Null }
    Expand-Archive -Path $jdkZipPath -DestinationPath $jdkBasePath -Force
    Remove-Item -Path $jdkZipPath -Force
    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1
    if (-not $jdkInstallPath) {
        Write-Host "Error: No se encontró la carpeta del JDK después de la instalación."
        exit
    }
    Write-Host "Amazon Corretto JDK 21 instalado en: $jdkInstallPath"
}

# Configurar JAVA_HOME y PATH
Write-Host "Configurando JAVA_HOME y PATH..."
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ($currentPath -notlike "*$jdkInstallPath\bin*") {
    $newPath = "$currentPath;$jdkInstallPath\bin"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
}
$env:JAVA_HOME = $jdkInstallPath
$env:Path += ";$jdkInstallPath\bin"

# ------------------------
# 3. INSTALAR APACHE JAMES
# ------------------------

Write-Host "Descargando Apache James Server $JAMES_VERSION..."
$JAMES_URL = "https://downloads.apache.org/james/server/apache-james-${JAMES_VERSION}-app.zip"
$JAMES_ZIP = "$env:TEMP\james.zip"
Invoke-WebRequest -Uri $JAMES_URL -OutFile $JAMES_ZIP
Expand-Archive -Path $JAMES_ZIP -DestinationPath $INSTALL_DIR -Force
$JAMES_DIR = "$INSTALL_DIR\apache-james-${JAMES_VERSION}-app"
$CLI = "$JAMES_DIR\bin\james-cli.bat"
Remove-Item -Path $JAMES_ZIP -Force

# Iniciar James
Write-Host "Iniciando Apache James..."
Start-Process -NoNewWindow -FilePath "$JAMES_DIR\bin\james.bat"
Start-Sleep -Seconds 30

# Crear dominio y usuarios
Write-Host "Configurando dominio y usuarios..."
& $CLI AddDomain $DOMAIN
& $CLI AddUser "prueba1@$DOMAIN" "12345"
& $CLI AddUser "prueba2@$DOMAIN" "12345"

# Registrar James como servicio
sc.exe create ApacheJames binPath= "cmd /c start /min $JAMES_DIR\bin\james.bat" start= auto
sc.exe description ApacheJames "Apache James Mail Server"
Start-Service ApacheJames

# ------------------------
# 4. FIREWALL
# ------------------------

Write-Host "Aplicando reglas de firewall SMTP, POP3, IMAP y HTTP..."
New-NetFirewallRule -DisplayName "SMTP (25)" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
New-NetFirewallRule -DisplayName "POP3 (110)" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
New-NetFirewallRule -DisplayName "IMAP (143)" -Direction Inbound -Protocol TCP -LocalPort 143 -Action Allow
New-NetFirewallRule -DisplayName "HTTP (80)" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# ------------------------
# 5. PHP + SQUIRRELMAIL
# ------------------------

# PHP
$phpZipUrl = "https://windows.php.net/downloads/releases/archives/php-7.4.33-Win32-vc15-x64.zip"
$phpZipPath = "$env:TEMP\php.zip"
$phpTargetPath = "C:\PHP"
$phpIniPath = "$phpTargetPath\php.ini"

# SquirrelMail
$squirrelUrl = "https://gigenet.dl.sourceforge.net/project/squirrelmail/stable/1.4.22/squirrelmail-webmail-1.4.22.zip?viasf=1"
$squirrelZipPath = "$env:TEMP\squirrelmail.zip"
$squirrelTempExtract = "$env:TEMP\squirrelmail"
$squirrelTargetPath = "C:\inetpub\wwwroot\squirrelmail"
$squirrelDefaultConfig = "$squirrelTargetPath\config\config_default.php"
$squirrelConfig = "$squirrelTargetPath\config\config.php"

# Instalar PHP
if (-Not (Test-Path $phpTargetPath)) {
    Write-Host "Descargando PHP 7.4.33..."
    Invoke-WebRequest -Uri $phpZipUrl -OutFile $phpZipPath
    Expand-Archive -Path $phpZipPath -DestinationPath $phpTargetPath -Force
    Remove-Item -Path $phpZipPath -Force
}

# php.ini
if (-Not (Test-Path $phpIniPath)) {
    Copy-Item "$phpTargetPath\php.ini-development" $phpIniPath
}

Write-Host "Configurando php.ini..."
(Get-Content $phpIniPath) |
ForEach-Object {
    $_ -replace '^;extension=mbstring', 'extension=mbstring' `
       -replace '^;extension=imap', 'extension=imap' `
       -replace '^;extension=sockets', 'extension=sockets' `
       -replace '^;extension=openssl', 'extension=openssl' `
       -replace '^;extension=fileinfo', 'extension=fileinfo' `
       -replace ';date.timezone =', 'date.timezone = America/Mexico_City'
} | Set-Content $phpIniPath

# Instalar SquirrelMail
if (-Not (Test-Path $squirrelTargetPath)) {
    Write-Host "Descargando SquirrelMail..."
    Invoke-WebRequest -Uri $squirrelUrl -OutFile $squirrelZipPath
    Expand-Archive -Path $squirrelZipPath -DestinationPath $squirrelTempExtract -Force
    Move-Item -Path "$squirrelTempExtract\squirrelmail-webmail-1.4.22" -Destination $squirrelTargetPath
    Remove-Item -Path $squirrelZipPath -Force
}

# Configuración SquirrelMail
if (-Not (Test-Path $squirrelConfig)) {
    Copy-Item $squirrelDefaultConfig $squirrelConfig
}

# Permisos IIS
$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-568")
$account = $sid.Translate([System.Security.Principal.NTAccount])
icacls $squirrelTargetPath /grant ($account + ":(OI)(CI)(RX)") /T | Out-Null

# Configurar PHP en FastCGI
$phpCgiPath = "C:\PHP\php-cgi.exe"
$fcgiList = & "$env:windir\system32\inetsrv\appcmd.exe" list config -section:system.webServer/fastCgi
if ($fcgiList -notmatch [regex]::Escape($phpCgiPath)) {
    & "$env:windir\system32\inetsrv\appcmd.exe" set config /section:system.webServer/fastCgi /+"[fullPath='$phpCgiPath']"
}

& "$env:windir\system32\inetsrv\appcmd.exe" set config -section:handlers `
    /+"[name='PHP_via_FastCGI',path='*.php',verb='GET,POST,HEAD',modules='FastCgiModule',scriptProcessor='$phpCgiPath',resourceType='File']" `
    /commit:apphost

iisreset

# ------------------------
# FINAL
# ------------------------

Write-Host ""
Write-Host "=========================================="
Write-Host "INSTALACION COMPLETA"
Write-Host "Apache James corriendo con dominio: $DOMAIN"
Write-Host "Usuarios: prueba1@$DOMAIN / prueba2@$DOMAIN"
Write-Host "IP del servidor: $bridgeIP"
Write-Host "SquirrelMail disponible en: http://$bridgeIP/squirrelmail"
Write-Host "=========================================="
