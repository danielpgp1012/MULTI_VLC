# Añadir ensamblados necesarios para Windows Forms, Drawing y HTTP
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Net.Http

# Configuración
$PuertoBase = 8080          # La ventana 1 usa 8080, la 2 usa 8081, etc.
$HttpPassword = "admin"     # Contraseña de la interfaz HTTP local de VLC
$VentanasPorDefecto = 3
$VentanasMaximo = 8

# Ventanas de VLC abiertas por esta aplicación (proceso + puerto)
$script:Instancias = @()

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
        ) | Out-Null
        Start-Process "https://www.videolan.org/vlc/index.html"
        return $null
    }

    return $VLCPath
}

# Devuelve las ventanas abiertas por esta aplicación que siguen en ejecución
function Get-InstanciasActivas {
    return @($script:Instancias | Where-Object { -not $_.Proceso.HasExited })
}

# Función para abrir N instancias de VLC
function AbrirVentanasVLC {
    param([int]$Cantidad)

    $VLCPath = Get-VLCPath
    if (-not $VLCPath) { return } # Si VLC no está, salir.

    # Si quedan ventanas abiertas de antes, sus puertos chocarían con las nuevas
    $activas = Get-InstanciasActivas
    if ($activas.Count -gt 0) {
        $respuesta = [System.Windows.Forms.MessageBox]::Show(
            "Hay $($activas.Count) ventana(s) de VLC abiertas. ¿Cerrarlas y abrir $Cantidad nuevas?",
            "Ventanas ya abiertas",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        if ($respuesta -ne 'Yes') { return }
        foreach ($instancia in $activas) {
            try { $instancia.Proceso.Kill() } catch { }
        }
        Start-Sleep -Milliseconds 500 # Dar tiempo a VLC para liberar los puertos
    }
    $script:Instancias = @()

    # Abrir el explorador de archivos para seleccionar un archivo de video
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.InitialDirectory = (Get-Location)
    $OpenFileDialog.Filter = "Archivos de Video (*.mp4, *.mkv, *.avi)|*.mp4;*.mkv;*.avi"
    $result = $OpenFileDialog.ShowDialog()

    if ($result -eq 'OK') {
        $VideoFilePath = $OpenFileDialog.FileName
        $VLCExecutable = Join-Path -Path $VLCPath -ChildPath "vlc.exe"
        for ($i = 0; $i -lt $Cantidad; $i++) {
            $port = $PuertoBase + $i
            $proceso = Start-Process $VLCExecutable -ArgumentList "--no-one-instance --no-playlist-enqueue --intf qt --start-paused --extraintf http --http-port=$port --http-password=$HttpPassword `"$VideoFilePath`"" -PassThru
            $script:Instancias += [pscustomobject]@{ Proceso = $proceso; Puerto = $port }
            Start-Sleep -Milliseconds 200
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "No se seleccionó ningún archivo de video. Operación cancelada.",
            "Archivo no seleccionado",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
}

# Envía la misma petición a todas las ventanas a la vez y devuelve los puertos que fallaron.
# Todas las peticiones salen antes de esperar ninguna respuesta, así ninguna ventana
# espera a que la anterior conteste.
function Invoke-ComandoVLC {
    param([int[]]$Puertos, [string]$Consulta)

    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.UseProxy = $false # La detección automática de proxy añade retrasos
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(3)
    $encodedCredentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$HttpPassword"))
    $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Basic", $encodedCredentials)

    $tareas = @{}
    foreach ($port in $Puertos) {
        $tareas[$port] = $client.GetAsync("http://localhost:$port/requests/status.xml$Consulta")
    }

    $fallidos = @()
    foreach ($port in $Puertos) {
        try {
            $respuesta = $tareas[$port].GetAwaiter().GetResult()
            if (-not $respuesta.IsSuccessStatusCode) { $fallidos += $port }
        } catch {
            $fallidos += $port
        }
    }
    $client.Dispose()
    return $fallidos
}

# Función para reproducir los videos
function ReproducirVideos {
    param([int]$CantidadPorDefecto)

    $puertos = @(Get-InstanciasActivas | ForEach-Object { $_.Puerto })
    if ($puertos.Count -eq 0) {
        # Ventanas abiertas en una sesión anterior de la aplicación: usar el número elegido
        $puertos = @(0..($CantidadPorDefecto - 1) | ForEach-Object { $PuertoBase + $_ })
    }

    # Primero comprobar qué ventanas responden, para que el "play" llegue a todas a la vez
    $sinRespuesta = @(Invoke-ComandoVLC -Puertos $puertos -Consulta "")
    $disponibles = @($puertos | Where-Object { $sinRespuesta -notcontains $_ })

    if ($disponibles.Count -gt 0) {
        $sinRespuesta += @(Invoke-ComandoVLC -Puertos $disponibles -Consulta "?command=pl_play")
    }

    if ($sinRespuesta.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Error al conectar con VLC en el/los puerto(s) $($sinRespuesta -join ', '). Asegúrese de que VLC esté abierto.",
            "Error de Conexión",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

# Crear un formulario
$form = New-Object System.Windows.Forms.Form
$form.Text = "Multi VLC Manager"
$form.Size = New-Object System.Drawing.Size(320, 150)
$form.StartPosition = "CenterScreen"

# Selector del número de ventanas
$labelCantidad = New-Object System.Windows.Forms.Label
$labelCantidad.Location = New-Object System.Drawing.Point(30, 22)
$labelCantidad.Size = New-Object System.Drawing.Size(130, 20)
$labelCantidad.Text = "Número de ventanas:"
$form.Controls.Add($labelCantidad)

$numCantidad = New-Object System.Windows.Forms.NumericUpDown
$numCantidad.Location = New-Object System.Drawing.Point(160, 20)
$numCantidad.Size = New-Object System.Drawing.Size(60, 20)
$numCantidad.Minimum = 1
$numCantidad.Maximum = $VentanasMaximo
$numCantidad.Value = $VentanasPorDefecto
$form.Controls.Add($numCantidad)

# Botón para abrir ventanas de VLC
$buttonOpen = New-Object System.Windows.Forms.Button
$buttonOpen.Location = New-Object System.Drawing.Point(30, 55)
$buttonOpen.Size = New-Object System.Drawing.Size(120, 30)
$buttonOpen.Text = "Abrir Ventanas VLC"
$buttonOpen.Add_Click({ AbrirVentanasVLC -Cantidad ([int]$numCantidad.Value) })
$form.Controls.Add($buttonOpen)

# Botón para reproducir videos
$buttonPlay = New-Object System.Windows.Forms.Button
$buttonPlay.Location = New-Object System.Drawing.Point(160, 55)
$buttonPlay.Size = New-Object System.Drawing.Size(120, 30)
$buttonPlay.Text = "Reproducir Videos"
$buttonPlay.Add_Click({ ReproducirVideos -CantidadPorDefecto ([int]$numCantidad.Value) })
$form.Controls.Add($buttonPlay)

# Mostrar el formulario
[void]$form.ShowDialog()
