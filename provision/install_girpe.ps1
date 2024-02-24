# Definir la strategie d'execution sur Bypass pour le processus en cours
# Cela permet l'execution de scripts sans aucune restriction pendant la session PowerShell actuelle.
Set-ExecutionPolicy Bypass -Scope Process

# Arrêter le script en cas d'erreur fatale
# Cette directive definit le comportement pour arrêter le script en cas de rencontre d'une erreur grave.
$ErrorActionPreference = 'Stop'

# Desactiver les messages de progression pendant l'execution du script
$ProgressPreference = 'SilentlyContinue'

Write-Output "Etape 1: Creation du dossier d'installation..."
$installationPath = "C:\GIRPE"
New-Item -ItemType Directory -Path $installationPath -Force

Write-Output "Etape 2: Exclusion du dossier d'installation de l'antivirus Windows..."
Add-MpPreference -ExclusionPath $installationPath

Write-Output "Etape 3: Telechargement des fichiers..."
$downloadUrlGIRPE = "https://www.fftt.com/sportif/girpe/telechargements/GIRPE_7_5_21.zip"
$downloadUrlMAJgirpe = "https://www.fftt.com/sportif/girpe/telechargements/MAJgirpe7.zip"
$downloadUrlEasendmail = "https://www.fftt.com/sportif/girpe/telechargements/easendmail.zip"
$downloadUrlAide = "https://www.fftt.com/sportif/girpe/telechargements/aideGIRPE.chm"

Invoke-WebRequest -Uri $downloadUrlGIRPE -OutFile "$installationPath\GIRPE_7_5_21.zip"
Invoke-WebRequest -Uri $downloadUrlMAJgirpe -OutFile "$installationPath\MAJgirpe7.zip"
Invoke-WebRequest -Uri $downloadUrlEasendmail -OutFile "$installationPath\easendmail.zip"
Invoke-WebRequest -Uri $downloadUrlAide -OutFile "$installationPath\aideGIRPE.chm"

Write-Output "Etape 4: Decompression des fichiers ZIP..."
Expand-Archive -Path "$installationPath\GIRPE_7_5_21.zip" -DestinationPath $installationPath -Force
Expand-Archive -Path "$installationPath\MAJgirpe7.zip" -DestinationPath $installationPath -Force
Expand-Archive -Path "$installationPath\easendmail.zip" -DestinationPath $installationPath -Force


Write-Output "Etape 5: Exclusion des fichiers du scan antivirus..."
$filesToExclude = @("GIRPE7.exe", "MAJgirpe7.exe", "Easendmail.exe")
foreach ($file in $filesToExclude) {
    Add-MpPreference -ExclusionPath "$installationPath\$file"
}

Write-Output "Etape 6: Suppression des fichiers ZIP..."
Remove-Item "$installationPath\*.zip" -Force

Write-Output "Etape 7: Installation d'Easendmail en mode silencieux..."
$easendmailInstallerPath = "$installationPath\EasendMail.exe"

# Paramètres pour l'installation silencieuse
$installArguments = "/S /ComponentSelection=!EASendMailComponentManager"
Start-Process -FilePath $easendmailInstallerPath -ArgumentList $installArguments -Wait

Write-Output "Etape 8: Telechargement et installation du certificat USERTrustRSAAddTrustCA.crt..."

$certUrl = "http://crt.usertrust.com/USERTrustRSAAddTrustCA.crt"

$certFilePath = "$installationPath\USERTrustRSAAddTrustCA.crt"
Invoke-WebRequest -Uri $certUrl -OutFile $certFilePath

# Importer le certificat dans le magasin "Root" du "LocalMachine"
$certObject = Get-PfxCertificate -FilePath $certFilePath
$certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
$certStore.Open("ReadWrite")
$certStore.Add($certObject)
$certStore.Close()

Write-Output "Etape 9: Création d'un raccourci sur le bureau pour GIRPE7.exe..."
$girpeExePath = Join-Path $installationPath "GIRPE7.exe"
$desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut([System.IO.Path]::Combine($desktopPath, "GIRPE7.lnk"))
$shortcut.TargetPath = $girpeExePath
$shortcut.Save()

Write-Output "Etape 10: Création d'un raccourci vers https://monclub.fftt.com/login/ sur le bureau..."
$urlShortcutPath = [System.IO.Path]::Combine($desktopPath, "MonClubFFTT.url")
echo "[InternetShortcut]" | Out-File -FilePath $urlShortcutPath -Encoding ASCII
echo "URL=https://monclub.fftt.com/login/" | Out-File -Append -FilePath $urlShortcutPath -Encoding ASCII

Write-Output "Le script d'installation est terminee."
