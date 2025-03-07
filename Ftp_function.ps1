# Funciones de validación

function Validar-Contra {
    param (
        [securestring]$Contrasena
    )

    # Convertir SecureString a String para validación
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Contrasena)
    $ContrasenaTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Validaciones
    if ($ContrasenaTexto.Length -lt 8) { return $false }
    if ($ContrasenaTexto -notmatch '[A-Z]') { return $false }
    if ($ContrasenaTexto -notmatch '[a-z]') { return $false }
    if ($ContrasenaTexto -notmatch '\d') { return $false }
    if ($ContrasenaTexto -notmatch '[^a-zA-Z0-9]') { return $false }

    return $true
}


function Validar-Grupo {
    param (
        [string]$Grupo
    )

    $gruposValidos = @("recursadores", "reprobados")
    return $gruposValidos -contains $Grupo
}

# Función para crear las carpetas del usuario
function Crear-Carpetas {
    param (
        [string]$Usuario
    )

    $carpetaUsuario = "C:\FTP\$Usuario"
    $carpetaLocal = "C:\FTP\LocalUser\$Usuario"

    mkdir $carpetaUsuario
    mkdir $carpetaLocal
    cmd /c mklink /D "$carpetaLocal\$Usuario" "$carpetaUsuario"
    cmd /c mklink /D "$carpetaLocal\General" "C:\FTP\General"
}

# Función para asignar permisos a un usuario
function Asignar-Permisos {
    param (
        [string]$Ubicacion,
        [string]$Permisos,
        [string]$Usuario
    )

    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{
        accessType="Allow"
        users="$Usuario"
        permissions=$Permisos
    } -PSPath IIS:\ -Location $Ubicacion
}

# Función para crear un usuario en el sistema
function Crear-Usuario {
    param (
        [string]$NombreUsuario,
        [securestring]$ContrasenaUsuario,
        [string]$GrupoAsignado
    )

    # 🔹 Convertir SecureString a texto plano
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ContrasenaUsuario)
    $ContrasenaTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # 🔹 Crear el usuario con la contraseña correcta
    net user "$NombreUsuario" "$ContrasenaTexto" /add

    # 🔹 Asignar al usuario al grupo general y al grupo específico
    net localgroup "general" $NombreUsuario /add
    net localgroup "$GrupoAsignado" $NombreUsuario /add
}


# Función para crear enlaces simbólicos
function Crear-EnlacesSimbolicos {
    param (
        [string]$NombreUsuario,
        [string]$GrupoAsignado
    )

    cmd /c mklink /D "C:\FTP\LocalUser\$NombreUsuario\$NombreUsuario" "C:\FTP\$NombreUsuario"
    cmd /c mklink /D "C:\FTP\LocalUser\$NombreUsuario\$GrupoAsignado" "C:\FTP\$GrupoAsignado"
}

# Función para agregar un usuario con todas las configuraciones necesarias
function Agregar-Usuario {
    param (
        [string]$NombreUsuario,
        [securestring]$ContrasenaUsuario,
        [string]$GrupoAsignado
    )

    Crear-Usuario -NombreUsuario $NombreUsuario -ContrasenaUsuario $ContrasenaUsuario -GrupoAsignado $GrupoAsignado
    Crear-Carpetas -Usuario $NombreUsuario
    Crear-EnlacesSimbolicos -NombreUsuario $NombreUsuario -GrupoAsignado $GrupoAsignado
    Asignar-Permisos -Ubicacion "FTP/$NombreUsuario" -Permisos 3 -Usuario $NombreUsuario
    Asignar-Permisos -Ubicacion "FTP/General" -Permisos 3 -Usuario $NombreUsuario
}

