function Log-Exito { param([string]$texto); Write-Host "[OK] $texto" -ForegroundColor Green }
function Log-Error { param([string]$texto); Write-Host "[ERROR] $texto" -ForegroundColor Red }
function Log-Aviso { param([string]$texto); Write-Host "[INFO] $texto" -ForegroundColor Cyan }

function Verificar-Admin {
    $identidad = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidad)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Log-Error "Ocupas correr PowerShell como ADMINISTRADOR."
        Start-Sleep -Seconds 5; exit
    }
}

function Pedir-Entero {
    param ([string]$Mensaje)
    while ($true) {
        $num = Read-Host "$Mensaje"
        if ([string]::IsNullOrWhiteSpace($num)) { Log-Error "No puede estar vacio."; continue }
        if ($num -match '^\d+$') {
            $valor = [int]$num
            if ($valor -gt 0) { return $valor } else { Log-Error "Debe ser mayor a 0." }
        } else { Log-Error "Solo numeros enteros positivos." }
    }
}

function Obtener-Mascara-Desde-Prefijo {
    param ([int]$Prefijo)
    switch ($Prefijo) {
        8  { return "255.0.0.0" }
        16 { return "255.255.0.0" }
        24 { return "255.255.255.0" }
        Default { 
            $mascara = [uint32]::MaxValue -shl (32 - $Prefijo)
            $bytes = [BitConverter]::GetBytes([uint32][IPAddress]::HostToNetworkOrder($mascara))
            return (($bytes | ForEach-Object { $_ }) -join ".")
        }
    }
}

function Pedir-IP-Segura {
    param ([string]$Mensaje, [string]$EsOpcional = "no")
    while ($true) {
        $entrada = (Read-Host "$Mensaje").Trim()
        if ($EsOpcional -eq "si" -and $entrada -eq "") { return "" }
        if ($entrada -eq "") { Log-Error "No lo dejes vacio."; continue }

        if ($entrada -match '^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') {
            if ($entrada -eq "0.0.0.0" -or $entrada -eq "127.0.0.1" -or $entrada -eq "255.255.255.255") { 
                Log-Error "IP $entrada NO permitida." 
            } else { return $entrada }
        } else { Log-Error "Formato incorrecto. Usa X.X.X.X" }
    }
}