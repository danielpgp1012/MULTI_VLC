[Setup]
AppName=Multi VLC Manager
AppVersion=1.0
AppVerName=Multi VLC Manager - Gestor de Reproducción Multimedia
AppPublisher=Daniel Pacheco
AppPublisherURL=github.com/danielpgp1012
DefaultDirName={pf}\MultiVLCManager
OutputBaseFilename=MultiVLCManagerSetup
Compression=lzma
SolidCompression=yes
UninstallDisplayIcon={app}\Multi_vlc.exe
CreateUninstallRegKey=yes
SetupIconFile=C:\Users\animi\Documents\DANIEL\MULTI_VLC\assets\multi_vlc_icon.ico

[Files]
; Archivo principal de la aplicación
Source: "C:\Users\animi\Documents\DANIEL\MULTI_VLC\Multi_vlc.exe"; DestDir: "{app}"; Flags: ignoreversion
; Archivo del ícono personalizado
Source: "C:\Users\animi\Documents\DANIEL\MULTI_VLC\assets\multi_vlc_icon.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Accesos directos con icono personalizado
Name: "{commondesktop}\Multi VLC Manager"; Filename: "{app}\Multi_vlc.exe"; IconFilename: "{app}\multi_vlc_icon.ico"
Name: "{group}\Multi VLC Manager"; Filename: "{app}\Multi_vlc.exe"; IconFilename: "{app}\multi_vlc_icon.ico"
Name: "{group}\Desinstalar Multi VLC Manager"; Filename: "{uninstallexe}"; IconFilename: "{uninstallexe}"

[Run]
; Ejecutar la aplicación después de la instalación
Filename: "{app}\Multi_vlc.exe"; Description: "Ejecutar Multi VLC Manager"; Flags: postinstall nowait

[UninstallDelete]
; Eliminar todos los archivos en la carpeta de instalación
Type: files; Name: "{app}\*.*"
; Eliminar la carpeta si está vacía
Type: dirifempty; Name: "{app}"

