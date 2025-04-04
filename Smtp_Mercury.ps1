# ------------------------
# CONFIGURACIÓN GENERAL
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
    Write-Host "Visual C++ Redistributable ya está instalado."
} else {
    Write-Host "Falta Visual C++. Descargando e instalando..."
    $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
    Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
    Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
    Write-Host "Visual C++ Redistributable instalado correctamente."
}

# Verificar e instalar Amazon Corretto JDK 21
Write-Host "`nVerificando Amazon Corretto JDK 21..."

$jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

if ($jdkInstallPath -and (Test-Path "$jdkInstallPath\bin\java.exe")) {
    Write-Host "Amazon Corretto JDK 21 ya está instalado en: $jdkInstallPath"
} else {
    Write-Host "Falta JDK 21. Descargando e instalando..."
    $jdkUrl = "https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.zip"
    $jdkZipPath = "$env:TEMP\Corretto21.zip"

    Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZipPath

    if (-Not (Test-Path $jdkBasePath)) {
        New-Item -ItemType Directory -Path $jdkBasePath | Out-Null
    }

    Write-Host "Extrayendo Amazon Corretto JDK 21..."
    Expand-Archive -Path $jdkZipPath -DestinationPath $jdkBasePath -Force
    Remove-Item -Path $jdkZipPath -Force

    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

    if (-not $jdkInstallPath) {
        Write-Host "❌ Error: No se encontró la carpeta del JDK después de la instalación."
        exit
    }

    Write-Host "Amazon Corretto JDK 21 instalado en: $jdkInstallPath"
}

# Configurar JAVA_HOME y agregar al PATH
Write-Host "`nConfigurando JAVA_HOME y PATH..."

[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)

$currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
if ($currentPath -notlike "*$jdkInstallPath\bin*") {
    $newPath = "$currentPath;$jdkInstallPath\bin"
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
}

$env:JAVA_HOME = $jdkInstallPath
$env:Path = "$env:Path;$jdkInstallPath\bin"

Write-Host "JAVA_HOME configurado correctamente en: $env:JAVA_HOME"

Write-Host "`nVerificando configuración de Java..."
$javaVersion = & "$jdkInstallPath\bin\java.exe" -version 2>&1
if ($javaVersion -match "21\.") {
    Write-Host "✅ Java configurado correctamente:`n$javaVersion"
} else {
    Write-Host "❌ Error: JAVA_HOME no está configurado correctamente."
    exit
}

# ------------------------
# 2. FIREWALL
# ------------------------

Write-Host "`nConfigurando reglas de firewall para servicios de correo..."
New-NetFirewallRule -DisplayName "SMTP (25)" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
New-NetFirewallRule -DisplayName "POP3 (110)" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
New-NetFirewallRule -DisplayName "IMAP (143)" -Direction Inbound -Protocol TCP -LocalPort 143 -Action Allow
New-NetFirewallRule -DisplayName "HTTP (80)" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# ------------------------
# 3. PHP + SQUIRRELMAIL
# ------------------------

Write-Host "`nInstalando PHP y SquirrelMail..."

# Configuraciones
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
    Write-Host "Descargando PHP 7.4.33..."
    Invoke-WebRequest -Uri $phpZipUrl -OutFile $phpZipPath
    Write-Host "Extrayendo PHP..."
    Expand-Archive -Path $phpZipPath -DestinationPath $phpTargetPath -Force
    Remove-Item $phpZipPath -Force
} else {
    Write-Host "PHP ya está instalado en $phpTargetPath"
}

if (-Not (Test-Path $phpIniPath)) {
    Copy-Item "$phpTargetPath\php.ini-development" $phpIniPath
    Write-Host "php.ini creado desde php.ini-development"
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
    Write-Host "Descargando SquirrelMail..."
    Invoke-WebRequest -Uri $squirrelUrl -OutFile $squirrelZipPath
    Write-Host "Extrayendo SquirrelMail..."
    Expand-Archive -Path $squirrelZipPath -DestinationPath $squirrelTempExtract -Force
    Move-Item -Path "$squirrelTempExtract\squirrelmail-webmail-1.4.22" -Destination $squirrelTargetPath
    Remove-Item $squirrelZipPath -Force
} else {
    Write-Host "SquirrelMail ya está instalado en $squirrelTargetPath"
}

if (-Not (Test-Path $squirrelConfig)) {
    Copy-Item $squirrelDefaultConfig $squirrelConfig
    Write-Host "Archivo config.php creado desde config_default.php"
}

# Permisos IIS
$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-568")
$account = $sid.Translate([System.Security.Principal.NTAccount])
icacls $squirrelTargetPath /grant ($account + ":(OI)(CI)(RX)") /T | Out-Null
Write-Host "Permisos asignados a IIS_IUSRS sobre la carpeta SquirrelMail."

# Registrar PHP en IIS como FastCGI
$phpCgiPath = "C:\PHP\php-cgi.exe"
$fcgiList = & "$env:windir\system32\inetsrv\appcmd.exe" list config -section:system.webServer/fastCgi
if ($fcgiList -notmatch [regex]::Escape($phpCgiPath)) {
    Write-Host "Registrando PHP como FastCGI..."
    & "$env:windir\system32\inetsrv\appcmd.exe" set config /section:system.webServer/fastCgi /+"[fullPath='$phpCgiPath']"
}

Write-Host "Agregando handler mapping para .php..."
& "$env:windir\system32\inetsrv\appcmd.exe" set config -section:handlers `
    /+"[name='PHP_via_FastCGI',path='*.php',verb='GET,POST,HEAD',modules='FastCgiModule',scriptProcessor='$phpCgiPath',resourceType='File']" `
    /commit:apphost

iisreset

Write-Host "`n✅ PHP y SquirrelMail instalados correctamente."
Write-Host "Accede a SquirrelMail en: http://$bridgeIP/squirrelmail"
