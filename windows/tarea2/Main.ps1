<#
 Practica: Servidor DHCP en Windows Server
 Materia: Administracion de Redes
 Descripcion: Script para instalar y configurar DHCP con menu
#>

# ---------------------------------------------------
# 1. MIS FUNCIONES PARA MENSAJES Y VALIDACIONES
# ---------------------------------------------------

function Log-Exito {
    param([string]$texto)
    Write-Host "[OK] $texto" -ForegroundColor Green
}

function Log-Error {
    param([string]$texto)
    Write-Host "[ERROR] $texto" -ForegroundColor Red
}

function Log-Aviso {
    param([string]$texto)
    Write-Host "[INFO] $texto" -ForegroundColor Cyan
}

# Reviso si tengo permisos de admin, si no, me saco del script
function Verificar-Admin {
    $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidad)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log-Error "Ocupas correr esto como Administrador para que jale."
        Start-Sleep -Seconds 5
        exit
    }
}

# Funcion para asegurar que el usuario solo meta numeros enteros positivos
function Pedir-Entero {
    param ([string]$Mensaje)
    while ($true) {
        $num = Read-Host "$Mensaje"
        
        # 1. Validar que no esté vacío
        if ([string]::IsNullOrWhiteSpace($num)) {
            Log-Error "El campo no puede estar vacio."
            continue
        }

        # 2. Validar que sean solo dígitos (evita signos - y +)
        if ($num -match '^\d+$') {
            $valor = [int]$num
            # 3. Validar que sea mayor a 0
            if ($valor -gt 0) {
                return $valor
            } else {
                Log-Error "El tiempo debe ser mayor a 0."
            }
        } else {
            Log-Error "Entrada invalida. Solo pon numeros enteros positivos (sin signos)."
        }
    }
}
# Aqui convierto el prefijo (ej. 24) a la mascara completa (ej. 255.255.255.0)
function Obtener-Mascara-Desde-Prefijo {
    param ([int]$Prefijo)
    
    switch ($Prefijo) {
        8  { return "255.0.0.0" }
        16 { return "255.255.0.0" }
        24 { return "255.255.255.0" }
        Default { 
            # Calculo matematico por si meten un prefijo raro
            $mascara = [uint32]::MaxValue -shl (32 - $Prefijo)
            $bytes = [BitConverter]::GetBytes([uint32][IPAddress]::HostToNetworkOrder($mascara))
            return (($bytes | ForEach-Object { $_ }) -join ".")
        }
    }
}

# Funcion principal para pedir IPs y validar que no sean las prohibidas
function Pedir-IP-Segura {
    param (
        [string]$Mensaje,
        [string]$EsOpcional = "no"
    )

    while ($true) {
        $entrada = Read-Host "$Mensaje"
        $entrada = $entrada.Trim() # Le quito los espacios

        # Si es opcional y le dan enter, retorno vacio
        if ($EsOpcional -eq "si" -and $entrada -eq "") { return "" }

        if ($entrada -eq "") {
            Log-Error "No lo dejes vacio."
            continue
        }

        # Checo que tenga formato de IP correcto
        if ($entrada -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
            # Aqui valido las IPs que dijo el profe que no usaramos
            if ($entrada -eq "0.0.0.0" -or $entrada -eq "127.0.0.1" -or $entrada -eq "255.255.255.255") { 
                Log-Error "Esa IP no se puede usar ($entrada)." 
            } else { return $entrada }
        } else {
            Log-Error "Formato incorrecto. Pon bien la IP (0-255)."
        }
    }
}

# ---------------------------------------------------
# 2. FUNCIONES DEL MENU
# ---------------------------------------------------

function Instalar-Rol-DHCP {
    Log-Aviso "Checando si ya tienes el DHCP..."
    $estado = Get-WindowsFeature -Name DHCP
    
    if ($estado.Installed) {
        Log-Exito "Ya estaba instalado."
    }
    else {
        Log-Aviso "Instalando el Rol DHCP, aguanta tantito..."
        try {
            Install-WindowsFeature DHCP -IncludeManagementTools -ErrorAction Stop
            Log-Exito "Listo, se instalo."
        }
        catch {
            Log-Error "Hubo bronca al instalar: $_"
        }
    }
    Read-Host "Dale Enter para seguir..."
}

