# Importa las funciones necesarias
. .\Ftp_function.ps1
. .\Ftp_config.ps1

# Función para mostrar el menú principal
function Mostrar-MenuPrincipal {
    Write-Host "Menú de administración del FTP:"
    Write-Host "1. Agregar nuevo usuario"
    Write-Host "2. Mover usuario a otro grupo"
    Write-Host "3. Eliminar usuario"
    Write-Host "4. Salir"
    return (Read-Host "Selecciona una opción")
}
# Función para validar nombres de usuario
function Validar-NombreUsuario {
    param (
        [string]$NombreUsuario
    )

    if ($NombreUsuario -match '[^a-zA-Z0-9_-]' -or $NombreUsuario.Length -lt 3) {
        Write-Host "Error: Nombre de usuario inválido. Solo se permiten letras, números, guiones y mínimo 3 caracteres." -ForegroundColor Red
        return $false
    }
    return $true
}

# Bucle del menú principal
do {
    $opcion = Mostrar-MenuPrincipal

    switch ($opcion) {
        1 {
            do {
                $nombreUsuario = Read-Host "Ingresa el nombre del usuario"
            } while (-not (Validar-NombreUsuario -NombreUsuario $nombreUsuario))
            # Verifica si el usuario ya existe
            $existe = net user $nombreUsuario 2>$null
            if ($existe) {
                Write-Host "El usuario $nombreUsuario ya existe. Intenta con otro nombre." -ForegroundColor Red
                break
            }
            $contrasenaUsuario = Read-Host "Ingresa la contraseña del usuario" -AsSecureString
            
            $grupoAsignado = Read-Host "Ingresa el grupo al que pertenece (recursadores /  reprobados)"
            if (-not (Validar-Grupo -Grupo $grupoAsignado)) {
                Write-Host "El grupo '$grupoAsignado' no es válido." -ForegroundColor Red
            return
            }
            # Valida la contraseña
            if (-not (Validar-Contra -Contrasena $contrasenaUsuario)) {
                Write-Host "Contraseña no válida. Intenta de nuevo." -ForegroundColor Red
                break
            }

            # Agrega el usuario
            Agregar-Usuario -NombreUsuario $nombreUsuario -ContrasenaUsuario $contrasenaUsuario -GrupoAsignado $grupoAsignado
        }
        2 {
            $nombreUsuario = Read-Host "Ingresa el nombre del usuario a mover"
            $nuevoGrupo = Read-Host "Ingresa el nuevo grupo (grupo1 / grupo2)"
            Mover-Usuario -NombreUsuario $nombreUsuario -NuevoGrupo $nuevoGrupo
        }
        3 {
            do {
                $nombreUsuario = Read-Host "Ingresa el nombre del usuario a eliminar"
            } while (-not (Validar-NombreUsuario -NombreUsuario $nombreUsuario))

            # Confirmación antes de eliminar el usuario
            $confirmacion = Read-Host "¿Estás seguro de que deseas eliminar al usuario '$nombreUsuario'? (S/N)"
            if ($confirmacion -eq "S") {
                Eliminar-Usuario -NombreUsuario $nombreUsuario
            } else {
                Write-Host "Operación cancelada." -ForegroundColor Yellow
            }
        }
        4 {
            Write-Host "Saliendo..." -ForegroundColor Green
            break
        }
        default {
            Write-Host "Opción no válida, intenta nuevamente." -ForegroundColor Red
        }
    }
} while ($opcion -ne 4)

