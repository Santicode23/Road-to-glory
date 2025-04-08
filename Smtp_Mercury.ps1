function Reglas_Correo_Firewall {
    New-NetFirewallRule -DisplayName "SMTP" -Direction Inbound -Protocol TCP -LocalPort 25 -Action Allow
    Write-Host "Regla de firewall creada: SMTP (Puerto 25)" -ForegroundColor Green
    
    New-NetFirewallRule -DisplayName "POP3" -Direction Inbound -Protocol TCP -LocalPort 110 -Action Allow
    Write-Host "Regla de firewall creada: POP3 (Puerto 110)"

    New-NetFirewallRule -DisplayName "IMAP" -Direction Inbound -Protocol TCP -LocalPort 143 -Action Allow
    Write-Host "Regla de firewall creada: IMAP (Puerto 143)"
    
    New-NetFirewallRule -DisplayName "James Server JMX" -Direction Inbound -Protocol TCP -LocalPort 9999 -Action Allow
    Write-Host "Regla de firewall creada: JMX para James Server (Puerto 9999)"
}

function Configuracion_JamesServer {
    param ( [string]$IP, [string]$DOMINIO )

    $archivoSMTP = "C:\Apache_JS\JamesServer\conf\smtpserver.xml"
    $archivoPOP3 = "C:\Apache_JS\JamesServer\conf\pop3server.xml"
    $archivoDomList = "C:\Apache_JS\JamesServer\conf\domainlist.xml"
    $archivoIMAP = "C:\Apache_JS\JamesServer\conf\imapserver.xml"

    #Leer el contenido del archivo DOMAINLIST
    $contenidoDL = Get-Content $archivoDomList
    #Reemplazar líneas específicas
    $contenidoDL = $contenidoDL -replace '       <domainname>localhost</domainname>', "       <domainname>$DOMINIO</domainname>"
    #Guardar el contenido modificado
    $contenidoDL | Set-Content $archivoDomList

    #Leer el contenido del archivo SMTPSERVER
    $contenidoSMTP = Get-Content $archivoSMTP
    #Reemplazar líneas específicas
    $contenidoSMTP = $contenidoSMTP -replace '<bind>0.0.0.0:25</bind>', "<bind>$IP:25</bind>"

    $contenidoSMTP = $contenidoSMTP -replace '                        <domain>yourdomain1</domain>', "                        <domain>$DOMINIO</domain>"
    #Guardar el contenido modificado
    $contenidoSMTP | Set-Content $archivoSMTP

    #Leer el contenido del archivo POP3SERVER
    $contenidoPOP3 = Get-Content $archivoPOP3
    #Reemplazar líneas específicas
    $contenidoPOP3 = $contenidoPOP3 -replace '<bind>0.0.0.0:110</bind>', "<bind>$IP:110</bind>"
    #Guardar el contenido modificado
    $contenidoPOP3 | Set-Content $archivoPOP3

    #Leer el contenido del archivo IMAPSERVER
    $contenidoIMAP = Get-Content $archivoIMAP
    #Reemplazar líneas específicas
    $contenidoIMAP = $contenidoIMAP -replace '<bind>0.0.0.0:143</bind>', "<bind>$IP:143</bind>"
    $contenidoIMAP = $contenidoIMAP -replace '       <plainAuthDisallowed>true</plainAuthDisallowed>', '       <plainAuthDisallowed>false</plainAuthDisallowed>'
    #Guardar el contenido modificado
    $contenidoIMAP | Set-Content $archivoIMAP

    #----------------------------------------JAMES SERVER-------------------------------------------
    Set-Location "C:\Apache_JS\JamesServer\bin"

    #Iniciar y verificar estado del servicio
    Write-Host "...Verificando e instalando Apache James Server..."
    james status
    james install
    james status
    james start
    james status
    #Esperar unos segundos para asegurar que el servicio esté levantado
    Start-Sleep -Seconds 5

    #Verificar dominios existentes
    Write-Host "Verificando dominios actuales en James Server..." -ForegroundColor Yellow
    .\james-cli --host 127.0.0.1 --port 9999 ListDomains
    #.\james-cli ListDomains

    #Agregar dominio
    Write-Host "Agregando dominio: $DOMINIO" -ForegroundColor Yellow
    .\james-cli AddDomain $DOMINIO

    #Listar dominios nuevamente para confirmar
    Write-Host "Dominios configurados tras agregar $DOMINIO" -ForegroundColor Yellow
    .\james-cli --host 127.0.0.1 --port 9999 ListDomains
    #.\james-cli ListDomains
}

