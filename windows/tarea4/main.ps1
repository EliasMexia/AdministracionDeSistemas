# ==========================================
# PROYECTO INTEGRADOR - GESTOR WINDOWS SERVER
# ==========================================

. .\funciones_core.ps1
. .\funciones_ssh.ps1
. .\funciones_dhcp.ps1
. .\funciones_dns.ps1

Verificar-Admin

function Verificar-Estado-Servicio {
    Clear-Host
    Log-Aviso "--- ESTADO DE LOS SERVICIOS ---"
    $servicios = @("DhcpServer", "DNS", "sshd")
    foreach ($s in $servicios) {
        $status = Get-Service -Name $s -ErrorAction SilentlyContinue
        Write-Host "$s : " -NoNewline
        if ($status -and $status.Status -eq "Running") { Write-Host "[CORRIENDO]" -ForegroundColor Green }
        else { Write-Host "[DETENIDO / NO INSTALADO]" -ForegroundColor Red }
    }
    Read-Host "Enter para continuar..."
}

Clear-Host
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "   SISTEMA DE ADMINISTRACION - WINDOWS SERVER          " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "S) Modo SERVIDOR (Habilitar acceso remoto SSH)"
Write-Host "C) Modo CLIENTE  (Panel de administracion local)"
Write-Host "=======================================================" -ForegroundColor Cyan
$Entorno = Read-Host "Seleccione el entorno [S/C]"

if ($Entorno -eq "S" -or $Entorno -eq "s") {
    Instalar-Servidor-SSH
    exit
} elseif ($Entorno -eq "C" -or $Entorno -eq "c") {
    while ($true) {
        Clear-Host
        Write-Host "--- GESTOR UNIFICADO (WINDOWS SERVER) ---" -ForegroundColor Cyan
        Write-Host "1. Configuracion DHCP"
        Write-Host "2. Configuracion DNS"
        Write-Host "3. Ver Estado de Servicios"
        Write-Host "4. Salir"
        $op = Read-Host "Opcion"
        
        switch ($op) {
            "1" { SubMenu-DHCP }
            "2" { SubMenu-DNS }
            "3" { Verificar-Estado-Servicio }
            "4" { Write-Host "Cerrando..."; Start-Sleep -Seconds 1; exit }
        }
    }
} else {
    Write-Host "Opcion invalida. Saliendo..." -ForegroundColor Red
    Start-Sleep -Seconds 2
}