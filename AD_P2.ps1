function EstablecerHorarioCuates {
 
    # Definir la UO
    $UO = "OU=CUATES,DC=pedimospizza,DC=com"

    # Obtener todos los usuarios en esa UO
    $usuarios = Get-ADUser -Filter * -SearchBase $UO
 
    # Definiendo el horario de acceso
    # 3 bytes por dia, 1 bit por hora
    # Permitiendo logon de L a S, de 8am a 3pm (hora 14)
    [byte[]]$horario = @(0,128,63,0,128,63,0,128,63,0,128,63,0,128,63,0,128,63,0,128,63)
 
    foreach ($usuario in $usuarios) {
 
        Get-ADUser -Identity $usuario |
        Set-ADUser -Replace @{logonhours = $hours}
    }
}

function EstablecerHorarioNoCuates {
 
    # Definir la UO
    $UO = "OU=NO_CUATES,DC=pedimospizza,DC=com"

    # Obtener todos los usuarios en esa UO
    $usuarios = Get-ADUser -Filter * -SearchBase $UO
 
    # Definiendo el horario de acceso
    # 3 bytes por dia, 1 bit por hora
    # Permitiendo logon de L a S, de 3pm a 2am
    [byte[]]$horario = @(255,1,192,255,1,192,255,1,192,255,1,192,255,1,192,255,1,192,255,1,192)
 
    foreach ($usuario in $usuarios) {
 
        Get-ADUser -Identity $usuario |
        Set-ADUser -Replace @{logonhours = $hours}
    }
}


# Llamada a la funcion
EstablecerHorarioCuates
EstablecerHorarioNoCuatesfunction EstablecerHorarioCuates {
 
    # Definir la UO
    $UO = "OU=CUATES,DC=pedimospizza,DC=com"

    # Obtener todos los usuarios en esa UO
    $usuarios = Get-ADUser -Filter * -SearchBase $UO
 
    # Definiendo el horario de acceso
    # 3 bytes por dia, 1 bit por hora
    # Permitiendo logon de L a S, de 8am a 3pm (hora 14)
    [byte[]]$horario = @(0,128,63,0,128,63,0,128,63,0,128,63,0,128,63,0,128,63,0,128,63)
 
    foreach ($usuario in $usuarios) {
 
        Get-ADUser -Identity $usuario |
        Set-ADUser -Replace @{logonhours = $hours}
    }
}

function EstablecerHorarioNoCuates {
 
    # Definir la UO
    $UO = "OU=NO_CUATES,DC=pedimospizza,DC=com"

    # Obtener todos los usuarios en esa UO
    $usuarios = Get-ADUser -Filter * -SearchBase $UO
 
    # Definiendo el horario de acceso
    # 3 bytes por dia, 1 bit por hora
    # Permitiendo logon de L a S, de 3pm a 2am
    [byte[]]$horario = @(255,1,192,255,1,192,255,1,192,255,1,192,255,1,192,255,1,192,255,1,192)
 
    foreach ($usuario in $usuarios) {
 
        Get-ADUser -Identity $usuario |
        Set-ADUser -Replace @{logonhours = $hours}
    }
}


# Llamada a la funcion
EstablecerHorarioCuates
EstablecerHorarioNoCuates