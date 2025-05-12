# Ensure admin privileges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Please run PowerShell as Administrator." -ForegroundColor Red
    Exit
}

# Download SpeculationControl module if not present
$ModulePath = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\SpeculationControl"
If (!(Test-Path "$ModulePath\SpeculationControl.psm1")) {
    Write-Host "Downloading SpeculationControl module..."
    New-Item -ItemType Directory -Path $ModulePath -Force | Out-Null
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/microsoft/SpeculationControl/master/SpeculationControl.psm1" -OutFile "$ModulePath\SpeculationControl.psm1"
}

# Import SpeculationControl module
Import-Module $ModulePath\SpeculationControl.psm1 -Force

# Run SpeculationControl check
$Results = Get-SpeculationControlSettings

# Apply registry fixes if needed
$FixesApplied = $false

Function Set-RegistryFix ($Path, $Name, $Value) {
    If ((Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name -ne $Value) {
        Write-Host "Applying fix: $Path\$Name = $Value" -ForegroundColor Yellow
        reg add $Path /v $Name /t REG_DWORD /d $Value /f
        $Global:FixesApplied = $true
    }
}

Write-Host "Analyzing system for speculative execution vulnerabilities..." -ForegroundColor Cyan

# Spectre v2 (Branch Target Injection)
If ($Results.BTIWindowsSupportPresent -eq $true -and $Results.BTIWindowsSupportEnabled -eq $false) {
    Set-RegistryFix "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0
    Set-RegistryFix "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3
}

# Meltdown (KVA Shadow)
If ($Results.KVAShadowWindowsSupportPresent -eq $true -and $Results.KVAShadowWindowsSupportEnabled -eq $false) {
    Set-RegistryFix "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0
}

# MDS (ZombieLoad, Fallout, RIDL)
If ($Results.MDSWindowsSupportPresent -eq $true -and $Results.MDSWindowsSupportEnabled -eq $false) {
    Set-RegistryFix "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0
}

# L1 Terminal Fault (L1TF)
If ($Results.L1TFWindowsSupportPresent -eq $true -and $Results.L1TFWindowsSupportEnabled -eq $false) {
    Set-RegistryFix "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 0
}

# Check if fixes were applied and require a reboot
If ($FixesApplied) {
    Write-Host "Fixes have been applied. A reboot is required for changes to take effect." -ForegroundColor Green
    $Reboot = Read-Host "Would you like to reboot now? (Y/N)"
    If ($Reboot -match "^[Yy]$") {
        Restart-Computer -Force
    }
} Else {
    Write-Host "No changes were needed. Your system is already mitigated." -ForegroundColor Green
}
