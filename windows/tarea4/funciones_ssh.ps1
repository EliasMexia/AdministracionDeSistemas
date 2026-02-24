function Instalar-Servidor-SSH {
    Clear-Host
    Log-Aviso "--- INSTALACION Y CONFIGURACION DE OPENSSH SERVER ---"
    
    $sshStatus = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    
    if ($sshStatus.State -eq 'Installed') {
        Log-Exito "El servidor OpenSSH ya se encuentra instalado."
    } else {
        Log-Aviso "Descargando e instalando OpenSSH Server (puede demorar un poco)..."
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
        Log-Exito "Instalacion completada."
    }

    Log-Aviso "Levantando el servicio sshd..."
    Start-Service sshd -ErrorAction SilentlyContinue
    Set-Service -Name sshd -StartupType 'Automatic'
    
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        Log-Aviso "Abriendo puerto 22 en el Firewall de Windows..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }

    $ipActual = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -notmatch 'Loopback').IPAddress -join ", "
    Log-Exito "Servidor SSH configurado y escuchando en el puerto 22."
    Log-Aviso "Puedes conectarte con: ssh Administrador@$ipActual"
    
    Read-Host "Enter para continuar..."
}