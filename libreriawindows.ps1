### ACTIVE DIRECTORY
function Get-UserData {
    $users = @()
    $continue = $true
    
    while ($continue) {
        # Solicitar nombre de usuario
        $username = capturarUsuarioFTPValido "Coloque el nombre del usuario (o 'salir')"
        if ($username.ToLower() -eq 'salir') {
            $continue = $false
            break
        }
        
        # Validar OU
        $ouChoice = $null
        while ($ouChoice -notin @('1', '2')) {
            $ouChoice = Read-Host "A que OU pertenece? (1 para 'cuates', 2 para 'no cuates')"
        }
        $ouName = if ($ouChoice -eq '1') { "cuates" } else { "nocuates" }
        
        $pass = capturarContra

        # Agregar usuario al array
        $users += @{
            Name      = $username
            GivenName = "Usuario"
            Surname   = $username
            OU        = $ouName
            Pass      = $pass
        }
    }
    
    return $users
}

Function Set-LogonHours {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidateRange(0, 23)]
        [int[]]$TimeIn24Format,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
        [string]$Identity,

        [Parameter(Mandatory = $False)]
        [ValidateSet("WorkingDays", "NonWorkingDays")]
        [string]$NonSelectedDaysare = "NonWorkingDays",

        [Parameter(Mandatory = $False)][switch]$Sunday,
        [Parameter(Mandatory = $False)][switch]$Monday,
        [Parameter(Mandatory = $False)][switch]$Tuesday,
        [Parameter(Mandatory = $False)][switch]$Wednesday,
        [Parameter(Mandatory = $False)][switch]$Thursday,
        [Parameter(Mandatory = $False)][switch]$Friday,
        [Parameter(Mandatory = $False)][switch]$Saturday
    )

    Process {
        $FullByte = New-Object "byte[]" 21
        $FullDay = [ordered]@{}
        0..23 | ForEach-Object { $FullDay.Add($_, "0") }

        $TimeIn24Format.ForEach({ $FullDay[$_] = "1" })
        $Working = -join ($FullDay.Values)

        switch ($NonSelectedDaysare) {
            'NonWorkingDays' {
                $SundayValue = $MondayValue = $TuesdayValue = $WednesdayValue = `
                    $ThursdayValue = $FridayValue = $SaturdayValue = "000000000000000000000000"
            }
            'WorkingDays' {
                $SundayValue = $MondayValue = $TuesdayValue = $WednesdayValue = `
                    $ThursdayValue = $FridayValue = $SaturdayValue = "111111111111111111111111"
            }
        }

        switch ($PSBoundParameters.Keys) {
            'Sunday'    { $SundayValue = $Working }
            'Monday'    { $MondayValue = $Working }
            'Tuesday'   { $TuesdayValue = $Working }
            'Wednesday' { $WednesdayValue = $Working }
            'Thursday'  { $ThursdayValue = $Working }
            'Friday'    { $FridayValue = $Working }
            'Saturday'  { $SaturdayValue = $Working }
        }

        $AllTheWeek = "{0}{1}{2}{3}{4}{5}{6}" -f `
            $SundayValue, $MondayValue, $TuesdayValue, $WednesdayValue, `
            $ThursdayValue, $FridayValue, $SaturdayValue

        # Ajustar zona horaria si es necesario
        $offset = (Get-TimeZone).BaseUtcOffset.Hours

        if ($offset -lt 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0, 168 + $offset)
            $TimeZoneOffset1 = $AllTheWeek.Substring(168 + $offset)
            $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
        }
        elseif ($offset -gt 0) {
            $TimeZoneOffset = $AllTheWeek.Substring(0, $offset)
            $TimeZoneOffset1 = $AllTheWeek.Substring($offset)
            $FixedTimeZoneOffSet = "$TimeZoneOffset1$TimeZoneOffset"
        }
        else {
            $FixedTimeZoneOffSet = $AllTheWeek
        }

        # Convertir binario a bytes (logonHours espera 21 bytes)
        $i = 0
        $BinaryResult = $FixedTimeZoneOffSet -split '(\d{8})' | Where-Object { $_ -match '(\d{8})' }

        foreach ($singleByte in $BinaryResult) {
            $Tempvar = $singleByte.ToCharArray()
            [array]::Reverse($Tempvar)
            $Tempvar = -join $Tempvar
            $Byte = [Convert]::ToByte($Tempvar, 2)
            $FullByte[$i] = $Byte
            $i++
        }

        Set-ADUser -Identity $Identity -Replace @{logonhours = $FullByte}
    }

    End {
    }
}

