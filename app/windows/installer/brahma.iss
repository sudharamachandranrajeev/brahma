; Brahma for Windows: Inno Setup script. The release workflow builds the app
; (flutter build windows) and compiles this with
;   iscc /DAppVersion=0.1.0 windows\installer\brahma.iss
; Installs for the current user by default (no admin prompt). Uninstalling
; leaves the encrypted data in %APPDATA%\Brahma alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{6DAAFB0C-B2A5-440A-92B9-370050674767}
AppName=Brahma
AppVersion={#AppVersion}
AppVerName=Brahma {#AppVersion}
AppPublisher=Rajeev Sudharamachandran
DefaultDirName={autopf}\Brahma
DefaultGroupName=Brahma
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Brahma-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\brahma.exe
UninstallDisplayName=Brahma
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
Name: "{autoprograms}\Brahma"; Filename: "{app}\brahma.exe"; Comment: "Life management: money, property, career, social and learning"
Name: "{autodesktop}\Brahma"; Filename: "{app}\brahma.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\brahma.exe"; Description: "{cm:LaunchProgram,Brahma}"; Flags: nowait postinstall skipifsilent