function Configurar-Todo-Scope {
    Log-Aviso "--- VAMOS A CONFIGURAR LA RED Y EL SCOPE ---"

    Write-Host "Tus tarjetas de red:" -ForegroundColor Gray
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status | Format-Table -AutoSize
    Write-Host "------------------------------------------------" -ForegroundColor Gray
    
    # Si le dan enter agarra Ethernet 2 por defecto
    $InputInterfaz = Read-Host "Nombre del adaptador [Default: Ethernet 2]"
    if ($InputInterfaz -eq "") { $NombreInterfaz = "Ethernet 2" } else { $NombreInterfaz = $InputInterfaz }
    
    # Valido que la tarjeta exista
    if (-not (Get-NetAdapter -Name $NombreInterfaz -ErrorAction SilentlyContinue)) {
        Log-Error "No encuentro esa tarjeta '$NombreInterfaz'. Checa el nombre."
        Read-Host "Enter para volver..."
        return
    }

    Write-Host "`n--- DATOS DE LA RED ---" -ForegroundColor Yellow
    
    # Pido la IP inicial
    $RangoInicio = Pedir-IP-Segura "1. IP Inicio Rango (Server IP)" "no"
    
    # Ciclo para asegurar que la IP final sea mayor a la inicial
    while ($true) {
        $RangoFin = Pedir-IP-Segura "2. IP Fin Rango" "no"
        
        # Las convierto a version para comparar facil cual es mayor
        $ip1 = [Version]$RangoInicio
        $ip2 = [Version]$RangoFin
        
        if ($ip2 -gt $ip1) {
            break # Todo bien, salimos
        } else {
            Log-Error "La IP Final tiene que ser mas grande que la Inicial ($RangoInicio)."
        }
    }

    # Pido el prefijo para sacar la mascara
    while ($true) {
        $Prefijo = Read-Host "3. Prefijo de Red (24, 16, 8) [Default: 24]"
        if ($Prefijo -eq "") { $Prefijo = 24 }
        # Valido que sea un numero razonable
        if ($Prefijo -match '^\d+$' -and [int]$Prefijo -ge 8 -and [int]$Prefijo -le 30) {
            $Prefijo = [int]$Prefijo
            break
        } else { Log-Error "Prefijo invalido. Usa un numero entre 8 y 30." }
    }

    $Gateway     = Pedir-IP-Segura "4. Gateway (Enter si no tiene)" "si"
    $DnsServer   = Pedir-IP-Segura "5. DNS (Enter si no tiene)" "si"
    
    $NombreScope = Read-Host "6. Nombre del Scope (ej. RedInterna)"
    if ($NombreScope -eq "") { $NombreScope = "RedInterna" }
    
   # Valido que el tiempo sea entero y positivo al instante
    $TiempoLease = Pedir-Entero "7. Tiempo Lease en segundos (ej. 600)"

    # El script no pasará de aquí hasta que $TiempoLease sea un entero válido.
    # Los cálculos posteriores como el New-TimeSpan ya no fallarán.
    $TiempoSpan = New-TimeSpan -Seconds $TiempoLease

    # --- HAGO LOS CALCULOS ---
    $IpServidor = $RangoInicio
    $Mascara = Obtener-Mascara-Desde-Prefijo $Prefijo

    # Saco la IP donde empieza el DHCP (Server + 1)
    $partes = $IpServidor.Split(".") 
    $octeto4 = [int]$partes[3] + 1
    $DhcpInicioIP = "$($partes[0]).$($partes[1]).$($partes[2]).$octeto4"

    # Calculo el ID de Red usando operaciones binarias con la mascara
    $ipBytes = [System.Net.IPAddress]::Parse($IpServidor).GetAddressBytes()
    $maskBytes = [System.Net.IPAddress]::Parse($Mascara).GetAddressBytes()
    $netBytes = New-Object byte[] 4
    for ($i=0; $i -lt 4; $i++) { $netBytes[$i] = $ipBytes[$i] -band $maskBytes[$i] }
    $RedID = [System.Net.IPAddress]::new($netBytes).IPAddressToString

    Log-Aviso "Calculando todo..."
    Write-Host " -> Servidor IP: $IpServidor"
    Write-Host " -> Prefijo:     /$Prefijo ($Mascara)"
    Write-Host " -> Red ID:      $RedID"
    Write-Host " -> Rango DHCP:  $DhcpInicioIP hasta $RangoFin"

    # Configuro la IP Estatica en la tarjeta
    Log-Aviso "Poniendo la IP Estatica en '$NombreInterfaz'..."
    try {
        # Limpio configuraciones viejas
        Remove-NetIPAddress -InterfaceAlias $NombreInterfaz -Confirm:$false -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceAlias $NombreInterfaz -ResetServerAddresses -ErrorAction SilentlyContinue

        if ($Gateway -eq "") {
            New-NetIPAddress -InterfaceAlias $NombreInterfaz -IPAddress $IpServidor -PrefixLength $Prefijo -AddressFamily IPv4 -ErrorAction Stop | Out-Null
        }
        else {
            New-NetIPAddress -InterfaceAlias $NombreInterfaz -IPAddress $IpServidor -PrefixLength $Prefijo -DefaultGateway $Gateway -AddressFamily IPv4 -ErrorAction Stop | Out-Null
        }
        Log-Exito "Ya quedo la IP fija."
    }
    catch {
        Log-Error "Fallo al poner la IP: $_"
        Read-Host "Enter para volver..."
        return
    }

    # Ahora si configuro el servicio DHCP
    Log-Aviso "Configurando el DHCP..."
    Restart-Service DhcpServer -Force

    # Si el Scope ya existe lo borro para crearlo de nuevo
    if (Get-DhcpServerv4Scope -ScopeId $RedID -ErrorAction SilentlyContinue) {
        Remove-DhcpServerv4Scope -ScopeId $RedID -Force
    }

    try {
        # Creo el scope nuevo
        Add-DhcpServerv4Scope -Name $NombreScope -StartRange $DhcpInicioIP -EndRange $RangoFin -SubnetMask $Mascara -State Active -ErrorAction Stop
        Log-Exito "Scope creado."

        if ($Gateway -ne "") {
            Set-DhcpServerv4OptionValue -ScopeId $RedID -OptionId 3 -Value $Gateway
            Log-Exito "Gateway agregado."
        }

        if ($DnsServer -ne "") {
            try {
                Set-DhcpServerv4OptionValue -ScopeId $RedID -OptionId 6 -Value $DnsServer -ErrorAction Stop
                Log-Exito "DNS agregado."
            }
            catch {
                Write-Host "[AVISO] El DNS no responde, pero igual lo forzamos..." -ForegroundColor Yellow
                try {
                    Set-DhcpServerv4OptionValue -ScopeId $RedID -OptionId 6 -Value $DnsServer -ErrorAction SilentlyContinue
                } catch { Log-Error "No se pudo poner el DNS." }
            }
        }
        
        $TiempoSpan = New-TimeSpan -Seconds $TiempoLease
        Set-DhcpServerv4Scope -ScopeId $RedID -LeaseDuration $TiempoSpan

        Restart-Service DhcpServer -Force
        Log-Exito "Configuracion terminada al 100."

    }
    catch {
        Log-Error "Error al crear el Scope: $_"
        Log-Error "Checa que el Rango IP coincida con la Mascara ($Mascara)"
    }
    
    Read-Host "Dale Enter..."
}

