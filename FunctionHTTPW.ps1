# Variables globales (compartidas entre las funciones)
$global:servicio = ""   # Almacena el servicio seleccionado (IIS, Apache, Tomcat)
$global:version = ""    # Almacena la versión seleccionada del servicio
$global:puerto = ""     # Almacena el puerto en el que se configurará el servicio
$global:versions = @()  # Almacena un array con las versiones disponibles del servicio seleccionado

function seleccionar_servicio {
    Write-Host "Seleccione el servicio que desea instalar:"
    Write-Host "1.- IIS"
    Write-Host "2.- Apache"
    Write-Host "3.- Tomcat"
    $opcion = Read-Host "Opción"

    switch ($opcion) {
        "1" {
            $global:servicio = "IIS"
            Write-Host "Servicio seleccionado: IIS"
            obtener_versiones_IIS
        }
        "2" {
            $global:servicio = "Apache"
            Write-Host "Servicio seleccionado: Apache"
            obtener_versiones_apache
        }
        "3" {
            $global:servicio = "Tomcat"
            Write-Host "Servicio seleccionado: Tomcat"
            obtener_versiones_tomcat
        }
        default {
            Write-Host "Opción no válida. Intente de nuevo."
            seleccionar_servicio
        }
    }
}

function obtener_versiones_IIS {
    # Verificar si IIS ya está instalado
    $iisVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp" -ErrorAction SilentlyContinue).MajorVersion

    if ($iisVersion) {
        Write-Host "IIS ya está instalado. Versión detectada: $iisVersion"
        $global:version = "IIS $iisVersion.0"
    } else {
        Write-Host "IIS no está instalado. Determinando la versión predeterminada..."

        # Obtener la versión del sistema operativo
        $osBuild = (Get-ComputerInfo).WindowsBuildLabEx

        # Identificar la versión de Windows Server
        switch -Wildcard ($osBuild) {
            "*20348*" { $global:version = "IIS 10.0 (Windows Server 2022)" }
            "*22000*" { $global:version = "IIS 10.0 (Windows Server 2025 / Windows 11)" }
            "*22621*" { $global:version = "IIS 10.0 (Windows Server 2025 / Windows 11 22H2)" }
            default   { $global:version = "IIS 10.0 (Versión predeterminada para Windows)" }
        }

        Write-Host "La versión predeterminada de IIS que se instalará en su sistema es: $global:version"
    }
}

function obtener_versiones_apache {
    Write-Host "Obteniendo versiones de Apache HTTP Server desde https://httpd.apache.org/download.cgi"

    # Descargar el contenido HTML de la página oficial de Apache
    try {
        $html = Invoke-WebRequest -Uri "https://httpd.apache.org/download.cgi" -UseBasicParsing
    } catch {
        Write-Host "Error al descargar la página de Apache. Verifique su conexión a Internet."
        return
    }

    # Convertir el HTML en texto
    $htmlContent = $html.Content

    # Buscar versiones en formato httpd-X.Y.Z usando expresión regular
    $versionsRaw = [regex]::Matches($htmlContent, "httpd-(\d+\.\d+\.\d+)") | ForEach-Object { $_.Groups[1].Value }

    # Extraer la versión LTS (2.4.x) y la versión de desarrollo (2.5.x o superior si existe)
    $versionLTS = ($versionsRaw | Where-Object { $_ -match "^2\.4\.\d+$" } | Select-Object -First 1)
    $versionDev = ($versionsRaw | Where-Object { $_ -match "^2\.5\.\d+$" } | Select-Object -First 1)

    # Si no hay versión de desarrollo disponible
    if (-not $versionDev) {
        $versionDev = "No disponible"
    }

    # Asegurar que el array `$global:versions` tenga solo dos valores correctos
    $global:versions = @($versionLTS, $versionDev)

    Write-Host "Versión estable (LTS): $versionLTS"
    Write-Host "Versión de desarrollo: $versionDev"
}

