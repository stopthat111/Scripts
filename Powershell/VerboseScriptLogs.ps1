# Enable Process Creation Logging
Write-Host "Enabling Process Creation Logging..." -ForegroundColor Cyan
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" `
    -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord

# Configure Audit Policies using AuditPol
Write-Host "Configuring Audit Policies..." -ForegroundColor Cyan

# Set Success and Failure auditing for Process Creation
$subCategory = "Process Creation"
$auditCommand = "auditpol /set /subcategory:'$subCategory' /success:enable /failure:enable"

try {
    Invoke-Expression $auditCommand
    Write-Host "Audit policies configured successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to configure audit policies: $_" -ForegroundColor Red
}

# Inform user
Write-Host "Process Creation Logging and Command-Line Logging are now enabled." -ForegroundColor Green
Write-Host "Please reboot the system for changes to take effect." -ForegroundColor Yellow