function Monitorear-Clientes {
    Log-Aviso "CLIENTES CONECTADOS"
    try {
        # Busco leases en todos los scopes
        $clientes = Get-DhcpServerv4Lease -ScopeId 0.0.0.0 -ErrorAction SilentlyContinue
        if ($clientes) {
            $clientes | Select-Object IPAddress, ClientId, HostName, LeaseExpiryTime | Format-Table -AutoSize
        } else {
            Write-Host "Nadie conectado todavia." -ForegroundColor Yellow
        }
    }
    catch {
        Log-Error "No pude leer los datos (¿Esta prendido el DHCP?)."
    }
    Read-Host "Dale Enter..."
}

function Verificar-Estado-Servicio {
    Log-Aviso "ESTADO DEL SERVICIO"
    $feature = Get-WindowsFeature DHCP
    
    if ($feature.Installed -eq $false) {
        Log-Error "El DHCP NO esta instalado."
    }
    else {
        try {
            $servicio = Get-Service -Name DhcpServer -ErrorAction Stop
            $servicio | Select-Object Name, Status, StartType | Format-List
            
            # Checo si esta pendiente de borrar
            if ($feature.InstallState -eq "UninstallRequested" -or $feature.InstallState -eq "Removed") {
                Write-Host "OJO: Falta reiniciar para que se termine de borrar." -ForegroundColor Red
            }
        }
        catch { Log-Error "El servicio no existe." }
    }
    Read-Host "Dale Enter..."
}

function Desinstalar-Todo {
    Write-Host "SEGURO QUE QUIERES BORRAR EL DHCP? (s/n)" -ForegroundColor Red
    $resp = Read-Host "Respuesta"
    if ($resp -eq "s") {
        Log-Aviso "Desinstalando..."
        $res = Uninstall-WindowsFeature DHCP -IncludeManagementTools
        if ($res.RestartNeeded -eq "Yes" -or $res.RestartNeeded -eq $true) {
            Log-Exito "Listo. REINICIA EL SERVER AHORA."
        } else { Log-Exito "Desinstalado." }
    }
    Read-Host "Dale Enter..."
}

# ---------------------------------------------------
# 3. MENU PRINCIPAL
# ---------------------------------------------------

Verificar-Admin

while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   MI SERVIDOR DHCP (Windows)  " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "1. Instalar Servidor"
    Write-Host "2. Configurar Scope (IP Fija + DHCP)"
    Write-Host "3. Ver clientes conectados"
    Write-Host "4. Checar estado del servicio"
    Write-Host "5. Desinstalar todo"
    Write-Host "6. Salir"
    Write-Host "========================================" -ForegroundColor Cyan
    
    $Opcion = Read-Host "Elige una opcion"
    $Opcion = $Opcion.Trim()

    switch ($Opcion) {
        "1" { Instalar-Rol-DHCP }
        "2" { Configurar-Todo-Scope }
        "3" { Monitorear-Clientes }
        "4" { Verificar-Estado-Servicio }
        "5" { Desinstalar-Todo }
        "6" { exit }
        Default { Log-Error "Opcion no valida."; Start-Sleep -Seconds 1 }
    }
}