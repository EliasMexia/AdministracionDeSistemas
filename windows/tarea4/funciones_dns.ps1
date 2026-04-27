function Instalar-DNS {
    Clear-Host
    Log-Aviso "--- INSTALACION DE DNS ---"
    Log-Aviso "Instalando el rol de DNS..."
    Install-WindowsFeature -Name DNS -IncludeManagementTools | Out-Null
    Import-Module DnsServer -ErrorAction SilentlyContinue
    Start-Service DNS -ErrorAction SilentlyContinue
    Log-Exito "DNS Instalado."
    Read-Host "Enter para continuar..."
}

function Agregar-Dominio-DNS {
    Clear-Host
    Log-Aviso "--- AGREGAR DOMINIO ---"
    
    $dominio = Read-Host "Ingresa el nombre del dominio"
    if ([string]::IsNullOrWhiteSpace($dominio)) { return }

    if (Get-DnsServerZone -Name $dominio -ErrorAction SilentlyContinue) { 
        Log-Aviso "El dominio ya existe."
        Read-Host "Enter para continuar..."
        return 
    }

    $ip = Read-Host "Ingresa la IP para este dominio"
    if ([string]::IsNullOrWhiteSpace($ip)) { return }

    Log-Aviso "Creando Zona Directa..."
    Add-DnsServerPrimaryZone -Name $dominio -ZoneFile "$dominio.dns"
    Add-DnsServerResourceRecordA -Name "@" -ZoneName $dominio -IPv4Address $ip
    Add-DnsServerResourceRecordA -Name "ns1" -ZoneName $dominio -IPv4Address $ip
    Add-DnsServerResourceRecordCName -Name "www" -HostNameAlias "$dominio." -ZoneName $dominio

    Log-Aviso "Creando Zona Inversa..."
    $partes = $ip.Split(".")
    if ($partes.Count -eq 4) {
        $redInversa = "$($partes[0]).$($partes[1]).$($partes[2]).0/24"
        $nombreZonaInversa = "$($partes[2]).$($partes[1]).$($partes[0]).in-addr.arpa"
        
        if (-not (Get-DnsServerZone -Name $nombreZonaInversa -ErrorAction SilentlyContinue)) {
            Add-DnsServerPrimaryZone -NetworkId $redInversa -ZoneFile "$nombreZonaInversa.dns" -ErrorAction SilentlyContinue
        }
        
        try {
            Add-DnsServerResourceRecordPtr -Name $partes[3] -ZoneName $nombreZonaInversa -PtrDomainName "$dominio." -ErrorAction Stop
        } catch {
            Log-Aviso "Registro PTR listo."
        }
    }

    Log-Exito "Dominio creado."
    Read-Host "Enter para continuar..."
}

function Eliminar-Dominio-DNS {
    Log-Aviso "--- ELIMINAR DOMINIO ---"
    $zonas = Get-DnsServerZone | Where-Object { $_.IsAutoCreated -eq $false -and $_.ZoneName -ne "TrustAnchors" }
    
    if (-not $zonas) { 
        Log-Aviso "No hay dominios activos."
        Read-Host "Enter para continuar..."
        return 
    }
    
    Log-Aviso "Dominios disponibles:"
    foreach ($z in $zonas) { Write-Host "- $($z.ZoneName)" -ForegroundColor White }
    
    $dominio = Read-Host "`nIngresa el nombre del dominio a eliminar"
    if ($dominio -eq "") { return }

    if (Get-DnsServerZone -Name $dominio -ErrorAction SilentlyContinue) {
        Remove-DnsServerZone -Name $dominio -Force
        Log-Exito "Dominio eliminado."
    } else {
        Log-Error "Ese dominio no existe."
    }
    Read-Host "Enter para continuar..."
}

function Listar-Dominios-DNS {
    Clear-Host
    Log-Aviso "--- DOMINIOS ACTIVOS ---"
    $zonas = Get-DnsServerZone | Where-Object { 
        $_.IsAutoCreated -eq $false -and 
        $_.ZoneName -ne "TrustAnchors" -and 
        $_.ZoneName -notmatch "in-addr.arpa$" 
    }
    
    if (-not $zonas) { 
        Log-Aviso "No hay dominios configurados."
        Read-Host "Enter para continuar..."
        return 
    }

    foreach ($z in $zonas) {
        $record = Get-DnsServerResourceRecord -ZoneName $z.ZoneName -RRType A -ErrorAction SilentlyContinue | Where-Object { $_.HostName -eq "@" } | Select-Object -First 1
        $ip = if ($record) { $record.RecordData.IPv4Address } else { "Sin IP" }
        Write-Host "- Dominio : $($z.ZoneName) -> IP: $ip" -ForegroundColor White
    }
    Read-Host "Enter para continuar..."
}

function SubMenu-DNS {
    while ($true) {
        Clear-Host
        Write-Host "--- SUBMENU DNS ---" -ForegroundColor Green
        Write-Host "1. Instalar DNS`n2. Agregar Dominio`n3. Listar Dominios`n4. Eliminar Dominio`n5. Desinstalar`n6. Volver"
        $op = Read-Host "Opcion"
        switch ($op) {
            "1" { Instalar-DNS }
            "2" { Agregar-Dominio-DNS }
            "3" { Listar-Dominios-DNS }
            "4" { Eliminar-Dominio-DNS }
            "5" { Uninstall-WindowsFeature DNS -Remove; Log-Exito "Desinstalado."; Read-Host "Enter..." }
            "6" { return }
        }
    }
}