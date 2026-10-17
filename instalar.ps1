# Instala Multi VLC Manager para el usuario actual (no requiere permisos de administrador):
# copia la aplicación a %LOCALAPPDATA%\MultiVLCManager y crea accesos directos en el
# escritorio y en el menú Inicio. Volver a ejecutarlo actualiza la aplicación.
$ErrorActionPreference = 'Stop'

$destino = Join-Path $env:LOCALAPPDATA 'MultiVLCManager'
New-Item -ItemType Directory -Path $destino -Force | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'multi_vlc.ps1') $destino -Force
Copy-Item (Join-Path $PSScriptRoot 'assets\multi_vlc_icon.ico') $destino -Force

# Quitar la marca "descargado de Internet" para que Windows no bloquee la aplicación
Get-ChildItem $destino | Unblock-File

$aplicacion = Join-Path $destino 'multi_vlc.ps1'
$shell = New-Object -ComObject WScript.Shell
$carpetas = @(
    [Environment]::GetFolderPath('Desktop'),
    [Environment]::GetFolderPath('Programs')  # Menú Inicio
)
foreach ($carpeta in $carpetas) {
    $acceso = $shell.CreateShortcut((Join-Path $carpeta 'Multi VLC Manager.lnk'))
    $acceso.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $acceso.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$aplicacion`""
    $acceso.WorkingDirectory = [Environment]::GetFolderPath('MyVideos')
    $acceso.IconLocation = Join-Path $destino 'multi_vlc_icon.ico'
    $acceso.WindowStyle = 7 # Minimizada, para que no se vea la consola al abrir
    $acceso.Save()
}

Write-Host "Multi VLC Manager se instaló en $destino"
Write-Host "Ábralo desde el acceso directo 'Multi VLC Manager' del escritorio."
