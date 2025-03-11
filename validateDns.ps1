# validate.ps1
function Validate-IP {
    param([string]$IP)
    if (-not ($IP -match "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$")) {
        Write-Host "Error: La dirección IP ingresada no es válida." -ForegroundColor Red
        exit
    }
}

function Validate-Domain {
    param([string]$Dominio)
    if (-not ($Dominio -match "^(?:[a-zA-Z0-9]+\.)+[a-zA-Z]{2,}$")) {
        Write-Host "Error: El dominio ingresado no es válido." -ForegroundColor Red
        exit
    }
}