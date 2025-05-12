# Disable Cortana via Group Policy by editing the registry
Write-Host "Disabling Cortana via Group Policy..."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -Force
Write-Host "Cortana has been disabled."

# Uninstall Cortana from the system
Write-Host "Uninstalling Cortana..."

# Check if Cortana is installed
$cortanaPackage = Get-AppxPackage -Name "*Cortana*" -AllUsers

if ($cortanaPackage) {
    Write-Host "Cortana found, uninstalling..."
    # Uninstall Cortana for all users
    Get-AppxPackage -AllUsers *Cortana* | Remove-AppxPackage
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq "Microsoft.549981C3F5F10" | Remove-AppxProvisionedPackage -Online
    Write-Host "Cortana has been uninstalled."
} else {
    Write-Host "Cortana is not installed."
}

# Optionally, restart the system to apply changes
# Write-Host "Restarting the system to apply changes..."
# Restart-Computer -Force