function obtener_urls_tomcat {
    Write-Host "Obteniendo URLs dinámicas de descarga desde el índice de Tomcat..."

    # Intentar obtener el contenido de la página principal de Tomcat
    try {
        $html = Invoke-WebRequest -Uri "https://tomcat.apache.org/index.html" -UseBasicParsing
    } catch {
        Write-Host "Error al descargar la página de Tomcat. Verifique su conexión a Internet."
        return
    }

    # Convertir el contenido HTML en texto
    $htmlContent = $html.Content

    # Extraer los enlaces de descarga de Tomcat
    $urls = [regex]::Matches($htmlContent, "https://tomcat.apache.org/download-(\d+)\.cgi") | ForEach-Object { $_.Value }

    # Variables para almacenar las URLs de LTS y Dev
    $global:tomcat_url_lts = ""
    $global:tomcat_url_dev = ""

    # Identificar la versión LTS y la versión de desarrollo
    foreach ($url in $urls) {
        $versionNumber = [regex]::Match($url, "\d+").Value

        if ([int]$versionNumber -lt 11) {
            $global:tomcat_url_lts = $url
        }

        if ([int]$versionNumber -eq 11) {
            $global:tomcat_url_dev = $url
        }
    }

    Write-Host "URL de la versión estable (LTS): $global:tomcat_url_lts"
    Write-Host "URL de la versión de desarrollo: $global:tomcat_url_dev"
}

function obtener_versiones_tomcat {
    obtener_urls_tomcat  # Primero obtenemos las URLs de descarga

    Write-Host "Obteniendo versiones de Apache Tomcat desde las URLs detectadas..."

    # Obtener la versión estable desde la página LTS
    if ($global:tomcat_url_lts -ne "") {
        try {
            $htmlLTS = Invoke-WebRequest -Uri $global:tomcat_url_lts -UseBasicParsing
            $versionLTS = [regex]::Match($htmlLTS.Content, "v(\d+\.\d+\.\d+)").Groups[1].Value
        } catch {
            Write-Host "Error al obtener la versión LTS de Tomcat."
            $versionLTS = "No disponible"
        }
    } else {
        $versionLTS = "No disponible"
    }

    # Obtener la versión de desarrollo desde la página Dev
    if ($global:tomcat_url_dev -ne "") {
        try {
            $htmlDev = Invoke-WebRequest -Uri $global:tomcat_url_dev -UseBasicParsing
            $versionDev = [regex]::Match($htmlDev.Content, "v(\d+\.\d+\.\d+)").Groups[1].Value
        } catch {
            Write-Host "Error al obtener la versión de desarrollo de Tomcat."
            $versionDev = "No disponible"
        }
    } else {
        $versionDev = "No disponible"
    }

    # Guardar versiones en la variable global
    $global:versions = @($versionLTS, $versionDev)

    Write-Host "Versión estable (LTS): $versionLTS"
    Write-Host "Versión de desarrollo: $versionDev"
}

function seleccionar_version {
    if (-not $global:servicio) {
        Write-Host "Debe seleccionar un servicio antes de elegir la versión."
        return
    }
        # Mostrar el servicio antes de la selección de versión
    Write-Host "`n========================================"
    Write-Host "Seleccionando versión para: $global:servicio"
    Write-Host "========================================"

    # Si el servicio es IIS, no permitir selección de versión
    if ($global:servicio -eq "IIS") {
        Write-Host "IIS no tiene versiones seleccionables. Se instalará la versión predeterminada para Windows Server."
        $global:version = "IIS (Versión según sistema operativo)"
        return
    }

    if ($global:servicio -eq "Apache") {
        Write-Host "Apache solo cuenta con version stable. Se instalará la version 2.4.63"
        $global:version = "2.4.63"
        return
    }

    # Extraer las versiones en variables locales asegurando que `$global:versions` es un array válido
    $versionLTS = if ($global:versions.Count -ge 1) { $global:versions[0] } else { "No disponible" }
    $versionDev = if ($global:versions.Count -ge 2) { $global:versions[1] } else { "No disponible" }

    $global:version = $versionLTS
    Write-Host "1.- Versión Estable (LTS): $global:version"
    $global:version = $versionDev

    Write-Host "2.- Versión de Desarrollo: $global:version"
    $opcion = Read-Host "Opción"

    switch ($opcion) {
        "1" {
            $global:version = $versionLTS
            Write-Host "Versión seleccionada: $global:version"
        }
        "2" {
            $global:version = $versionDev
            Write-Host "Versión seleccionada: $global:version"
        }
        default {
            Write-Host "Opción no válida."
        }
    }
}

