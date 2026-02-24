function Instalar-Rol-DHCP {
    Log-Aviso "Verificando DHCP..."
    if ((Get-WindowsFeature DHCP).Installed) { Log-Exito "DHCP ya instalado." }
    else {
        Install-WindowsFeature DHCP -IncludeManagementTools
        Log-Exito "Instalacion completa."
    }
    Read-Host "Enter para continuar..."
}

function Configurar-Todo-Scope {
    Log-Aviso "--- CONFIGURACION DE RED Y SCOPE ---"
    Get-NetAdapter | Select-Object Name, Status | Format-Table -AutoSize
    $NombreInterfaz = Read-Host "Nombre del adaptador [Default: Ethernet 2]"
    if ($NombreInterfaz -eq "") { $NombreInterfaz = "Ethernet 2" }

    $RangoInicio = Pedir-IP-Segura "1. IP Inicio Rango (Server IP)"
    
    while ($true) {
        $RangoFin = Pedir-IP-Segura "2. IP Fin Rango"
        if ([Version]$RangoFin -gt [Version]$RangoInicio) { break }
        else { Log-Error "La IP Final debe ser mayor a $RangoInicio." }
    }

    $Prefijo = Read-Host "3. Prefijo (24, 16, 8) [Default: 24]"
    if ($Prefijo -eq "") { $Prefijo = 24 }
    $Mascara = Obtener-Mascara-Desde-Prefijo ([int]$Prefijo)
    
    $Gateway = Pedir-IP-Segura "4. Gateway (Enter para omitir)" "si"
    $DnsServer = Pedir-IP-Segura "5. DNS"
    
    $NombreScope = Read-Host "6. Nombre del Scope"
    $TiempoLease = Pedir-Entero "7. Tiempo Lease (segundos)"

    Log-Aviso "Configurando IP Estatica..."
    try {
        Remove-NetIPAddress -InterfaceAlias $NombreInterfaz -Confirm:$false -ErrorAction SilentlyContinue
        if ($Gateway) {
            New-NetIPAddress -InterfaceAlias $NombreInterfaz -IPAddress $RangoInicio -PrefixLength $Prefijo -DefaultGateway $Gateway -ErrorAction SilentlyContinue
        } else {
            New-NetIPAddress -InterfaceAlias $NombreInterfaz -IPAddress $RangoInicio -PrefixLength $Prefijo -ErrorAction SilentlyContinue
        }
    } catch { Log-Error "Error en IP fija." }
    
    $partes = $RangoInicio.Split("."); $netID = "$($partes[0]).$($partes[1]).$($partes[2]).0"
    
    if (Get-DhcpServerv4Scope -ScopeId $netID -ErrorAction SilentlyContinue) { 
        Remove-DhcpServerv4Scope -ScopeId $netID -Force 
    }
    
    try {
        Add-DhcpServerv4Scope -Name $NombreScope -StartRange $RangoInicio -EndRange $RangoFin -SubnetMask $Mascara -State Active
        Set-DhcpServerv4Scope -ScopeId $netID -LeaseDuration (New-TimeSpan -Seconds $TiempoLease)
        
        if ($Gateway) { Set-DhcpServerv4OptionValue -ScopeId $netID -OptionId 3 -Value $Gateway }
        
        Log-Aviso "Vinculando Servidor DNS..."
        Set-DhcpServerv4OptionValue -ScopeId $netID -OptionId 6 -Value $DnsServer -Force
        
        Log-Exito "DNS vinculado correctamente."
    } catch {
        Log-Error "Fallo en la configuracion del Scope."
    }

    Restart-Service DhcpServer -Force
    Log-Exito "Configuracion terminada."
    Read-Host "Enter para continuar..."
}

function Monitorear-Clientes {
    Log-Aviso "CLIENTES CONECTADOS"
    Get-DhcpServerv4Lease -ScopeId 0.0.0.0 -ErrorAction SilentlyContinue | Select-Object IPAddress, HostName, LeaseExpiryTime | Format-Table -AutoSize
    Read-Host "Enter para continuar..."
}

function SubMenu-DHCP {
    while ($true) {
        Clear-Host
        Write-Host "--- SUBMENU DHCP ---" -ForegroundColor Yellow
        Write-Host "1. Instalar DHCP`n2. Configurar Scope`n3. Ver clientes`n4. Desinstalar`n5. Volver"
        $op = Read-Host "Opcion"
        switch ($op) {
            "1" { Instalar-Rol-DHCP }
            "2" { Configurar-Todo-Scope }
            "3" { Monitorear-Clientes }
            "4" { Uninstall-WindowsFeature DHCP; Log-Exito "Desinstalado." }
            "5" { return }
        }
    }
}