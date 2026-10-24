; Vidya for Windows: Inno Setup script. The release workflow builds the app
; (flutter build windows) and compiles this with
;   iscc /DAppVersion=0.1.0 windows\installer\vidya.iss
; Installs for the current user by default (no admin prompt). Uninstalling
; leaves the encrypted data in %APPDATA%\Vidya alone.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#define Release "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{55825A17-B296-4ED6-A66E-84FB1F5A100C}
AppName=Vidya
AppVersion={#AppVersion}
AppVerName=Vidya {#AppVersion}
AppPublisher=Rajeev Sudharamachandran
DefaultDirName={autopf}\Vidya
DefaultGroupName=Vidya
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer
OutputBaseFilename=Vidya-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\vidya.exe
UninstallDisplayName=Vidya
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
Name: "{autoprograms}\Vidya"; Filename: "{app}\vidya.exe"; Comment: "Personal finance"
Name: "{autodesktop}\Vidya"; Filename: "{app}\vidya.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\vidya.exe"; Description: "{cm:LaunchProgram,Vidya}"; Flags: nowait postinstall skipifsilent
