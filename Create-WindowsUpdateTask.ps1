# Create-WindowsUpdateTask.ps1
# This script creates a scheduled task to automatically check and install Windows updates at system startup

# Check if script is running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Esse script requer permissões de administrador. Por favor re-execute o script com permissões elevadas."
    Exit 1
}

# Ensure the PSWindowsUpdate module is installed
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Output "PSWindowsUpdate module not found. Attempting to install..."
    try {
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers -Confirm:$false
        Write-Output "PSWindowsUpdate module installed successfully."
    } catch {
        Write-Error "Falha ao instalar o modulo PSWindowsUpdate. Por favor instalar manualmente utilizando o comando: 'Install-Module PSWindowsUpdate -Force'; Ou contate o seu TI."
        Exit 1
    }
}

# Define the path for the update script
$scriptPath = "$env:LOCALAPPDATA\WindowsUpdate"
$updateScriptPath = "$scriptPath\checkupdate.ps1"

# Create directory if it doesn't exist
if (-not (Test-Path -Path $scriptPath)) {
    New-Item -Path $scriptPath -ItemType Directory -Force | Out-Null
}

# Create the Windows Update script
$updateScript = @'
# checkupdate.ps1 - Windows Update Script
# This script checks for and installs Windows updates with logging

# Setup logging
$logPath = "$env:LOCALAPPDATA\WindowsUpdate\update_logs"
if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}
$logFile = "$logPath\update_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param(
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
    Write-Output $Message
}

# Begin logging
Write-Log "Windows Update process started"

try {
    # Check if PSWindowsUpdate module is installed
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "PSWindowsUpdate module not found. Attempting to install..."
        Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser -Confirm:$false
        Write-Log "PSWindowsUpdate module installed successfully."
    }

    # Import the module
    Import-Module PSWindowsUpdate
    Write-Log "PSWindowsUpdate module imported successfully"

    # Get available updates
    Write-Log "Checking for available updates..."
    $Updates = Get-WindowsUpdate
    
    if ($Updates.Count -eq 0) {
        Write-Log "No updates found. System is up to date."
    } else {
        Write-Log "Found $($Updates.Count) updates to install"
        
        # Install updates
        Write-Log "Installing updates - this may take some time..."
        $installResult = Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -Verbose 4>&1
        
        # Log the result
        Write-Log "Update installation completed with the following results:"
        foreach ($line in $installResult) {
            Write-Log "  $line"
        }
    }
} catch {
    Write-Log "Error occurred during Windows Update process: $_"
}

Write-Log "Windows Update process completed"
'@

# Save the update script to file
Set-Content -Path $updateScriptPath -Value $updateScript

# Create the scheduled task
$taskName = "Windows_AutoUpdate"
$taskDescription = "Automatically checks and installs Windows updates at user logon"

# Remove task if it already exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Output "Removed existing scheduled task: $taskName"
}

$taskTrigger = New-ScheduledTaskTrigger -AtLogon

# Create the action to run the PowerShell script
$taskAction = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$updateScriptPath`""

# Define settings
$taskSettings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

# Register the scheduled task to run with highest privileges (SYSTEM account)
Register-ScheduledTask -TaskName $taskName -Description $taskDescription -Trigger $taskTrigger -Action $taskAction -Settings $taskSettings -User "SYSTEM" -RunLevel Highest

Write-Output "Tarefa programada com sucesso: '$taskName'"
Write-Output "O script de atualização do Windows foi instalado em: $updateScriptPath"
Write-Output "Very Nice My Friend!"