function Mover-Usuario {
    param (
        [string]$NombreUsuario,
        [string]$NuevoGrupo
    )

    # Verifica si el usuario existe
    $existeUsuario = net user $NombreUsuario 2>$null
    if (-not $existeUsuario) {
        Write-Host "El usuario '$NombreUsuario' no existe." -ForegroundColor Red
        return
    }

    # Verifica si el grupo ingresado es válido
    if (-not (Validar-Grupo -Grupo $NuevoGrupo)) {
        Write-Host "El grupo '$NuevoGrupo' no es válido." -ForegroundColor Red
        return
    }

    # Obtiene el grupo actual del usuario
    $grupoActual = ""
    if (net localgroup "recursadores" | Select-String -Pattern $NombreUsuario) { $grupoActual = "recursadores" }
    if (net localgroup "reprobados" | Select-String -Pattern $NombreUsuario) { $grupoActual = "reprobados" }

    if ($grupoActual -eq "") {
        Write-Host "El usuario '$NombreUsuario' no pertenece a 'recursadores' ni 'reprobados'." -ForegroundColor Yellow
        return
    }

    # Si el usuario ya está en el grupo, no hace nada
    if ($grupoActual -eq $NuevoGrupo) {
        Write-Host "El usuario '$NombreUsuario' ya está en el grupo '$NuevoGrupo'." -ForegroundColor Yellow
        return
    }

    Write-Host "Moviendo al usuario '$NombreUsuario' de '$grupoActual' a '$NuevoGrupo'..." -ForegroundColor Cyan

    # Elimina al usuario del grupo anterior
    net localgroup "$grupoActual" "$NombreUsuario" /delete

    # Agrega al usuario al nuevo grupo
    net localgroup "$NuevoGrupo" "$NombreUsuario" /add

    # 🔹 Elimina el enlace simbólico del grupo anterior en su carpeta personal
    $rutaSimbolicaAntigua = "C:\FTP\LocalUser\$NombreUsuario\$grupoActual"
    
    if (Test-Path $rutaSimbolicaAntigua) {
        cmd /c rmdir "$rutaSimbolicaAntigua"
    }

    # 🔹 Crea un nuevo enlace simbólico al nuevo grupo
    cmd /c mklink /D "C:\FTP\LocalUser\$NombreUsuario\$NuevoGrupo" "C:\FTP\$NuevoGrupo"

    # Verifica si el servicio FTP está corriendo antes de reiniciarlo
$ftpService = Get-Service -Name "FTPSVC" -ErrorAction SilentlyContinue
if ($ftpService -and $ftpService.Status -eq "Running") {
    Restart-WebItem "IIS:\Sites\FTP" -Verbose
}
    Write-Host "El usuario '$NombreUsuario' ha sido movido correctamente a '$NuevoGrupo'." -ForegroundColor Green
}

function Eliminar-Usuario {
    param (
        [string]$NombreUsuario
    )

    #Verificar si el usuario existe antes de eliminarlo
    $existeUsuario = net user $NombreUsuario 2>$null
    if (-not $existeUsuario) {
        Write-Host "Error: El usuario '$NombreUsuario' no existe." -ForegroundColor Red
        return
    }

    Write-Host "Eliminando usuario '$NombreUsuario'..." -ForegroundColor Cyan

    #Eliminar al usuario del sistema
    net user "$NombreUsuario" /delete

    #Eliminar al usuario de todos los grupos
    foreach ($grupo in @("recursadores", "reprobados", "general")) {
        if (net localgroup $grupo | Select-String -Pattern $NombreUsuario) {
            net localgroup "$grupo" "$NombreUsuario" /delete
        }
    }

    #Eliminar carpetas y enlaces simbólicos del usuario
    $carpetaUsuario = "C:\FTP\$NombreUsuario"
    $carpetaLocalUser = "C:\FTP\LocalUser\$NombreUsuario"

    if (Test-Path $carpetaUsuario) { Remove-Item -Recurse -Force $carpetaUsuario }
    if (Test-Path $carpetaLocalUser) { Remove-Item -Recurse -Force $carpetaLocalUser }

    #Eliminar permisos de FTP en IIS
    Remove-WebConfigurationProperty -PSPath IIS:\ -Location "FTP/$NombreUsuario" -Filter "system.ftpServer/security/authorization" -Name "."

    #Reiniciar el servicio FTP para aplicar cambios
    Restart-WebItem "IIS:\Sites\FTP"

    Write-Host "El usuario '$NombreUsuario' ha sido eliminado correctamente." -ForegroundColor Green
}
