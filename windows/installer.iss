#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{3B1E9C82-9F07-4928-8D74-1958377FA55E}
AppName=Cockpit
AppVersion={#AppVersion}
AppVerName=Cockpit {#AppVersion}
AppPublisher=samy-1603
AppPublisherURL=https://github.com/samy-1603/streak
AppSupportURL=https://github.com/samy-1603/streak/issues
AppUpdatesURL=https://github.com/samy-1603/streak/releases
DefaultDirName={autopf}\Cockpit
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=Cockpit-windows-x64-setup
SetupIconFile=runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Cockpit.exe
UninstallDisplayName=Cockpit
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "ukrainian"; MessagesFile: "compiler:Languages\Ukrainian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Cockpit"; Filename: "{app}\Cockpit.exe"; AppUserModelID: "io.github.samy1603.cockpit"
Name: "{autodesktop}\Cockpit"; Filename: "{app}\Cockpit.exe"; Tasks: desktopicon; AppUserModelID: "io.github.samy1603.cockpit"

[Run]
Filename: "{app}\Cockpit.exe"; Description: "{cm:LaunchProgram,Cockpit}"; Flags: nowait postinstall skipifsilent
