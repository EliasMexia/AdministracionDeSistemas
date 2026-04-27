
Clear-Host

Write-Host "Check status (Practica 1)"
Write-Host ""

Write-Host "NOMBRE DEL EQUIPO (HOSTNAME):"
hostname

Write-Host ""
Write-Host "DIRECCION IP ACTUAL:"
# Usamos ipconfig enfocandonos en la linea IPv4 para que asi no nos de toda la
#informacion innecesaria si no solo nuestras IPv4 la de los 2 adaptadores
ipconfig | Select-String "IPv4"

Write-Host ""
Write-Host " ESPACIO EN DISCO (Raiz C:\):"
#Batalle un poco(un mucho) porque me daba el almacenamiento con informacion inecesaria
#ademas de que me la daba en bytes por lo cual implemente variables para usar operaciones
#logrando asi hacer más amigable a la vista la salida del script
$DiscoC = Get-PSDrive C
$used = [float] ($DiscoC.Used/1GB)
$free = [float] ($DiscoC.Free/1GB)
Write-Host "Espacio en uso $used GB"
Write-Host "Espacio disponible $free GB"
Write-Host ""

