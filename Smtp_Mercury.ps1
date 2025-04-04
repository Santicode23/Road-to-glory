param (
    [string]$Dominio = "reprobados.com",
    [string]$IP = "192.168.100.162",  # IP del adaptador puente
    [string]$RutaInstalacion = "C:\Mercury",

    [array]$Usuarios = @(
        @{ Nombre = "pepito"; Clave = "correo123" },
        @{ Nombre = "chabelo"; Clave = "correo456" }
    )
)

function Verificar-Ejecutable {
    $exePath = Join-Path $RutaInstalacion "mercury.exe"
    if (!(Test-Path $exePath)) {
        Write-Error "❌ No se encontró mercury.exe en $RutaInstalacion"
        Write-Host "➡️  Descárgalo desde https://www.pmail.com y colócalo ahí."
        exit 1
    }
}

function Configurar-Mercury {
    Write-Host "Configurando Mercury..."
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

function Agregar-Usuarios {
    Write-Host "Agregando usuarios..."
    foreach ($usuario in $Usuarios) {
        $nombre = $usuario.Nombre
        $clave = $usuario.Clave
        Write-Host "  - $nombre@$Dominio"
        $pmfile = Join-Path $RutaInstalacion "MAIL\$nombre\PMail\"
        New-Item -ItemType Directory -Path $pmfile -Force | Out-Null
        Add-Content -Path (Join-Path $RutaInstalacion "MAIL\passwd.dat") -Value "$nombre|$clave"
    }
}

function Instalar-Servicio {
    Write-Host "Instalando Mercury como servicio..."
    $exe = Join-Path $RutaInstalacion "mercury.exe"
    Start-Process -FilePath $exe -ArgumentList "/install" -Wait
}

function Configurar-Firewall {
    Write-Host "Configurando reglas de firewall..."
    New-NetFirewallRule -DisplayName "SMTP Mercury" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
    New-NetFirewallRule -DisplayName "POP3 Mercury" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
}

# === Flujo principal ===
Verificar-Ejecutable
Configurar-Mercury
Agregar-Usuarios
Instalar-Servicio
Configurar-Firewall

Write-Host "`Mercury Mail instalado y configurado correctamente."
Write-Host "Puedes probar los correos en Thunderbird o SquirrelMail apuntando a $IP"
