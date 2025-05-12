# Ensure TLS 1.2 is enabled for secure module downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Check and install NuGet provider if missing
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false -ErrorAction SilentlyContinue
}

# Ensure PSGallery is registered and trusted
if (-not (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" })) {
    Register-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -Confirm:$false -ErrorAction SilentlyContinue
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

# Attempt to install SpeculationControl module
try {
    Install-Module -Name SpeculationControl -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop
}
catch {
    # Fallback: Manual installation if PSGallery is unavailable
    $modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\SpeculationControl"
    $scriptUrl = "https://raw.githubusercontent.com/microsoft/SpeculationControl/master/SpeculationControl.psm1"
    $scriptFile = "$modulePath\SpeculationControl.psm1"

    if (-not (Test-Path $modulePath)) { 
        New-Item -ItemType Directory -Path $modulePath -Force -Confirm:$false 
    }

    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptFile -UseBasicParsing -ErrorAction SilentlyContinue
}

# Import module and run Speculation Control check
Import-Module SpeculationControl -Force
$speculationStatus = Get-SpeculationControlSettings

# Check if mitigation is required for Speculative Store Bypass
if ($speculationStatus.'Speculative Store Bypass Disabled System-Wide' -eq $false) {
    Write-Host "Mitigation required for Speculative Store Bypass. Applying registry changes..."

    # Apply mitigation via registry
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $featureSettingsOverride = Get-ItemProperty -Path $regPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
    if (-not $featureSettingsOverride) {
        New-ItemProperty -Path $regPath -Name "FeatureSettingsOverride" -Value 0 -PropertyType DWord -Force | Out-Null
    }

    $featureSettingsOverrideMask = Get-ItemProperty -Path $regPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue
    if (-not $featureSettingsOverrideMask) {
        New-ItemProperty -Path $regPath -Name "FeatureSettingsOverrideMask" -Value 3 -PropertyType DWord -Force | Out-Null
    }

    # Apply Speculative Store Bypass disable system-wide
    $featureSettings = Get-ItemProperty -Path $regPath -Name "FeatureSettings" -ErrorAction SilentlyContinue
    if (-not $featureSettings) {
        New-ItemProperty -Path $regPath -Name "FeatureSettings" -Value 0 -PropertyType DWord -Force | Out-Null
    }

    # Force reboot after applying the changes
    Write-Host "Registry changes applied. Rebooting the system now..."
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Host "Speculative Store Bypass is already disabled system-wide."
}

# Check if MDS mitigation is enabled and apply if necessary
if ($speculationStatus.'MDS Mitigation Enabled' -eq $false) {
    Write-Host "MDS mitigation is not enabled. Applying MDS mitigation..."

    # Enable MDS mitigation
    $mdsRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $mdsMitigation = Get-ItemProperty -Path $mdsRegistryPath -Name "MdsMitigationEnabled" -ErrorAction SilentlyContinue
    if (-not $mdsMitigation) {
        New-ItemProperty -Path $mdsRegistryPath -Name "MdsMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    }

    Write-Host "MDS mitigation enabled. Rebooting the system now..."
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Host "MDS mitigation is already enabled."
}

# Check for Fill Buffer Stale Data Propagator (FBSDP) and Primary Stale Data Propagator (PSDP) mitigation
if ($speculationStatus.'FBSDP Mitigation Enabled' -eq $false) {
    Write-Host "FBSDP mitigation is not enabled. Enabling FBSDP mitigation..."

    # Enable FBSDP mitigation
    $fbsdpRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $fbsdpMitigation = Get-ItemProperty -Path $fbsdpRegistryPath -Name "FbsdpMitigationEnabled" -ErrorAction SilentlyContinue
    if (-not $fbsdpMitigation) {
        New-ItemProperty -Path $fbsdpRegistryPath -Name "FbsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    }

    Write-Host "FBSDP mitigation enabled. Rebooting the system now..."
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Host "FBSDP mitigation is already enabled."
}

# Check for PSDP mitigation
if ($speculationStatus.'PSDP Mitigation Enabled' -eq $false) {
    Write-Host "PSDP mitigation is not enabled. Enabling PSDP mitigation..."

    # Enable PSDP mitigation
    $psdpRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    $psdpMitigation = Get-ItemProperty -Path $psdpRegistryPath -Name "PsdpMitigationEnabled" -ErrorAction SilentlyContinue
    if (-not $psdpMitigation) {
        New-ItemProperty -Path $psdpRegistryPath -Name "PsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    }

    Write-Host "PSDP mitigation enabled. Rebooting the system now..."
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
} else {
    Write-Host "PSDP mitigation is already enabled."
}
