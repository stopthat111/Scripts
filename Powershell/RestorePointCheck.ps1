# Ensure the script is running with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run this script as an administrator." -ForegroundColor Red
    exit
}

# Check for system restore points
try {
    # Get a list of system restore points
    $restorePoints = Get-ComputerRestorePoint

    if ($restorePoints) {
        Write-Host "Current System Restore Points:" -ForegroundColor Green
        $restorePoints | ForEach-Object {
            Write-Host "Restore Point ID: $($_.SequenceNumber)"
            Write-Host "Description: $($_.Description)"
            Write-Host "Type: $($_.EventType)"
            Write-Host "Creation Time: $($_.CreationTime)"
            Write-Host "--------------------------------------"
        }
    } else {
        Write-Host "No system restore points found on this machine." -ForegroundColor Yellow
    }
} catch {
    Write-Host "An error occurred while fetching system restore points. Ensure the System Protection is enabled." -ForegroundColor Red
    Write-Host $_.Exception.Message
}
