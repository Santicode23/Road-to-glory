# ========================
# INSTALADOR COMPLETO: Apache James + PHP + SquirrelMail + Firewall + Java + Visual C++
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
# 1. DEPENDENCIAS: Visual C++ + Java Corretto 21
# ------------------------

Write-Host "`nVerificando Visual C++ Redistributable..."

$vcInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | 
               Get-ItemProperty | 
               Where-Object { $_.DisplayName -match "Visual C\+\+ (2015|2017|2019|2022) Redistributable" }

if ($vcInstalled) {
    Write-Host "Visual C++ Redistributable ya esta instalado."
} else {
    Write-Host "Descargando Visual C++..."
    $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
    Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
    Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
    Write-Host "Visual C++ instalado correctamente."
}

Write-Host "`nVerificando Amazon Corretto JDK 21..."
$jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

if (-not (Test-Path "$jdkInstallPath\bin\java.exe")) {
    Write-Host "Descargando Amazon Corretto JDK 21..."
    $jdkUrl = "https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.zip"
    $jdkZipPath = "$env:TEMP\Corretto21.zip"
    Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZipPath
    if (-Not (Test-Path $jdkBasePath)) { New-Item -ItemType Directory -Path $jdkBasePath | Out-Null }
    Expand-Archive -Path $jdkZipPath -DestinationPath $jdkBasePath -Force
    Remove-Item -Path $jdkZipPath -Force
    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1
    if (-not $jdkInstallPath) {
        Write-Host "Error: No se encontro la carpeta del JDK despues de la instalacion."
        exit
    }
    Write-Host "JDK instalado en: $jdkInstallPath"
} else {
    Write-Host "JDK ya instalado en: $jdkInstallPath"
}

Write-Host "`nConfigurando JAVA_HOME y PATH..."
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ($currentPath -notlike "$jdkInstallPath\bin") {
    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$jdkInstallPath\bin", [System.EnvironmentVariableTarget]::Machine)
}
$env:JAVA_HOME = $jdkInstallPath
$env:Path += ";$jdkInstallPath\bin"

Write-Host "`nVerificando Java..."
$javaVersion = & "$jdkInstallPath\bin\java.exe" -version 2>&1
if ($javaVersion -match "21\.") {
    Write-Host "Java configurado correctamente: $javaVersion"
} else {
    Write-Host "Error: JAVA_HOME no esta configurado correctamente."
    exit
}

# ------------------------
# 2. INSTALACION DE APACHE JAMES
# ------------------------

Write-Host "`nDescargando Apache James Server $JAMES_VERSION..."
$JAMES_URL = "https://dlcdn.apache.org/james/server/james-server-app-${JAMES_VERSION}/apache-james-${JAMES_VERSION}-app.zip"
$JAMES_ZIP = "$env:TEMP\james.zip"
Invoke-WebRequest -Uri $JAMES_URL -OutFile $JAMES_ZIP

if (-not (Test-Path $JAMES_ZIP)) {
    Write-Host "Error: No se descargo Apache James."
    exit
}

Expand-Archive -Path $JAMES_ZIP -DestinationPath $INSTALL_DIR -Force
Remove-Item -Path $JAMES_ZIP -Force

$JAMES_DIR = "$INSTALL_DIR\apache-james-${JAMES_VERSION}-app"
$CLI = "$JAMES_DIR\bin\james-cli.bat"
$JAMES_BAT = "$JAMES_DIR\bin\james.bat"

if (-not (Test-Path $JAMES_BAT)) {
    Write-Host "Error: No se encontro james.bat. Revisa si la descompresion fue correcta."
    exit
}

Write-Host "Iniciando Apache James..."
Start-Process -NoNewWindow -FilePath $JAMES_BAT
Start-Sleep -Seconds 30

if (-not (Test-Path $CLI)) {
    Write-Host "Error: No se encontro james-cli.bat. Abortando configuracion."
    exit
}

Write-Host "Configurando dominio y usuarios..."
& $CLI AddDomain $DOMAIN
& $CLI AddUser "prueba1@$DOMAIN" "12345"
& $CLI AddUser "prueba2@$DOMAIN" "12345"

sc.exe create ApacheJames binPath= "cmd /c start /min $JAMES_BAT" start= auto
sc.exe description ApacheJames "Apache James Mail Server"
Start-Service ApacheJames

# ------------------------
# 3. FIREWALL
# ------------------------

Write-Host "`nConfigurando reglas de firewall..."
New-NetFirewallRule -DisplayName "SMTP (25)" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
New-NetFirewallRule -DisplayName "POP3 (110)" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
New-NetFirewallRule -DisplayName "IMAP (143)" -Direction Inbound -Protocol TCP -LocalPort 143 -Action Allow
New-NetFirewallRule -DisplayName "HTTP (80)" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# ------------------------
# 4. PHP + SQUIRRELMAIL
# ------------------------

Write-Host "`nInstalando PHP y SquirrelMail..."

$phpZipUrl = "https://windows.php.net/downloads/releases/archives/php-7.4.33-Win32-vc15-x64.zip"
$phpZipPath = "$env:TEMP\php.zip"
$phpTargetPath = "C:\PHP"
$phpIniPath = "$phpTargetPath\php.ini"

$squirrelUrl = "https://gigenet.dl.sourceforge.net/project/squirrelmail/stable/1.4.22/squirrelmail-webmail-1.4.22.zip?viasf=1"
$squirrelZipPath = "$env:TEMP\squirrelmail.zip"
$squirrelTempExtract = "$env:TEMP\squirrelmail"
$squirrelTargetPath = "C:\inetpub\wwwroot\squirrelmail"
$squirrelDefaultConfig = "$squirrelTargetPath\config\config_default.php"
$squirrelConfig = "$squirrelTargetPath\config\config.php"

# PHP
if (-Not (Test-Path $phpTargetPath)) {
    Write-Host "Descargando PHP..."
    Invoke-WebRequest -Uri $phpZipUrl -OutFile $phpZipPath
    Expand-Archive -Path $phpZipPath -DestinationPath $phpTargetPath -Force
    Remove-Item $phpZipPath -Force
}

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

# SquirrelMail
if (-Not (Test-Path $squirrelTargetPath)) {
    Invoke-WebRequest -Uri $squirrelUrl -OutFile $squirrelZipPath
    Expand-Archive -Path $squirrelZipPath -DestinationPath $squirrelTempExtract -Force
    Move-Item "$squirrelTempExtract\squirrelmail-webmail-1.4.22" $squirrelTargetPath
    Remove-Item $squirrelZipPath -Force
}

if (-Not (Test-Path $squirrelConfig)) {
    Copy-Item $squirrelDefaultConfig $squirrelConfig
}

$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-568")
$account = $sid.Translate([System.Security.Principal.NTAccount])
icacls $squirrelTargetPath /grant ($account + ":(OI)(CI)(RX)") /T | Out-Null

# IIS FastCGI
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

Write-Host "`nINSTALACION COMPLETA"
Write-Host "Apache James corriendo con dominio: $DOMAIN"
Write-Host "Usuarios: prueba1@$DOMAIN / prueba2@$DOMAIN"
Write-Host "IP del servidor: $bridgeIP"
Write-Host "SquirrelMail disponible en: http://$bridgeIP/squirrelmail"