function verificar_puerto_en_uso {
    param (
        [int]$puerto
    )

    # Usar netstat para verificar si el puerto está en uso
    $ocupado = netstat -an | Select-String ":$puerto " | Where-Object { $_ -match "LISTENING" }

    if ($ocupado) {
        return $true  # Puerto en uso
    } else {
        return $false # Puerto disponible
    }
}

function verificar_puerto_restringido {
    param (
        [int]$puerto
    )
    # Lista de puertos restringidos por servicios comunes o navegadores
    $puertos_restringidos = @(21, 22, 23, 25, 53, 110, 143, 161, 162, 389, 443, 465, 993, 995, 1433, 1434, 1521, 3306, 3389,
                              1, 7, 9, 11, 13, 15, 17, 19, 137, 138, 139, 2049, 3128, 6000)

    return $puerto -in $puertos_restringidos
}

function preguntar_puerto {
    while ($true) {
        $puerto = Read-Host "Ingrese el puerto para el servicio (debe estar entre 1 y 65535, excepto los restringidos)"

        # Validar que la entrada sea un número dentro del rango permitido
        if ($puerto -match "^\d+$") {
            $puerto = [int]$puerto  # Convertir a número
            if ($puerto -ge 1 -and $puerto -le 65535) {
                if (verificar_puerto_restringido -puerto $puerto) {
                    Write-Host "El puerto $puerto está restringido por otros servicios. Intente con otro."
                } elseif (-not (verificar_puerto_en_uso -puerto $puerto)) {
                    Write-Host "El puerto $puerto está disponible."
                    $global:puerto = $puerto
                    break
                } else {
                    Write-Host "El puerto $puerto está ocupado. Intente con otro."
                }
            } else {
                Write-Host "Número fuera de rango. Ingrese un puerto entre 1 y 65535."
            }
        } else {
            Write-Host "Entrada inválida. Ingrese un número de puerto válido."
        }
    }
}

function habilitar_puerto_firewall {
    if ($global:puerto) {
        # Verifica si ya existe una regla para el puerto
        $reglaExistente = Get-NetFirewallRule | Where-Object { $_.DisplayName -eq "Puerto $global:puerto" }
        
        if ($reglaExistente) {
            Write-Host "El puerto $global:puerto ya tiene una regla de firewall activa."
        } else {
            # Crear una nueva regla en el firewall
            New-NetFirewallRule -DisplayName "Puerto $global:puerto" -Direction Inbound -Protocol TCP -LocalPort $global:puerto -Action Allow | Out-Null
            Write-Host "Se ha habilitado el puerto $global:puerto en el firewall."
        }
    } else {
        Write-Host "No hay un puerto definido en la variable global `$global:puerto`."
    }
}


function proceso_instalacion {
    if (-not $global:servicio -or -not $global:version -or -not $global:puerto) {
        Write-Host "Debe seleccionar el servicio, la versión y el puerto antes de proceder con la instalación."
        return
    }

    Write-Host "Iniciando instalación silenciosa de $global:servicio versión $global:version en el puerto $global:puerto..."

    switch ($global:servicio) {
        "IIS" {
            instalar_iis
        }
        "Apache" {
            instalar_apache
        }
        "Tomcat" {
            instalar_tomcat
        }
        default {
            Write-Host "Servicio desconocido. No se puede proceder."
            return
        }
    }

    Write-Host "Instalación completada para $global:servicio versión $global:version en el puerto $global:puerto."

    # Limpiar variables globales después de la instalación
    $global:servicio = $null
    $global:version = $null
    $global:puerto = $null
}

