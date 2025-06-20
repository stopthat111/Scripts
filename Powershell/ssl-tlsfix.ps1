# Harden SSL/TLS settings: Disable SSL 2.0/3.0, TLS 1.0/1.1, Enable TLS 1.2/1.3
# With audit logging, summary, confirmation prompt, and optional reboot

# Verify script is running as administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ This script must be run as Administrator." -ForegroundColor Red
    exit 1
}

# Set log path
$logPath = "C:\ProgramData\NinjaRMMAgent\Logs\ssltls-fix.log"
if (-not (Test-Path $logPath)) {
    New-Item -ItemType File -Path $logPath -Force | Out-Null
}

Function Get-ProtocolState {
    param ([string]$Protocol)

    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$Protocol"
    $states = @{}

    foreach ($role in @("Client", "Server")) {
        $key = Join-Path $base $role
        $enabled = $null
        $disabledByDefault = $null

        if (Test-Path $key) {
            $enabled = (Get-ItemProperty -Path $key -Name Enabled -ErrorAction SilentlyContinue).Enabled
            $disabledByDefault = (Get-ItemProperty -Path $key -Name DisabledByDefault -ErrorAction SilentlyContinue).DisabledByDefault
        }

        $states["$role.Enabled"] = $enabled
        $states["$role.DisabledByDefault"] = $disabledByDefault
    }

    return $states
}

Function Set-ProtocolState {
    param (
        [string]$Protocol,
        [bool]$Enable
    )

    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$Protocol"

    foreach ($role in @("Client", "Server")) {
        $key = Join-Path $base $role
        if (-not (Test-Path $key)) {
            New-Item -Path $key -Force | Out-Null
        }

        if ($Enable) {
            New-ItemProperty -Path $key -Name "Enabled" -Value 1 -PropertyType "DWord" -Force | Out-Null
            New-ItemProperty -Path $key -Name "DisabledByDefault" -Value 0 -PropertyType "DWord" -Force | Out-Null
        } else {
            New-ItemProperty -Path $key -Name "Enabled" -Value 0 -PropertyType "DWord" -Force | Out-Null
            New-ItemProperty -Path $key -Name "DisabledByDefault" -Value 1 -PropertyType "DWord" -Force | Out-Null
        }

        Add-Content -Path $logPath -Value "$(Get-Date -Format u) - Modified ${Protocol} ($role): Enabled=$Enable"
    }
}

# Desired protocol states
$desiredStates = @{
    "SSL 2.0"  = $false
    "SSL 3.0"  = $false
    "TLS 1.0"  = $false
    "TLS 1.1"  = $false
    "TLS 1.2"  = $true
    "TLS 1.3"  = $true
}

# Check OS support for TLS 1.3
$tls13Supported = $false
if ([Environment]::OSVersion.Version.Major -ge 10 -and [Environment]::OSVersion.Version.Build -ge 20348) {
    $tls13Supported = $true
} else {
    $desiredStates.Remove("TLS 1.3")
}

Write-Host "`n--- Current SSL/TLS Protocol States ---" -ForegroundColor Cyan
$changes = @{}

foreach ($protocol in $desiredStates.Keys) {
    $current = Get-ProtocolState -Protocol $protocol
    $desired = $desiredStates[$protocol]

    Write-Host "`n${protocol}:" -ForegroundColor White
    foreach ($role in @("Client", "Server")) {
        $enabled = $current["$role.Enabled"]
        $disabled = $current["$role.DisabledByDefault"]
        Write-Host "  $role - Enabled: $enabled, DisabledByDefault: $disabled"

        if (($desired -and ($enabled -ne 1 -or $disabled -ne 0)) -or
            (-not $desired -and ($enabled -ne 0 -or $disabled -ne 1))) {
            $changes[$protocol] = $desired
        }
    }
}

# Summary
if ($changes.Count -eq 0) {
    Write-Host "`n✅ No changes are needed. Protocols already match desired state." -ForegroundColor Green
    Add-Content -Path $logPath -Value "$(Get-Date -Format u) - No changes required"
    exit 0
} else {
    Write-Host "`n⚠️ The following protocols will be modified:" -ForegroundColor Yellow
    foreach ($item in $changes.GetEnumerator()) {
        $status = if ($item.Value) { "ENABLE" } else { "DISABLE" }
        Write-Host " - $($item.Key): $status"
    }

    # Prompt for confirmation
    $response = Read-Host "`nDo you want to apply these changes? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "Aborted by user."
        Add-Content -Path $logPath -Value "$(Get-Date -Format u) - Aborted by user"
        exit 1
    }

    # Apply changes
    foreach ($item in $changes.GetEnumerator()) {
        Set-ProtocolState -Protocol $item.Key -Enable:$item.Value
        Write-Host "✅ Applied changes to $($item.Key)" -ForegroundColor Green
    }

    Write-Host "`n✅ All requested changes applied. A system reboot is required." -ForegroundColor Green
    Add-Content -Path $logPath -Value "$(Get-Date -Format u) - Protocol changes applied successfully"

    # Optional reboot prompt
    $doReboot = Read-Host "`nDo you want to reboot now to apply changes? (Y/N)"
    if ($doReboot -eq 'Y' -or $doReboot -eq 'y') {
        Write-Host "Rebooting..." -ForegroundColor Cyan
        Restart-Computer -Force
    } else {
        Write-Host "⚠️ Reboot postponed. Changes will not take full effect until reboot." -ForegroundColor Yellow
    }
}
