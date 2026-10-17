; Installateur Windows de "A petits pas" (Inno Setup 6).
; Compile par le CI : ISCC /DAppVersion=1.3.0 /DSourceDir=<Release> /DIconFile=<ico> petitpas.iss
; (fichier sans accents : ISCC le lit comme du texte ANSI faute de BOM)
;
; Installation par utilisateur, sans droits administrateur (postes d'ecole
; souvent verrouilles). Les donnees de la classe sont dans Documents : la
; desinstallation ne les touche pas.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
; Ne jamais changer : c'est ce qui relie les mises a jour a l'installation existante.
AppId={{EA936717-6D95-40DA-A376-C4862D41B4BF}
AppName=A petits pas
AppVersion={#AppVersion}
AppPublisher=A petits pas
DefaultDirName={autopf}\A petits pas
DefaultGroupName=A petits pas
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=.
OutputBaseFilename=PetitPas_v{#AppVersion}_Windows_Setup
#ifdef IconFile
SetupIconFile={#IconFile}
#endif
UninstallDisplayIcon={app}\petitpas.exe
UninstallDisplayName=A petits pas
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; L'application doit etre fermee pour etre mise a jour.
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\A petits pas"; Filename: "{app}\petitpas.exe"
Name: "{group}\{cm:UninstallProgram,A petits pas}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\A petits pas"; Filename: "{app}\petitpas.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\petitpas.exe"; Description: "{cm:LaunchProgram,A petits pas}"; Flags: nowait postinstall skipifsilent
