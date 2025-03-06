# Importa las funciones necesarias
. .\Ftp_function.ps1
. .\Ftp_config.ps1

# Función para mostrar el menú principal
function Mostrar-MenuPrincipal {
    Write-Host "Menú de administración del FTP:"
    Write-Host "1. Agregar nuevo usuario"
    Write-Host "2. Mover usuario a otro grupo"
    Write-Host "3. Salir"
    return (Read-Host "Selecciona una opción")
}

# Bucle del menú principal
do {
    $opcion = Mostrar-MenuPrincipal

    switch ($opcion) {
        1 {
            $nombreUsuario = Read-Host "Ingresa el nombre del usuario"
            # Verifica si el usuario ya existe
            $existe = net user $nombreUsuario 2>$null
            if ($existe) {
                Write-Host "El usuario $nombreUsuario ya existe. Intenta con otro nombre." -ForegroundColor Red
                break
            }
            $contrasenaUsuario = Read-Host "Ingresa la contraseña del usuario" -AsSecureString
            $grupoAsignado = Read-Host "Ingresa el grupo al que pertenece (A: grupo1 / B: grupo2)"

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
            Write-Host "Saliendo..." -ForegroundColor Green
            break
        }
        default {
            Write-Host "Opción no válida, intenta nuevamente." -ForegroundColor Red
        }
    }
} while ($opcion -ne 3)
