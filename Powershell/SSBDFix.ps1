# Enforce TLS 1.2 for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet if missing
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false -ErrorAction SilentlyContinue
}

# Register PSGallery if missing
if (-not (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" })) {
    Register-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -Confirm:$false -ErrorAction SilentlyContinue
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

# Install SpeculationControl module
try {
    Install-Module -Name SpeculationControl -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop
}
catch {
    $modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\SpeculationControl"
    $scriptUrl = "https://raw.githubusercontent.com/microsoft/SpeculationControl/master/SpeculationControl.psm1"
    $scriptFile = "$modulePath\SpeculationControl.psm1"
    if (-not (Test-Path $modulePath)) {
        New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    }
    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptFile -UseBasicParsing -ErrorAction SilentlyContinue
}

# Load module and run check
Import-Module SpeculationControl -Force
$speculationStatus = Get-SpeculationControlSettings

# --- SSBD FIX START ---
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if ($speculationStatus.'Speculative Store Bypass Disabled System-Wide' -eq $false) {
    Write-Host "Applying Speculative Store Bypass (SSBD) mitigation..."

    New-ItemProperty -Path $regPath -Name "FeatureSettingsOverride" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name "FeatureSettingsOverrideMask" -Value 3 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name "FeatureSettings" -Value 0 -PropertyType DWord -Force | Out-Null

    Write-Host "SSBD mitigation applied. Rebooting system..."
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
    exit
} else {
    Write-Host "[SSBD] Already mitigated system-wide."
}
# --- SSBD FIX END ---

# MDS Mitigation
if ($speculationStatus.'MDS Mitigation Enabled' -eq $false) {
    Write-Host "Enabling MDS mitigation..."
    New-ItemProperty -Path $regPath -Name "MdsMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
    exit
} else {
    Write-Host "[MDS] Already mitigated."
}

# FBSDP
if ($speculationStatus.'FBSDP Mitigation Enabled' -eq $false) {
    Write-Host "Enabling FBSDP mitigation..."
    New-ItemProperty -Path $regPath -Name "FbsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
    exit
} else {
    Write-Host "[FBSDP] Already mitigated."
}

# PSDP
if ($speculationStatus.'PSDP Mitigation Enabled' -eq $false) {
    Write-Host "Enabling PSDP mitigation..."
    New-ItemProperty -Path $regPath -Name "PsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
    exit
} else {
    Write-Host "[PSDP] Already mitigated."
}

# SBDR (included automatically if OS and firmware support exists)
if ($speculationStatus.'SBDR Mitigation Enabled' -eq $false) {
    Write-Host "[SBDR] Mitigation not enabled, but no specific registry key exists. Confirm OS and firmware support."
} else {
    Write-Host "[SBDR] Already mitigated."
}
