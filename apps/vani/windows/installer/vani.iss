; Vani for Windows: Inno Setup script. The release workflow builds the app
; (flutter build windows) and compiles this with
;   iscc /DAppVersion=0.1.0 windows\installer\vani.iss
; Installs for the current user by default (no admin prompt). Uninstalling
; leaves the encrypted data in %APPDATA%\Vani alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{6AB2670E-49A5-4703-851F-808B3C52B347}
AppName=Vani
AppVersion={#AppVersion}
AppVerName=Vani {#AppVersion}
AppPublisher=Rajeev Sudharamachandran
DefaultDirName={autopf}\Vani
DefaultGroupName=Vani
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Vani-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\vani.exe
UninstallDisplayName=Vani
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
CloseApplications=yes
; Windows 10 1809 or later (and Windows 11)
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#Release}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Vani"; Filename: "{app}\vani.exe"; Comment: "Social media manager"
Name: "{autodesktop}\Vani"; Filename: "{app}\vani.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\vani.exe"; Description: "{cm:LaunchProgram,Vani}"; Flags: nowait postinstall skipifsilent
