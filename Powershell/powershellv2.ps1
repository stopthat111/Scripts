$powershell2 = Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2

if ($powershell2.State -eq 'Enabled') {
    Write-Host "PowerShell v2 detected. Attempting to remove..." -ForegroundColor Yellow
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2 -NoRestart -ErrorAction Stop
        Write-Host "PowerShell v2 successfully removed." -ForegroundColor Green
    } catch {
        Write-Host "Failed to remove PowerShell v2: $_" -ForegroundColor Red
    }
} else {
    Write-Host "PowerShell v2 is not enabled." -ForegroundColor Cyan
}