function Agregar_Usuarios {
    param ( [string]$DOMINIO )

    Write-Host "[--- CREACION DE USUARIOS ---]"

    do {
        #Validacion del nombre de usuario
        $USUARIO = ""
        do {
            $USUARIO = Read-Host "Ingresa el nombre del usuario (maximo 15 caracteres, solo letras, numeros y guion bajo, sin espacios) (Enter para cancelar)"
            
            #Si el usuario presiona Enter regresamos al menu
            if ($USUARIO -eq "") {
                Write-Host "Operacion cancelada. Regresando al menu..." -ForegroundColor Yellow
                return
            }

            #Validar que solo contenga letras y números, sin espacios y maximo 8 caracteres
            if ($USUARIO.Length -gt 15 -or $USUARIO -match '[^a-z0-9_]' -or $USUARIO -match '^\d+$' -or $USUARIO -cmatch '[A-Z]') {
                Write-Host "El nombre de usuario NO ES VALIDO. Debe tener maximo 15 caracteres, solo letras, numeros y guion bajo, sin espacios." -ForegroundColor Red
                $USUARIO = $null
                continue
            }
        } while (-not $USUARIO)

        #Validacion de la contraseña
        $CONTRA = ""
        do {
            $CONTRA = Read-Host "Ingresa la contraseña del usuario $USUARIO (Enter para cancelar)"    #-AsSecureString

            #Si el usuario presiona Enter regresamos al menu principal
            if ($CONTRA -eq "") {
                Write-Host "Operacion cancelada. Regresando al menu..." -ForegroundColor Yellow
                return
            }

            #Verificar la contraseña con las condiciones requeridas
            if ($CONTRA.Length -lt 8 -or $CONTRA -notmatch '\d' -or $CONTRA -notmatch '[a-z]' -or $CONTRA -notmatch '[A-Z]' -or $CONTRA -notmatch '[^\w\s]') {
                Write-Host "La contraseña no es valida. Debe tener al menos 8 caracteres, un numero, una letra minuscula, una letra mayuscula y un simbolo especial." -ForegroundColor Red
                $CONTRA = $null
                continue
            }
            
            #Confirmacion de la contraseña
            $CONTRA2 = Read-Host "Confirma la contraseña (Enter para cancelar)"

            if ($CONTRA2 -eq "") {
                Write-Host "Operacion cancelada. Regresando al menu..." -ForegroundColor Yellow
                return
            }

            if ($CONTRA -ne $CONTRA2) {
                Write-Host "Las contraseñas no coinciden. Intenta nuevamente." -ForegroundColor Red
                $CONTRA = $null
            }

        } while (-not $CONTRA)

        #CREACION DE USUARIO CON LAS CREDENCIALES INGRESADAS
        Write-Host "Creando usuario $USUARIO..."
        & .\james-cli AddUser "$USUARIO@$DOMINIO" "$CONTRA"

        #Preguntar si se desea agregar otro usuario
        $crearOtro = Read-Host "¿Deseas crear otro usuario? (S/N)"
        if ($crearOtro -eq "S" -or $crearOtro -eq "s") {
            Write-Host "Creando otro usuario..." -ForegroundColor Green
        } elseif ($crearOtro -eq "N" -or $crearOtro -eq "n") {
            Write-Host "Operación terminada. Regresando..." -ForegroundColor Yellow
            return
        } else {
            Write-Host "Opcion NO VALIDA. Por favor ingresa 'S' o 'N'." -ForegroundColor RED
            continue
        }
    } while ($true)
}
