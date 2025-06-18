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
    # Fallback if PSGallery is unavailable
    $modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\SpeculationControl"
    $scriptUrl = "https://raw.githubusercontent.com/microsoft/SpeculationControl/master/SpeculationControl.psm1"
    $scriptFile = "$modulePath\SpeculationControl.psm1"

    if (-not (Test-Path $modulePath)) { 
        New-Item -ItemType Directory -Path $modulePath -Force 
    }

    Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptFile -UseBasicParsing -ErrorAction SilentlyContinue
}

# Import and evaluate mitigation status
Import-Module SpeculationControl -Force
$speculationStatus = Get-SpeculationControlSettings

# Registry path for mitigation settings
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$rebootRequired = $false

# --- SPECULATIVE STORE BYPASS ---
if ($speculationStatus.'Speculative Store Bypass Disabled System-Wide' -eq $false) {
    Write-Host "[SSBD] Mitigation not enabled. Enforcing registry changes..."

    $override = Get-ItemProperty -Path $regPath -Name "FeatureSettingsOverride" -ErrorAction SilentlyContinue
    if ($override.FeatureSettingsOverride -ne 0) {
        Set-ItemProperty -Path $regPath -Name "FeatureSettingsOverride" -Value 0 -Type DWord -Force
        Write-Host "[SSBD] Set FeatureSettingsOverride = 0"
        $rebootRequired = $true
    }

    $mask = Get-ItemProperty -Path $regPath -Name "FeatureSettingsOverrideMask" -ErrorAction SilentlyContinue
    if ($mask.FeatureSettingsOverrideMask -ne 3) {
        Set-ItemProperty -Path $regPath -Name "FeatureSettingsOverrideMask" -Value 3 -Type DWord -Force
        Write-Host "[SSBD] Set FeatureSettingsOverrideMask = 3"
        $rebootRequired = $true
    }
} else {
    Write-Host "[SSBD] Already mitigated system-wide."
}

# --- MDS ---
if ($speculationStatus.'MDS Mitigation Enabled' -eq $false) {
    Write-Host "[MDS] Mitigation not enabled. Applying..."
    Set-ItemProperty -Path $regPath -Name "MdsMitigationEnabled" -Value 1 -PropertyType DWord -Force
    $rebootRequired = $true
} else {
    Write-Host "[MDS] Already mitigated."
}

# --- FBSDP ---
if ($speculationStatus.'FBSDP Mitigation Enabled' -eq $false) {
    Write-Host "[FBSDP] Mitigation not enabled. Applying..."
    Set-ItemProperty -Path $regPath -Name "FbsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force
    $rebootRequired = $true
} else {
    Write-Host "[FBSDP] Already mitigated."
}

# --- PSDP ---
if ($speculationStatus.'PSDP Mitigation Enabled' -eq $false) {
    Write-Host "[PSDP] Mitigation not enabled. Applying..."
    Set-ItemProperty -Path $regPath -Name "PsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force
    $rebootRequired = $true
} else {
    Write-Host "[PSDP] Already mitigated."
}

# --- SBDR (Optional: CVE-2020-0550) ---
if ($speculationStatus.'SBDR Mitigation Enabled' -eq $false) {
    Write-Host "[SBDR] Mitigation not enabled. Applying..."
    Set-ItemProperty -Path $regPath -Name "SbdRMitigationEnabled" -Value 1 -PropertyType DWord -Force
    $rebootRequired = $true
} else {
    Write-Host "[SBDR] Already mitigated."
}

# --- FINALIZE ---
if ($rebootRequired) {
    Write-Host "`nOne or more mitigations applied. Rebooting system now..."
    Restart-Computer -Force
} else {
    Write-Host "`nAll mitigations already in place. No reboot required."
}
