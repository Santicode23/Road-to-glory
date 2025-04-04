# ------------------------
# CONFIGURACION INICIAL
# ------------------------

$bridgeIP = "192.168.100.160"
$phpZipUrl = "https://windows.php.net/downloads/releases/archives/php-7.4.33-Win32-vc15-x64.zip"
$phpZipPath = "$env:TEMP\php-7.4.33.zip"
$phpTargetPath = "C:\PHP"
$phpIniPath = "$phpTargetPath\php.ini"

$squirrelUrl = "https://gigenet.dl.sourceforge.net/project/squirrelmail/stable/1.4.22/squirrelmail-webmail-1.4.22.zip?viasf=1"
$squirrelZipPath = "$env:TEMP\squirrelmail.zip"
$squirrelTempExtract = "$env:TEMP\squirrelmail"
$squirrelTargetPath = "C:\inetpub\wwwroot\squirrelmail"

# ------------------------
# 1. CONFIGURAR FIREWALL
# ------------------------

Write-Host "Configurando reglas de firewall"
$ports = @(25, 110, 143, 80)
foreach ($port in $ports) {
    if (-not (Get-NetFirewallRule -DisplayName "Puerto $port" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "Puerto $port" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
    }
}

# ------------------------
# 2. INSTALAR VISUAL C++
# ------------------------

Write-Host "Verificando Visual C++ Redistributable 2015-2022"
$vcInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" |
               Get-ItemProperty |
               Where-Object { $_.DisplayName -match "Visual C\+\+ (2015|2017|2019|2022) Redistributable" -and $_.DisplayName -match "x64" }

if (-not $vcInstalled) {
    Write-Host "Descargando e instalando Visual C++"
    $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
    $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
    Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
    Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -Wait
} else {
    Write-Host "Visual C++ ya esta instalado"
}

# ------------------------
# 3. INSTALAR PHP
# ------------------------

if (-not (Test-Path $phpTargetPath)) {
    Write-Host "Descargando y extrayendo PHP 7.4.33"
    Invoke-WebRequest -Uri $phpZipUrl -OutFile $phpZipPath
    Expand-Archive -Path $phpZipPath -DestinationPath $phpTargetPath -Force
    Remove-Item $phpZipPath -Force
} else {
    Write-Host "PHP ya esta instalado en $phpTargetPath"
}

if (-not (Test-Path $phpIniPath)) {
    Copy-Item "$phpTargetPath\php.ini-development" $phpIniPath
    Write-Host "php.ini creado desde php.ini-development"
}

Write-Host "Configurando extensiones en php.ini"
(Get-Content $phpIniPath) |
ForEach-Object {
    $_ -replace '^;extension=mbstring', 'extension=mbstring' `
       -replace '^;extension=imap', 'extension=imap' `
       -replace '^;extension=sockets', 'extension=sockets' `
       -replace '^;extension=openssl', 'extension=openssl' `
       -replace '^;extension=fileinfo', 'extension=fileinfo' `
       -replace ';date.timezone =', 'date.timezone = America/Mexico_City'
} | Set-Content $phpIniPath

# ------------------------
# 4. INSTALAR SQUIRRELMAIL
# ------------------------

if (-Not (Test-Path $squirrelTargetPath)) {
    Write-Host "Descargando SquirrelMail"
    Invoke-WebRequest -Uri $squirrelUrl -OutFile $squirrelZipPath
    Expand-Archive -Path $squirrelZipPath -DestinationPath $squirrelTempExtract -Force
    Remove-Item $squirrelZipPath -Force
    $extracted = Get-ChildItem -Directory $squirrelTempExtract | Where-Object { $_.Name -like "squirrelmail*" } | Select-Object -First 1
    if ($null -eq $extracted) {
        Write-Error "No se encontro carpeta extraida de SquirrelMail"
        exit
    }
    Move-Item -Path $extracted.FullName -Destination $squirrelTargetPath
    Remove-Item $squirrelTempExtract -Recurse -Force
} else {
    Write-Host "SquirrelMail ya esta instalado en $squirrelTargetPath"
}

$squirrelDefaultConfig = "$squirrelTargetPath\config\config_default.php"
$squirrelConfig = "$squirrelTargetPath\config\config.php"
if (-not (Test-Path $squirrelConfig) -and (Test-Path $squirrelDefaultConfig)) {
    Copy-Item $squirrelDefaultConfig $squirrelConfig
    Write-Host "Archivo config.php creado desde config_default.php"
}

$sid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-568")
$account = $sid.Translate([System.Security.Principal.NTAccount])
icacls $squirrelTargetPath /grant ($account + ":(OI)(CI)(RX)") /T | Out-Null
Write-Host "Permisos asignados a IIS_IUSRS sobre $squirrelTargetPath"

# ------------------------
# 5. CONFIGURAR IIS CON PHP
# ------------------------

$phpCgiPath = "$phpTargetPath\php-cgi.exe"
$fcgiList = & "$env:windir\system32\inetsrv\appcmd.exe" list config -section:system.webServer/fastCgi

if ($fcgiList -notmatch [regex]::Escape($phpCgiPath)) {
    Write-Host "Registrando PHP como FastCGI"
    & "$env:windir\system32\inetsrv\appcmd.exe" set config /section:system.webServer/fastCgi /+"[fullPath='$phpCgiPath']"
} else {
    Write-Host "PHP ya esta registrado como FastCGI"
}

Write-Host "Agregando handler mapping para archivos .php"
& "$env:windir\system32\inetsrv\appcmd.exe" set config -section:handlers `
    /+"[name='PHP_via_FastCGI',path='*.php',verb='GET,POST,HEAD',modules='FastCgiModule',scriptProcessor='$phpCgiPath',resourceType='File']" `
    /commit:apphost

iisreset

# ------------------------
# 6. VERIFICACION MANUAL
# ------------------------

$testPhp = "$squirrelTargetPath\info.php"
"<?php phpinfo(); ?>" | Out-File -Encoding ASCII $testPhp

Write-Host "Instalacion completada"
Write-Host "Abre en tu navegador: http://$bridgeIP/squirrelmail"
Write-Host "Prueba PHP con: http://$bridgeIP/squirrelmail/info.php"
