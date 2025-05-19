# CONFIGURACIÓN INICIAL

$dnsName = "WINSERVER2025.pedimospizza.com"
$subject = "CN=$dnsName"
$storeMy = "Cert:\LocalMachine\My"
$storeRoot = "Cert:\LocalMachine\Root"

# 1. ELIMINAR CERTIFICADOS EXISTENTES CON EL MISMO SUBJECT

Get-ChildItem -Path $storeMy | Where-Object {
    $_.Subject -eq $subject
} | ForEach-Object {
    Write-Host "Eliminando certificado anterior: $($_.Thumbprint)"
    Remove-Item -Path "$storeMy\$($_.Thumbprint)" -Force
}

# 2. CREAR NUEVO CERTIFICADO BÁSICO

$cert = New-SelfSignedCertificate -DnsName $dnsName -CertStoreLocation $storeMy

Write-Host "Certificado creado:"
Write-Host "Subject: $($cert.Subject)"
Write-Host "Thumbprint: $($cert.Thumbprint)"

# 3. COPIAR A 'TRUSTED ROOT CERTIFICATION AUTHORITIES'

$certPath = "$storeMy\$($cert.Thumbprint)"
$certObject = Get-Item -Path $certPath
$rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
$rootStore.Open("ReadWrite")
$rootStore.Add($certObject)
$rootStore.Close()

Write-Host "Certificado copiado a Trusted Root Certification Authorities"

# 4. ABRIR PUERTO 636 EN EL FIREWALL

$ruleName = "Abrir puerto 636 para LDAPS"
if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 636 `
        -Action Allow `
        -Profile Domain,Private `
        -Description "Permitir tráfico LDAPS (TCP 636)"
    Write-Host "Regla de firewall creada para puerto 636"
} else {
    Write-Host "La regla de firewall para el puerto 636 ya existe"
}

Write-Host "Proceso finalizado"
