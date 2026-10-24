; Anveshana for Windows: Inno Setup script. The release workflow builds the app
; (flutter build windows) and compiles this with
;   iscc /DAppVersion=0.1.0 windows\installer\anveshana.iss
; Installs for the current user by default (no admin prompt). Uninstalling
; leaves the encrypted data in %APPDATA%\Anveshana alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{55825A17-B296-4ED6-A66E-84FB1F5A100C}
AppName=Anveshana
AppVersion={#AppVersion}
AppVerName=Anveshana {#AppVersion}
AppPublisher=Rajeev Sudharamachandran
DefaultDirName={autopf}\Anveshana
DefaultGroupName=Anveshana
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Anveshana-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\anveshana.exe
UninstallDisplayName=Anveshana
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
Name: "{autoprograms}\Anveshana"; Filename: "{app}\anveshana.exe"; Comment: "Personal finance"
Name: "{autodesktop}\Anveshana"; Filename: "{app}\anveshana.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\anveshana.exe"; Description: "{cm:LaunchProgram,Anveshana}"; Flags: nowait postinstall skipifsilent
