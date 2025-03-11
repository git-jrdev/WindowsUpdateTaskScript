# Deploy-UpdateScript.ps1

$scriptUrl = "https://raw.githubusercontent.com/git-jrdev/WindowsUpdateTaskScript/refs/heads/main/Create-WindowsUpdateTask.ps1"

# Create a temporary directory
$tempDir = "$env:TEMP\WindowsUpdateDeployment"
if (-not (Test-Path -Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
}

Write-Host "Downloading Windows Update automation script..." -ForegroundColor Cyan

try {
    # Download the script
    $scriptPath = "$tempDir\Create-WindowsUpdateTask.ps1"
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath
    
    Write-Host "Script downloaded successfully." -ForegroundColor Green
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "Esse script requer permissões de administrador." -ForegroundColor Yellow
        Write-Host "Tentando reiniciar com permissões elevadas..." -ForegroundColor Yellow
        
        # Create a self-deleting elevated execution command
        $commandArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"; Remove-Item -Path `"$tempDir`" -Recurse -Force"
        
        Start-Process PowerShell.exe -ArgumentList $commandArgs -Verb RunAs
        Exit
    } else {
        # Run the script directly since we already have admin rights
        Write-Host "Running with administrator privileges..." -ForegroundColor Green
        & $scriptPath
        
        # Clean up
        Write-Host "Cleaning up temporary files..." -ForegroundColor Cyan
        Remove-Item -Path $tempDir -Recurse -Force
        
        Write-Host "Windows Update automation has been successfully installed!" -ForegroundColor Green
    }
} catch {
    Write-Host "Erro inesperado: $_" -ForegroundColor Red
    Write-Host "Por gentileza entre em contato com seu TI." -ForegroundColor Red
}