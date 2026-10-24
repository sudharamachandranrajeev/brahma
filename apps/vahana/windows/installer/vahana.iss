; Vahana for Windows: Inno Setup script. The release workflow builds the app
; (flutter build windows) and compiles this with
;   iscc /DAppVersion=0.1.0 windows\installer\vahana.iss
; Installs for the current user by default (no admin prompt). Uninstalling
; leaves the encrypted data in %APPDATA%\Vahana alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{1BFC6395-2669-4958-84C2-909F48B0B533}
AppName=Vahana Anveshana
AppVersion={#AppVersion}
AppVerName=Vahana Anveshana {#AppVersion}
AppPublisher=Rajeev Sudharamachandran
DefaultDirName={autopf}\Vahana
DefaultGroupName=Vahana Anveshana
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Vahana-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\vahana.exe
UninstallDisplayName=Vahana Anveshana
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
Name: "{autoprograms}\Vahana Anveshana"; Filename: "{app}\vahana.exe"; Comment: "Buying, owning and selling cars"
Name: "{autodesktop}\Vahana Anveshana"; Filename: "{app}\vahana.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\vahana.exe"; Description: "{cm:LaunchProgram,Vahana Anveshana}"; Flags: nowait postinstall skipifsilent
