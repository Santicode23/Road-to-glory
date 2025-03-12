# Cargar funcioneess
Import-Module "C:\Users\Administrator\Desktop\FunctionHTTPW.ps1"

function Mostrar-Menu {
    Clear-Host
    Write-Host "=================================="
    Write-Host "        Instalador HTTP           "
    Write-Host "=================================="
    Write-Host "0. Instalar dependencias necesarias"
    Write-Host "1. Seleccionar Servicio"
    Write-Host "2. Seleccionar Version"
    Write-Host "3. Configurar Puerto"
    Write-Host "4. Proceder con la Instalacion"
    Write-Host "5. Verificar servicios instalados"
    Write-Host "6. Salir"
}

while ($true) {
    Mostrar-Menu
    $opcion_menu = Read-Host "Seleccione una opcion"

    switch ($opcion_menu) {
        "0" {
            instalar_dependencias
            Read-Host "Presione Enter para continuar..."
        }
        "1" {
           seleccionar_servicio
            Read-Host "Presione Enter para continuar..."
        }
        "2" {
            seleccionar_version
            Read-Host "Presione Enter para continuar..."
        }
        "3" {
            preguntar_puerto
            Read-Host "Presione Enter para continuar..."
        }
        "4" {
            Write-Host "=================================="
            Write-Host "      Resumen de la instalacion   "
            Write-Host "=================================="
            Write-Host "Servicio seleccionado: $servicio"
            Write-Host "Version seleccionada: $version"
            Write-Host "Puerto configurado: $puerto"
            Write-Host "=================================="
            $confirmacion = Read-Host "¿Desea proceder con la instalacion? (s/n)"
            if ($confirmacion -eq "s") {
                proceso_instalacion
            } else {
                Write-Host "Instalacion cancelada."
            }
            Read-Host "Presione Enter para continuar..."
        }
        "5" {
            Write-Host "Saliendo..."
            exit
        }
        default {
            Write-Host "Opcion no valida. Intente de nuevo."
            Read-Host "Presione Enter para continuar..."
        }
    }
}
