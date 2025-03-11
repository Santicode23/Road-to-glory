function Validate-IP {
    param ([string]$ip)
    if (-not ($ip -match '^(\d{1,3}\.){3}\d{1,3}$')) {
        Write-Host "Error: IP inválida" -ForegroundColor Red
        exit 1
    }
}