function instalar_dependencias {
    Write-Host "`n============================================"
    Write-Host "   Verificando e instalando dependencias...   "
    Write-Host "============================================"

    # Verificar e instalar Visual C++ Redistributable
    Write-Host "`nVerificando Visual C++ Redistributable..."

    $vcInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | 
                   Get-ItemProperty | 
                   Where-Object { $_.DisplayName -match "Visual C\+\+ (2015|2017|2019|2022) Redistributable" }

    if ($vcInstalled) {
        Write-Host "Visual C++ Redistributable ya está instalado."
    } else {
        Write-Host "Falta Visual C++. Descargando e instalando..."
        $vcUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        $vcInstaller = "$env:TEMP\vc_redist.x64.exe"
        Invoke-WebRequest -Uri $vcUrl -OutFile $vcInstaller
        Start-Process -FilePath $vcInstaller -ArgumentList "/install /quiet /norestart" -NoNewWindow -Wait
        Write-Host "Visual C++ Redistributable instalado correctamente."
    }

    # Verificar e instalar Amazon Corretto JDK 21
    Write-Host "`nVerificando Amazon Corretto JDK 21..."

    $jdkBasePath = "C:\Java"

    # Buscar la carpeta correcta del JDK (detecta la versión instalada automáticamente)
    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

    if ($jdkInstallPath -and (Test-Path "$jdkInstallPath\bin\java.exe")) {
        Write-Host "Amazon Corretto JDK 21 ya está instalado en: $jdkInstallPath"
    } else {
        Write-Host "Falta JDK 21. Descargando e instalando..."
        $jdkUrl = "https://corretto.aws/downloads/latest/amazon-corretto-21-x64-windows-jdk.zip"
        $jdkZipPath = "$env:TEMP\Corretto21.zip"

        Invoke-WebRequest -Uri $jdkUrl -OutFile $jdkZipPath

        # Crear directorio de instalación si no existe
        if (-Not (Test-Path $jdkBasePath)) {
            New-Item -ItemType Directory -Path $jdkBasePath | Out-Null
        }

        # Extraer el archivo ZIP
        Write-Host "Extrayendo Amazon Corretto JDK 21..."
        Expand-Archive -Path $jdkZipPath -DestinationPath $jdkBasePath -Force
        Remove-Item -Path $jdkZipPath -Force

        # Detectar la carpeta real del JDK instalada
        $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

        if (-not $jdkInstallPath) {
            Write-Host "Error: No se encontró la carpeta del JDK después de la instalación."
            return
        }

        Write-Host "Amazon Corretto JDK 21 instalado en: $jdkInstallPath"
    }

    # Configurar JAVA_HOME y agregar al PATH
    Write-Host "`nConfigurando JAVA_HOME y PATH..."

    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)

    # Obtener el PATH actual del sistema y asegurarse de que la carpeta bin del JDK está en él
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($currentPath -notlike "*$jdkInstallPath\bin*") {
        $newPath = "$currentPath;$jdkInstallPath\bin"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
    }

    # Refrescar variables de entorno en la sesión actual
    $env:JAVA_HOME = $jdkInstallPath
    $env:Path = "$env:Path;$jdkInstallPath\bin"

    Write-Host "JAVA_HOME configurado correctamente en: $env:JAVA_HOME"

    # Verificar que JAVA_HOME está correctamente configurado
    Write-Host "`nVerificando configuración de Java..."
    $javaVersion = & "$jdkInstallPath\bin\java.exe" -version 2>&1
    if ($javaVersion -match "21\.") {
        Write-Host "Configuración correcta: `n$javaVersion"
    } else {
        Write-Host "Error: JAVA_HOME no está configurado correctamente."
    }

    Write-Host "`nVerificación e instalación de dependencias completada."
}

function instalar_iis {
    try {
        Write-Host "Instalando IIS y todas sus características..."
        Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -ErrorAction Stop
        Set-Service -Name W3SVC -StartupType Automatic

        Write-Host "IIS instalado correctamente."
        
        # Llamar automáticamente a la configuración después de la instalación
        configurar_iis
    } catch {
        Write-Host "Error durante la instalación de IIS: $_"
    }
}

function configurar_iis {
    if (-not $global:puerto -or $global:puerto -notmatch '^\d+$') {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de configurar IIS."
        return
    }

    try {
        Write-Host "Configurando IIS en el puerto $global:puerto..."

        # Obtener y eliminar todas las vinculaciones existentes
        $bindings = Get-WebBinding -Name "Default Web Site"
        if ($bindings) {
            foreach ($binding in $bindings) {
                Remove-WebBinding -Name "Default Web Site" -IPAddress "*" -Port $binding.bindingInformation.Split(':')[1] -Protocol $binding.protocol
                Write-Host "Vinculación en el puerto $($binding.bindingInformation.Split(':')[1]) eliminada."
            }
        }

        # Crear nueva vinculación con el puerto seleccionado
        New-WebBinding -Name "Default Web Site" -Protocol "http" -IPAddress "*" -Port $global:puerto
        Write-Host "Nueva vinculación establecida en el puerto $global:puerto."

        # Reiniciar IIS
        Restart-Service W3SVC
        iisreset

        Write-Host "Configuración de IIS completada exitosamente."

        # Habilitar el puerto en el firewall
        habilitar_puerto_firewall
    } catch {
        Write-Host "Error durante la configuración de IIS: $_"
    }
}


