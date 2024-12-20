# Añadir ensamblados necesarios para Windows Forms y Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Función para obtener la ruta de VLC dinámicamente
function Get-VLCPath {
    $VLCKey64 = "HKLM:\SOFTWARE\VideoLAN\VLC"
    $VLCKey32 = "HKLM:\SOFTWARE\WOW6432Node\VideoLAN\VLC"

    if (Test-Path $VLCKey64) {
        $VLCPath = (Get-ItemProperty -Path $VLCKey64).InstallDir
    } elseif (Test-Path $VLCKey32) {
        $VLCPath = (Get-ItemProperty -Path $VLCKey32).InstallDir
    } else {
        # Buscar en rutas comunes
        $commonPaths = @(
            "C:\Program Files\VideoLAN\VLC",
            "C:\Program Files (x86)\VideoLAN\VLC"
        )
        foreach ($path in $commonPaths) {
            if (Test-Path (Join-Path -Path $path -ChildPath "vlc.exe")) {
                return $path
            }
        }

        # Si no se encuentra VLC, mostrar popup y redirigir a la descarga
        [System.Windows.Forms.MessageBox]::Show(
            "No se encontró VLC Media Player. Por favor, instálelo desde el sitio oficial.",
            "VLC No Encontrado",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        Start-Process "https://www.videolan.org/vlc/index.html"
        return $null
    }

    return $VLCPath
}

# Función para abrir 3 instancias de VLC
function AbrirVentanasVLC {
    $VLCPath = Get-VLCPath
    if (-not $VLCPath) { return } # Si VLC no está, salir.

    # Abrir el explorador de archivos para seleccionar un archivo de video
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = (Get-Location)
    $OpenFileDialog.Filter = "Archivos de Video (*.mp4, *.mkv, *.avi)|*.mp4;*.mkv;*.avi"
    $result = $OpenFileDialog.ShowDialog()

    if ($result -eq 'OK') {
        $VideoFilePath = $OpenFileDialog.FileName
        for ($i = 1; $i -le 3; $i++) {
            $port = 8080 + $i - 1
            $VLCExecutable = Join-Path -Path $VLCPath -ChildPath "vlc.exe"
            Start-Process $VLCExecutable -ArgumentList "--no-one-instance --no-playlist-enqueue --intf qt --start-paused --extraintf http --http-port=$port --http-password=admin `"$VideoFilePath`"" -PassThru
            Start-Sleep -Seconds 0.2
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "No se seleccionó ningún archivo de video. Operación cancelada.",
            "Archivo no seleccionado",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
}

# Función para reproducir los videos
function ReproducirVideos {
    for ($i = 1; $i -le 3; $i++) {
        $port = 8080 + $i - 1
        $uri = "http://localhost:$port/requests/status.xml?command=pl_play"

        $pair = ":admin"
        $encodedCredentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))

        $headers = @{
            Authorization = "Basic $encodedCredentials"
        }
        try {
            Invoke-WebRequest -Uri $uri -Headers $headers -Method Get
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Error al conectar con VLC en el puerto $port. Asegúrese de que VLC esté abierto.",
                "Error de Conexión",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
}

# Crear un formulario
$form = New-Object System.Windows.Forms.Form
$form.Text = "Multi VLC Manager"
$form.Size = New-Object System.Drawing.Size(300, 150)
$form.StartPosition = "CenterScreen"

# Botón para abrir ventanas de VLC
$buttonOpen = New-Object System.Windows.Forms.Button
$buttonOpen.Location = New-Object System.Drawing.Point(30, 20)
$buttonOpen.Size = New-Object System.Drawing.Size(120, 30)
$buttonOpen.Text = "Abrir Ventanas VLC"
$buttonOpen.Add_Click({ AbrirVentanasVLC })
$form.Controls.Add($buttonOpen)

# Botón para reproducir videos
$buttonPlay = New-Object System.Windows.Forms.Button
$buttonPlay.Location = New-Object System.Drawing.Point(160, 20)
$buttonPlay.Size = New-Object System.Drawing.Size(120, 30)
$buttonPlay.Text = "Reproducir Videos"
$buttonPlay.Add_Click({ ReproducirVideos })
$form.Controls.Add($buttonPlay)

# Mostrar el formulario
$form.ShowDialog()
