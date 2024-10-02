<#
.Synopsis
   This is a task script to run on a Windows device that has Remote Desktop Connection Manager installed to help automate daily password updates for accounts to RDCM config files.
.DESCRIPTION
    This is a task script to run on a Windows device that has Remote Desktop Connection Manager installed to help automate daily password updates for accounts to RDCM config files.
    Run script and target the RDG file you wish to update before entering credentials to update. the new password will be encrypted using RDCM com objects to set in config file

.EXAMPLE
  Update-RDGPassword.ps1 -FilePath "C:\RDCConfig.rdg" -Username "Username"

.INPUTS
   String: -FilePath "C:\file\path\to\config.rdg" ( use this to avoid file dialog every time)
.INPUTS
   String: -Username "Username" (use this to avoid having to re-enter username each time, this is case sensitive)
.ROLE
   Password Management
.FUNCTIONALITY
   Management
#>
#Requires -PSEdition Desktop
param(
    [parameter(Mandatory = $false , position = 0)]
    [string] $FilePath,
    [parameter(Mandatory = $false , position = 1)]
    [string] $Username

)

#check for RDCMAN.exe, then copy to temp for module use

Add-Type -AssemblyName System.Windows.Forms
if (! $(Test-Path 'C:\Program Files (x86)\Microsoft\Remote Desktop Connection Manager\RDCMan.exe')){ "RDC MAN Not found installed on this machine! Need installed version for password encryption"; return}
if ( ! $(Test-Path 'C:\temp\RDCMan.dll')){ Copy-Item 'C:\Program Files (x86)\Microsoft\Remote Desktop Connection Manager\RDCMan.exe' 'C:\temp\RDCMan.dll'}
Import-Module 'C:\temp\RDCMan.dll'
$EncryptionSettings = New-Object -TypeName RdcMan.EncryptionSettings


#select RDG File
if(! $FilePath) {
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        InitialDirectory = [Environment]::GetFolderPath('Desktop')
        Filter           = 'RDCMan Config (*.rdg)|*.rdg| All Files | *'
    }
    $null = $FileBrowser.ShowDialog()
    if ( $FileBrowser.FileName) { $FilePath = $FileBrowser.FileName }


}

#check RDG File
if ( $FilePath ) {
    #get-cred to update in RDG
    if($Username) {$cred = Get-Credential -Message "Please enter your new password." -UserName $Username}
    else { $cred = Get-Credential -Message "Please enter the username in your RDG file you would like to update (no domain), followed by your new password." }

    if(! $cred) {Write-Host "Credential not provided. Exiting" ; return}

    $PwdString = [RdcMan.Encryption]::EncryptString($cred.GetNetworkCredential().Password, $EncryptionSettings)

    $file = Get-Item -Path $FilePath
    $filecontent = Get-Content $FilePath
    $indexcheck = $filecontent.IndexOf("        <userName>$($cred.UserName)</userName>")
    if($indexcheck -ge 0){
        #backup file before pw change
        Write-Host "Username found, updating password. Backup meing made at $($file.directoryname)\$($file.basename)-scriptbackup.rdg"
        Copy-Item -LiteralPath $file.FullName -Destination "$($file.directoryname)\$($file.basename)-scriptbackup.rdg"
        #found username.
        $filecontent[$indexcheck + 1] = "        <password>$PwdString</password>"
        $filecontent | Set-Content -LiteralPath $FilePath
    }
    else {Write-Host "Username not found in RDG file. No changes made. Please confirm id matches exactly (case-sensitive) in file"}


}
else { Write-Host "No file Selected. Exiting" }