function instalar_apache {
    # Verificar que la versión de Apache está definida
    if (-not $global:version) {
        Write-Host "Error: No se ha seleccionado una versión de Apache. Ejecute 'seleccionar_version' antes de instalar Apache."
        return
    }

    # Verificar que el puerto está definido
    if (-not $global:puerto) {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de instalar Apache."
        return
    }

    # Definir ruta de descarga con la versión seleccionada
    $url = "https://www.apachelounge.com/download/VS17/binaries/httpd-$global:version-250207-win64-VS17.zip"
    $destinoZip = "$env:USERPROFILE\Downloads\apache-$global:version.zip"
    $extraerdestino = "C:\Apache24"

    try {
        Write-Host "Iniciando instalación de Apache HTTP Server versión $global:version..."

        # Descargar Apache
        Write-Host "Descargando Apache desde: $url"
        $agente = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        Invoke-WebRequest -Uri $url -OutFile $destinoZip -MaximumRedirection 10 -UserAgent $agente -UseBasicParsing
        Write-Host "Apache descargado en: $destinoZip"

        # Extraer Apache en C:\Apache24
        Write-Host "Extrayendo archivos de Apache..."
        Expand-Archive -Path $destinoZip -DestinationPath "C:\" -Force
        Write-Host "Apache extraído en $extraerdestino"
        Remove-Item -Path $destinoZip -Force

        # Configurar el puerto en httpd.conf
        $configFile = Join-Path $extraerdestino "conf\httpd.conf"
        if (Test-Path $configFile) {
            (Get-Content $configFile) -replace "Listen 80", "Listen $global:puerto" | Set-Content $configFile
            Write-Host "Configuración actualizada para escuchar en el puerto $global:puerto"
        } else {
            Write-Host "Error: No se encontró el archivo de configuración en $configFile"
            return
        }

        # Buscar el ejecutable de Apache
        $apacheExe = Get-ChildItem -Path $extraerdestino -Recurse -Filter httpd.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($apacheExe) {
            $exeApache = $apacheExe.FullName
            Write-Host "Instalando Apache como servicio..."
            Start-Process -FilePath $exeApache -ArgumentList '-k', 'install', '-n', 'Apache24' -NoNewWindow -Wait
            Write-Host "Iniciando servicio Apache..."
            Start-Service -Name "Apache24"
            Write-Host "Apache instalado y ejecutándose en el puerto $global:puerto"

            # Habilitar el puerto en el firewall al final de la instalación
            habilitar_puerto_firewall
        } else {
            Write-Host "Error: No se encontró el ejecutable httpd.exe en $extraerdestino"
        }
    } catch {
        Write-Host "Error durante la instalación de Apache: $_"
    }
}

