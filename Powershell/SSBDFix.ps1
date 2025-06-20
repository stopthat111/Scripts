# Ensure TLS 1.2 for secure downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Install NuGet provider if missing
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Force -Scope CurrentUser -Confirm:$false -ErrorAction SilentlyContinue
}

# Register PSGallery if missing
if (-not (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" })) {
    Register-PSRepository -Name PSGallery -SourceLocation "https://www.powershellgallery.com/api/v2" -Confirm:$false -ErrorAction SilentlyContinue
}
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

# Attempt to install SpeculationControl module if missing
if (-not (Get-Module -ListAvailable -Name SpeculationControl)) {
    try {
        Install-Module -Name SpeculationControl -Force -Scope CurrentUser -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not install SpeculationControl module from PSGallery. Attempting manual download fallback..."
        $modulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\SpeculationControl"
        $scriptUrl = "https://raw.githubusercontent.com/microsoft/SpeculationControl/master/SpeculationControl.psm1"
        $scriptFile = Join-Path $modulePath "SpeculationControl.psm1"
        if (-not (Test-Path $modulePath)) {
            New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
        }
        try {
            Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptFile -UseBasicParsing -ErrorAction Stop
        }
        catch {
            Write-Warning "Manual download of SpeculationControl module failed. Continuing without module."
        }
    }
}

# Import SpeculationControl if available
$speculationStatus = $null
if (Get-Module -ListAvailable -Name SpeculationControl) {
    Import-Module SpeculationControl -Force -ErrorAction SilentlyContinue
    if (Get-Command Get-SpeculationControlSettings -ErrorAction SilentlyContinue) {
        $speculationStatus = Get-SpeculationControlSettings
    }
    else {
        Write-Warning "Get-SpeculationControlSettings cmdlet not found after import."
    }
} else {
    Write-Warning "SpeculationControl module not found; skipping mitigation status checks."
}

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$changesMade = $false

# Helper function to get registry DWORD safely
function Get-RegDwordValue([string]$path, [string]$name) {
    try {
        $prop = Get-ItemProperty -Path $path -Name $name -ErrorAction Stop
        return $prop.$name
    } catch {
        return $null
    }
}

# Check and apply Speculative Store Bypass mitigation
function Apply-SSBDMitigation {
    Write-Host "Checking Speculative Store Bypass mitigation..."
    # Current registry values
    $featureSettingsOverride = Get-RegDwordValue $regPath "FeatureSettingsOverride"
    $featureSettingsOverrideMask = Get-RegDwordValue $regPath "FeatureSettingsOverrideMask"
    $featureSettings = Get-RegDwordValue $regPath "FeatureSettings"

    $needChange = $false
    if ($featureSettingsOverride -ne 0) { $needChange = $true }
    if ($featureSettingsOverrideMask -ne 3) { $needChange = $true }
    if ($featureSettings -ne 0) { $needChange = $true }

    if ($speculationStatus -eq $null -or $speculationStatus.'Speculative Store Bypass Disabled System-Wide' -eq $false -or $needChange) {
        Write-Host "Applying registry keys for Speculative Store Bypass mitigation..."
        New-ItemProperty -Path $regPath -Name "FeatureSettingsOverride" -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $regPath -Name "FeatureSettingsOverrideMask" -Value 3 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $regPath -Name "FeatureSettings" -Value 0 -PropertyType DWord -Force | Out-Null
        $global:changesMade = $true
    } else {
        Write-Host "[SSBD] Mitigation registry keys already set."
    }
    if ($speculationStatus -ne $null -and $speculationStatus.'Speculative Store Bypass Disabled System-Wide' -eq $false) {
        Write-Warning "[SSBD] System-wide mitigation NOT enabled. Ensure CPU microcode and Windows updates are applied."
    } else {
        Write-Host "[SSBD] System-wide mitigation enabled."
    }
}

# Check and apply MDS mitigation
function Apply-MDSMitigation {
    Write-Host "Checking MDS mitigation..."
    $mdsMitigation = Get-RegDwordValue $regPath "MdsMitigationEnabled"
    if ($speculationStatus -eq $null -or $speculationStatus.'MDS Mitigation Enabled' -eq $false -or $mdsMitigation -ne 1) {
        Write-Host "Enabling MDS mitigation registry key..."
        New-ItemProperty -Path $regPath -Name "MdsMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
        $global:changesMade = $true
    } else {
        Write-Host "[MDS] Mitigation already enabled."
    }
}

# Check and apply FBSDP mitigation
function Apply-FBSDPMitigation {
    Write-Host "Checking FBSDP mitigation..."
    $fbsdpMitigation = Get-RegDwordValue $regPath "FbsdpMitigationEnabled"
    if ($speculationStatus -eq $null -or $speculationStatus.'FBSDP Mitigation Enabled' -eq $false -or $fbsdpMitigation -ne 1) {
        Write-Host "Enabling FBSDP mitigation registry key..."
        New-ItemProperty -Path $regPath -Name "FbsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
        $global:changesMade = $true
    } else {
        Write-Host "[FBSDP] Mitigation already enabled."
    }
}

# Check and apply PSDP mitigation
function Apply-PSDPMitigation {
    Write-Host "Checking PSDP mitigation..."
    $psdpMitigation = Get-RegDwordValue $regPath "PsdpMitigationEnabled"
    if ($speculationStatus -eq $null -or $speculationStatus.'PSDP Mitigation Enabled' -eq $false -or $psdpMitigation -ne 1) {
        Write-Host "Enabling PSDP mitigation registry key..."
        New-ItemProperty -Path $regPath -Name "PsdpMitigationEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
        $global:changesMade = $true
    } else {
        Write-Host "[PSDP] Mitigation already enabled."
    }
}

# SBDR mitigation does not have registry keys, only OS/firmware enforced
function Check-SBDRMitigation {
    if ($speculationStatus -ne $null) {
        if ($speculationStatus.'SBDR Mitigation Enabled' -eq $false) {
            Write-Warning "[SBDR] Mitigation not enabled. Confirm firmware and OS patch level."
        } else {
            Write-Host "[SBDR] Mitigation enabled."
        }
    } else {
        Write-Warning "[SBDR] SpeculationControl data unavailable."
    }
}

# Run mitigation checks and apply changes
Apply-SSBDMitigation
Apply-MDSMitigation
Apply-FBSDPMitigation
Apply-PSDPMitigation
Check-SBDRMitigation

if ($changesMade) {
    Write-Host "Mitigation registry keys updated. Rebooting to apply changes..."
    Restart-Computer -Force -Confirm:$false -ErrorAction SilentlyContinue
    exit
} else {
    Write-Host "All mitigations are already in place. No reboot required."
}
