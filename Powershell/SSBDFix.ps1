# Ensure TLS 1.2 is enabled for secure module downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet provider if missing
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false -ErrorAction SilentlyContinue
}

# Register and trust PSGallery if not already
if (-not (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" })) {
    Register-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -ErrorAction SilentlyContinue
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

# Try to install the SpeculationControl module
try {
    Install-Module -Name SpeculationControl -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop
} catch {
    $modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\SpeculationControl"
    $scriptUrl = "https://raw.githubusercontent.com/microsoft/SpeculationControl/master/SpeculationControl.psm1"
    $scriptFile = "$modulePath\SpeculationControl.psm1"

    if (-not (Test-Path $modulePath)) {
        New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    }

    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptFile -UseBasicParsing -ErrorAction SilentlyContinue
}

# Import module and get settings
Import-Module SpeculationControl -Force
$speculationStatus = Get-SpeculationControlSettings

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$rebootRequired = $false

# --- SPECULATIVE STORE BYPASS ---
if (-not $speculationStatus.'Speculative Store Bypass Disabled System-Wide') {
    Write-Host "Applying Speculative Store Bypass mitigation..."
    New-ItemProperty -Path $regPath -Name "FeatureSettingsOverride" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name "FeatureSettingsOverrideMask" -Value 3 -PropertyType DWord -Force | Out-Null
    $rebootRequired = $true
}

# --- MDS MITIGATION ---
if (-not $speculationStatus.'MDS Mitigation Enabled') {
    Write-Host "Enabling MDS mitigation..."
    New-ItemProperty -Path $regPath -Name "MdsMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    $rebootRequired = $true
}

# --- FBSDP MITIGATION ---
if (-not $speculationStatus.'FBSDP Mitigation Enabled') {
    Write-Host "Enabling FBSDP mitigation..."
    New-ItemProperty -Path $regPath -Name "FbsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    $rebootRequired = $true
}

# --- PSDP MITIGATION ---
if (-not $speculationStatus.'PSDP Mitigation Enabled') {
    Write-Host "Enabling PSDP mitigation..."
    New-ItemProperty -Path $regPath -Name "PsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    $rebootRequired = $true
}

# Final step
if ($rebootRequired) {
    Write-Host "Mitigation changes applied. Rebooting system..."
    Restart-Computer -Force
} else {
    Write-Host "All mitigations are already enabled. No reboot necessary."
}