function instalar_tomcat {
    Write-Host "`n============================================"
    Write-Host "   Instalando Apache Tomcat...   "
    Write-Host "============================================"

    # Verificar que la versión de Tomcat está definida
    if (-not $global:version) {
        Write-Host "Error: No se ha seleccionado una versión de Tomcat. Ejecute 'seleccionar_version' antes de instalar Tomcat."
        return
    }

    # Verificar que el puerto está definido
    if (-not $global:puerto) {
        Write-Host "Error: No se ha definido un puerto válido. Ejecute 'preguntar_puerto' antes de instalar Tomcat."
        return
    }

    # Verificar y configurar JAVA_HOME con la detección automática del JDK instalado
    $jdkBasePath = "C:\Java"
    $jdkInstallPath = Get-ChildItem -Path $jdkBasePath -Directory | Where-Object { $_.Name -match "^jdk21.*" } | Select-Object -ExpandProperty FullName -First 1

    if (-not $jdkInstallPath -or -not (Test-Path "$jdkInstallPath\bin\java.exe")) {
        Write-Host "Error: Amazon Corretto JDK 21 no está instalado correctamente. Ejecute 'instalar_dependencias' primero."
        return
    }

    # Configurar JAVA_HOME y agregarlo al Path
    Write-Host "Configurando JAVA_HOME..."
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkInstallPath, [System.EnvironmentVariableTarget]::Machine)
    $env:JAVA_HOME = $jdkInstallPath

    # Asegurar que el JDK esté en el Path
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($currentPath -notlike "*$jdkInstallPath\bin*") {
        $newPath = "$currentPath;$jdkInstallPath\bin"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
    }
    $env:Path = "$env:Path;$jdkInstallPath\bin"

    Write-Host "JAVA_HOME configurado correctamente en: $env:JAVA_HOME"

    # Definir URLs y rutas
    $tomcatVersion = $global:version
    Write-Host "Versión completa de Tomcat seleccionada: $tomcatVersion"
    $majorVersion = ($tomcatVersion -split "\.")[0]  # Obtiene solo la versión mayor
    Write-Host "Versión mayor extraída: $majorVersion"
    
    $url = "https://dlcdn.apache.org/tomcat/tomcat-${majorVersion}/v$tomcatVersion/bin/apache-tomcat-$tomcatVersion-windows-x64.zip"
    $destinoZip = "$env:USERPROFILE\Downloads\tomcat-$tomcatVersion.zip"
    $extraerDestino = "C:\Tomcat"

    try {
        Write-Host "Descargando Tomcat desde: $url"
        Invoke-WebRequest -Uri $url -OutFile $destinoZip -MaximumRedirection 10 -UseBasicParsing
        Write-Host "Tomcat descargado en: $destinoZip"

        # Si la carpeta C:\Tomcat ya existe, la eliminamos
        if (Test-Path $extraerDestino) {
            Write-Host "Limpiando instalación anterior de Tomcat..."
            Remove-Item -Path $extraerDestino -Recurse -Force
        }

        # Extraer Tomcat
        Write-Host "Extrayendo archivos de Tomcat en $extraerDestino..."
        Expand-Archive -Path $destinoZip -DestinationPath "C:\" -Force
        Remove-Item -Path $destinoZip -Force

        # Detectar si los archivos están dentro de una subcarpeta
        $subcarpeta = Get-ChildItem -Path "C:\" | Where-Object { $_.PSIsContainer -and $_.Name -match "apache-tomcat-" }

        if ($subcarpeta) {
            Write-Host "Moviendo archivos de $($subcarpeta.FullName) a $extraerDestino..."
            Rename-Item -Path $subcarpeta.FullName -NewName "Tomcat"
        }

        # Verificar que server.xml exista en la ubicación correcta
        $configFile = "$extraerDestino\conf\server.xml"
        if (-not (Test-Path $configFile)) {
            Write-Host "Error: No se encontró el archivo de configuración en $configFile"
            return
        }

        # Configurar el puerto en server.xml
        Write-Host "Configurando Tomcat para el puerto $global:puerto..."
        (Get-Content $configFile) -replace 'Connector port="8080"', "Connector port=`"$global:puerto`"" | Set-Content $configFile
        Write-Host "Configuración de Tomcat actualizada con puerto $global:puerto"

        # Registrar Tomcat como servicio correctamente
        $tomcatService = "$extraerDestino\bin\service.bat"
        if (Test-Path $tomcatService) {
            Write-Host "Registrando Tomcat como servicio..."
            Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tomcatService`" install" -WorkingDirectory "$extraerDestino\bin" -NoNewWindow -Wait

            # Verificar que el servicio se instaló
            $tomcatServiceName = "Tomcat$majorVersion"
            $serviceExists = Get-Service -Name $tomcatServiceName -ErrorAction SilentlyContinue

            if ($serviceExists) {
                Write-Host "Servicio $tomcatServiceName instalado correctamente."

                # Iniciar el servicio de Tomcat
                Write-Host "Iniciando servicio de Tomcat..."
                Start-Service -Name $tomcatServiceName -ErrorAction SilentlyContinue

                # Esperar unos segundos y verificar si está corriendo
                Start-Sleep -Seconds 5
                $serviceStatus = Get-Service -Name $tomcatServiceName
                if ($serviceStatus.Status -eq "Running") {
                    Write-Host "Tomcat está corriendo en el puerto $global:puerto."
                } else {
                    Write-Host "Error: El servicio $tomcatServiceName no se inició correctamente."
                }

                # Habilitar el puerto en el firewall
                habilitar_puerto_firewall
            } else {
                Write-Host "Error: No se pudo registrar el servicio de Tomcat."
            }
        } else {
            Write-Host "Error: No se encontró el archivo service.bat en $extraerDestino\bin"
        }
    } catch {
        Write-Host "Error durante la instalación de Tomcat: $_"
    }
}