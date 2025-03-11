function Get-Subnet {
    Read-Host "Introduce la subred"
}

function Get-RangeStart {
    Read-Host "Introduce el rango de inicio de IP"
}

function Get-RangeEnd {
    Read-Host "Introduce el rango final de IP"
}

function Get-Gateway {
    Read-Host "Introduce la puerta de enlace"
}

function Get-DNS {
    Read-Host "Introduce los servidores DNS"
}

function Get-ServerIP {
    Read-Host "Introduce la dirección IP del servidor DHCP"
}

function Configure-Network {
    param ([string]$ip)
    Get-NetIPAddress -InterfaceAlias "Ethernet 2" -AddressFamily IPv4 | Remove-NetIPAddress -Confirm:$false
    New-NetIPAddress -IPAddress $ip -InterfaceAlias "Ethernet 2" -PrefixLength 24
}

function Install-DHCP {
    if (-not (Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue).Installed) {
        Install-WindowsFeature -Name DHCP -IncludeManagementTools
        Write-Host "Rol DHCP instalado." -ForegroundColor Green
    }
}

function Configure-DHCP {
    param ([string]$subred, [string]$rangoInicio, [string]$rangoFinal, [string]$mascara, [string]$gateway, [string]$dns)
    $ScopeName = "Scope_Local"
    $ScopeID = $subred
    
    Add-DhcpServerv4Scope -Name $ScopeName -StartRange $rangoInicio -EndRange $rangoFinal -SubnetMask $mascara -State Active
    Set-DhcpServerv4OptionValue -ScopeId $ScopeID -Router $gateway -DnsServer $dns
}

function Restart-DHCP {
    Restart-Service DHCPServer
    Set-Service DHCPServer -StartupType Automatic
    Write-Host "Estado del servicio DHCP:" -ForegroundColor Green
    Get-Service DHCPServer
}