function Get-LogonsUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$user  # SamAccountName del usuario
    )

    # Obtener DN del usuario y nombre de dominio
    $userData = Get-ADUser -Identity $user -Properties DistinguishedName -ErrorAction SilentlyContinue
    if (-not $userData) {
        Write-Host "Usuario '$user' no encontrado."
        return
    }
    
    $userDN = $userData.DistinguishedName
    $domain = (Get-ADDomain).DNSRoot

    # Event IDs a buscar
    $userEvents = @(4624,4625,4648,4720,4722,4725,4738,4662,5136)

    try {
        $events = Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=$($userEvents -join ' or EventID=')]]" -MaxEvents 100 -ErrorAction Stop |
                  Where-Object { 
                      # Para eventos de logon (4624,4625,4648)
                      if ($_.Id -in (4624,4625,4648)) {
                          $_.Properties[5].Value -like "*\$user" -or  # DOMINIO\usuario
                          $_.Properties[5].Value -eq $user             # usuario solo
                      }
                      # Para otros eventos de AD
                      else {
                          $_.Properties[4].Value -eq $userDN -or 
                          $_.Properties[5].Value -eq $user
                      }
                  }

        if (-not $events) {
            Write-Host "No hay inicios de sesion registrados del usuario '$user'."
            return
        }

        $report = $events | ForEach-Object {
            [PSCustomObject]@{
                Fecha      = $_.TimeCreated
                EventoID   = $_.Id
                Accion     = switch ($_.Id) {
                    4624 { "Inicio de sesion exitoso" }
                    4625 { "Inicio de sesion fallido" }
                    4648 { "Logon con credenciales explícitas" }
                    4720 { "Usuario creado" }
                    4722 { "Contraseña cambiada" }
                    4725 { "Usuario deshabilitado" }
                    4738 { "Membresía de grupo modificada" }
                    4662 { "Acceso a objeto AD" }
                    5136 { "Atributo modificado" }
                    default { "Otro" }
                }
                # Mapeo correcto según tipo de evento
                Usuario    = if ($_.Id -in (4624,4625,4648)) { $_.Properties[5].Value } else { $_.Properties[5].Value }
                IP_Origen  = if ($_.Id -in (4624,4625,4648)) { $_.Properties[18].Value } else { "N/A" }
                Objetivo   = if ($_.Id -in (4624,4625,4648)) { $_.Properties[6].Value } else { $_.Properties[4].Value }
            }
        }

        # Ordenamos por fecha descendente y mostramos
        $report | Sort-Object Fecha -Descending -Unique | Format-Table -AutoSize
    }
    catch {
        Write-Host "Error al leer eventos: $_" -ForegroundColor Red
    }
}

# Función para auditoría general de AD (equivalente a Get-ADAuditEvents)
function Get-ADEvents {
    [CmdletBinding()]
    param ()

    # Event IDs clave para AD (personalizable)
    $targetEvents = @(4662, 4738, 4720, 4726, 4767)

    try {
        $events = Get-WinEvent -LogName Security -FilterXPath "*[System[EventID=$($targetEvents -join ' or EventID=')]]" -MaxEvents 1000 -ErrorAction Stop

        $report = $events | ForEach-Object {
            [PSCustomObject]@{
                Fecha      = $_.TimeCreated
                EventoID   = $_.Id
                Accion     = switch ($_.Id) {
                    4662 { "Acceso a objeto AD" }
                    4738 { "Cambio en grupo (membresia)" }
                    4720 { "Usuario creado" }
                    4726 { "Usuario eliminado" }
                    4767 { "Cambio en cuenta de servicio" }
                    default { "Otro" }
                }
                Usuario    = $_.Properties[5].Value
                Objetivo   = $_.Properties[4].Value
            }
        }

        $report | Sort-Object Fecha -Descending -Unique | Format-Table -AutoSize
    }
    catch {
        Write-Host "Error al leer eventos: $_" -ForegroundColor Red
    }
}

