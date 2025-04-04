param (
    [string]$Dominio = "reprobados.com",
    [string]$IP = "192.168.1.100",  # Cambia esto por la IP del adaptador puente
    [string]$RutaInstalacion = "C:\Mercury",
    
    [array]$Usuarios = @(
        @{ Nombre = "pepito"; Clave = "clave123" },
        @{ Nombre = "chabelo"; Clave = "clave456" }
    )
)

function Descargar-Mercury {
    Write-Host "[+] Descargando Mercury Mail..."
    $url = "https://www.pmail.com/downloads_m32/Mercury32_Install.zip"
    $destino = "$env:TEMP\Mercury.zip"
    Invoke-WebRequest -Uri $url -OutFile $destino
    Expand-Archive -Path $destino -DestinationPath $RutaInstalacion -Force
}

function Configurar-Mercury {
    Write-Host "[+] Configurando Mercury..."
    $iniPath = Join-Path $RutaInstalacion "Mercury.ini"

    $config = @"
[General]
Hostname=$Dominio
IP_Interface=$IP

[SMTP]
Port=25

[POP3]
Port=110
"@

    $config | Set-Content -Path $iniPath -Encoding ASCII
}

function Instalar-Servicio {
    Write-Host "[+] Instalando Mercury como servicio..."
    $exe = Join-Path $RutaInstalacion "mercury.exe"
    Start-Process -FilePath $exe -ArgumentList "/install" -Wait
}

function Agregar-Usuarios {
    Write-Host "[+] Agregando usuarios..."
    foreach ($usuario in $Usuarios) {
        $nombre = $usuario.Nombre
        $clave = $usuario.Clave
        Write-Host "  - $nombre@$Dominio"
        $pmfile = Join-Path $RutaInstalacion "MAIL\$nombre\PMail\"
        New-Item -ItemType Directory -Path $pmfile -Force | Out-Null
        Add-Content -Path (Join-Path $RutaInstalacion "MAIL\passwd.dat") -Value "$nombre|$clave"
    }
}

function Configurar-Firewall {
    Write-Host "[+] Configurando reglas de firewall..."
    New-NetFirewallRule -DisplayName "SMTP Mercury" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
    New-NetFirewallRule -DisplayName "POP3 Mercury" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
}

# --- Flujo principal ---
if (!(Test-Path $RutaInstalacion)) {
    Descargar-Mercury
}
Configurar-Mercury
Agregar-Usuarios
Instalar-Servicio
Configurar-Firewall

Write-Host "`n Instalación completada. Puedes probar los usuarios con Thunderbird o SquirrelMail apuntando a $IP"