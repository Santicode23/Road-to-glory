# Creando Unidades Organizativas
function CreaEstructura {

   $NombreOU = $args[0]
   $dominioLDAP = $args[1]
   $rutaOU = ("OU="+$NombreOU+","+$dominioLDAP)
   if ([adsi]::Exists(("LDAP://" + $rutaOU))) 
   {
      write-host ("La Unidad Organizativa " + $NombreOU + " ya existe.") -ForegroundColor Red
   } 
   else
   {
      write-host ("Creando la OU "+$NombreOU+","+$dominioLDAP) -ForegroundColor Green
      new-ADOrganizationalUnit -DisplayName $NombreOU -Name $NombreOU -path $dominioLDAP
   }
}

function CrearUO {

    $dominioLDAP="DC=lilsdomain,DC=local"
    CreaEstructura "CUATES" $dominioLDAP
    CreaEstructura "NO_CUATES" $dominioLDAP

}

# Creando Usuarios
function NuevoUsuario {
   param (
      [string]$NombreUsuario,
      [string]$NombreLogon,
      [string]$UO
   )

   $dominioLDAP = "DC=lilsdomain,DC=local"
   $rutaOU = "OU=$UO,$dominioLDAP"

   if (Get-ADUser -Filter {SamAccountName -eq $NombreLogon}) {
     Write-Host "La cuenta de usuario $NombreLogon ya existe." -ForegroundColor Red
   } else {
     Write-Host "Creando el usuario $NombreLogon en la unidad organizativa $rutaOU" -ForegroundColor Green
     New-ADUser -DisplayName $NombreUsuario `
                 -Name $NombreLogon `
                 -UserPrincipalName "$NombreLogon@lilsdomain.local" `
                 -Enabled $true `
                 -Path $rutaOU `
                 -AccountPassword (ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force) `
                 -ChangePasswordAtLogon $true
   }
}

function CrearUsuarios {
   Write-Host "=== CREAR USUARIOS ===" -ForegroundColor Cyan

   # Usuarios para CUATES
   $user1 = Read-Host "Ingrese el nombre del primer usuario de CUATES"
   $logon1 = Read-Host "Ingrese el logon name del primer usuario de CUATES"
   NuevoUsuario -NombreUsuario $user1 -NombreLogon $logon1 -UO "CUATES"

   $user2 = Read-Host "Ingrese el nombre del segundo usuario de CUATES"
   $logon2 = Read-Host "Ingrese el logon name del segundo usuario de CUATES"
   NuevoUsuario -NombreUsuario $user2 -NombreLogon $logon2 -UO "CUATES"

   # Usuarios para NO_CUATES
   $user3 = Read-Host "Ingrese el nombre del primer usuario de NO_CUATES"
   $logon3 = Read-Host "Ingrese el logon name del primer usuario de NO_CUATES"
   NuevoUsuario -NombreUsuario $user3 -NombreLogon $logon3 -UO "NO_CUATES"

   $user4 = Read-Host "Ingrese el nombre del segundo usuario de NO_CUATES"
   $logon4 = Read-Host "Ingrese el logon name del segundo usuario de NO_CUATES"
   NuevoUsuario -NombreUsuario $user4 -NombreLogon $logon4 -UO "NO_CUATES"
}