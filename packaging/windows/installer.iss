#ifndef AppVersion
  #define AppVersion "0.2"
#endif

#define AppName "CAMS"
#define AppPublisher "NetCamsTeam"
#define AppExeName "CAMS.exe"
#define AppId "{{BD78332E-54CD-4A19-A361-6D0F39FEA566}"

[Setup]
AppId={#AppId}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/viet15t12/CAMS
AppSupportURL=https://github.com/viet15t12/CAMS/issues
AppUpdatesURL=https://github.com/viet15t12/CAMS/releases
DefaultDirName={localappdata}\Programs\CAMS
DefaultGroupName=CAMS
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.22000
OutputDir=..\..\dist\installer
OutputBaseFilename=CAMS-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\UI\resources\brand\logo.ico
LicenseFile=..\..\LICENSE
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription=CAMS Windows 11 Installer
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "vietnamese"; MessagesFile: "compiler:Languages\Vietnamese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Tạo biểu tượng ngoài màn hình"; GroupDescription: "Biểu tượng bổ sung:"; Flags: unchecked

[Files]
Source: "..\..\dist\windows\CAMS\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\CAMS"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; AppUserModelID: "NetCamsTeam.CAMS.App"
Name: "{autodesktop}\CAMS"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon; AppUserModelID: "NetCamsTeam.CAMS.App"

[Registry]
Root: HKA; Subkey: "Software\Classes\.ntp"; ValueType: string; ValueName: ""; ValueData: "CAMS.Project"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\CAMS.Project"; ValueType: string; ValueName: ""; ValueData: "CAMS Project"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\CAMS.Project\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKA; Subkey: "Software\Classes\CAMS.Project\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Khởi chạy CAMS"; Flags: nowait postinstall skipifsilent

[Code]
function InitializeSetup(): Boolean;
begin
  Result := IsWin64;
  if not Result then
    MsgBox('CAMS yêu cầu Windows 11 64-bit.', mbError, MB_OK);
end;
