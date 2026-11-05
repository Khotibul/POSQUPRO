; POSQUPRO Desktop — Inno Setup installer
; Compile: ISCC.exe installer\PosquproDesktop.iss

#define MyAppName "POSQUPRO Desktop"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "POSQUPRO"
#define MyAppURL "https://posqupro.co-id.id"
#define MyAppExeName "PosquproDesktop.exe"
#define MySourceDir "..\src\Posqupro.Desktop\bin\publish"

[Setup]
AppId={{8F3C2A1B-5D4E-4F6A-9B7C-1D2E3F4A5B6C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=.
OutputBaseFilename=POSQUPRO-Desktop-Setup-{#MyAppVersion}
Compression=lzma2/max
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
SetupIconFile=..\src\Posqupro.Desktop\Assets\logo.ico
UninstallFilesDir={autopf}\{#MyAppName}\uninstall

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MySourceDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MySourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.pdb"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
