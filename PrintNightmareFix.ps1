try {
    Write-Host "Securing the Print Spooler service..."

    # Ensure the Print Spooler service is running
    Write-Host "Starting the Print Spooler service if not already running..."
    Set-Service -Name "Spooler" -StartupType Automatic -ErrorAction Stop
    Start-Service -Name "Spooler" -ErrorAction Stop

    # Restrict driver installation to administrators
    Write-Host "Restricting driver installation to administrators..."
    $regPath = "HKLM:\Software\Policies\Microsoft\Windows NT\Printers"
    if (!(Test-Path -Path $regPath)) {
        New-Item -Path $regPath -Force -ErrorAction Stop
    }
    New-ItemProperty -Path $regPath -Name "RestrictDriverInstallationToAdministrators" -Value 1 -PropertyType DWord -Force -ErrorAction Stop

    # Harden point and print restrictions
    Write-Host "Configuring Point and Print restrictions..."
    $regPathPrint = "HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint"
    if (!(Test-Path -Path $regPathPrint)) {
        New-Item -Path $regPathPrint -Force -ErrorAction Stop
    }

    # Restrict Point and Print server and driver behavior
    New-ItemProperty -Path $regPathPrint -Name "NoWarningNoElevationOnInstall" -Value 0 -PropertyType DWord -Force -ErrorAction Stop
    New-ItemProperty -Path $regPathPrint -Name "UpdatePromptSettings" -Value 2 -PropertyType DWord -Force -ErrorAction Stop

    # Apply recommended group policy settings
    Write-Host "Applying group policy settings for Printer security..."
    Set-ItemProperty -Path $regPathPrint -Name "Restricted" -Value 1 -ErrorAction Stop
    Set-ItemProperty -Path $regPathPrint -Name "TrustedServers" -Value 0 -ErrorAction Stop

    Write-Host "Print Spooler service secured successfully."
} catch {
    Write-Host "An error occurred while securing the Print Spooler service: $_"
}
