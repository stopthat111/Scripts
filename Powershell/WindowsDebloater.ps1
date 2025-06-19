# Optimized and cleaned Windows 10/11 Debloat Script (Windows 11 compatible) with Verbose Output

# Define AppX packages to remove
$AppXApps = @(
    '*TikTok*', '*Instagram*', '*WhatsApp*', '*Disney*', '*Netflix*', '*FacebookMessenger*',
    '*Microsoft.BingNews*', '*Windows.DevHome*', '*Microsoft.GamingApp*', '*Microsoft.GetHelp*', '*Microsoft.Getstarted*',
    '*Microsoft.Messaging*', '*Microsoft.Microsoft3DViewer*', '*Microsoft.MicrosoftOfficeHub*', '*Microsoft.MicrosoftSolitaireCollection*',
    '*Microsoft.NetworkSpeedTest*', '*Microsoft.Office.Sway*', '*Microsoft.OneConnect*', '*Microsoft.People*', '*Microsoft.Print3D*',
    '*Microsoft.SkypeApp*', '*Microsoft.WindowsAlarms*', '*Microsoft.WindowsCamera*', '*microsoft.windowscommunicationsapps*',
    '*Microsoft.WindowsFeedbackHub*', '*Microsoft.WindowsMaps*', '*Microsoft.WindowsSoundRecorder*', '*Microsoft.Xbox.TCUI*',
    '*Microsoft.XboxApp*', '*Microsoft.XboxGameOverlay*', '*Microsoft.XboxGamingOverlay*', '*Microsoft.XboxIdentityProvider*',
    '*Microsoft.XboxSpeechToTextOverlay*', '*Microsoft.YourPhone*', '*Microsoft.ZuneMusic*', '*Microsoft.ZuneVideo*',
    '*EclipseManager*', '*ActiproSoftwareLLC*', '*AdobeSystemsIncorporated.AdobePhotoshopExpress*', '*Duolingo-LearnLanguagesforFree*',
    '*PandoraMediaInc*', '*CandyCrush*', '*Wunderlist*', '*Flipboard*', '*Twitter*', '*Spotify*', '*Clipchamp*',
    '*Microsoft.549981C3F5F10*', '*Microsoft.BingWeather*'
)

Write-Output "Starting AppX package removal process..."

foreach ($App in $AppXApps) {
    $packages = Get-AppxPackage -Name $App -ErrorAction SilentlyContinue
    if ($packages) {
        foreach ($pkg in $packages) {
            Write-Output "Removing AppX Package (Current User): $($pkg.Name) Version: $($pkg.Version)"
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
        }
    } else {
        Write-Output "No AppX package found for pattern: $App (Current User)"
    }

    $allUserPackages = Get-AppxPackage -Name $App -AllUsers -ErrorAction SilentlyContinue
    if ($allUserPackages) {
        foreach ($pkg in $allUserPackages) {
            Write-Output "Removing AppX Package (All Users): $($pkg.Name) Version: $($pkg.Version)"
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    } else {
        Write-Output "No AppX package found for pattern: $App (All Users)"
    }
}

Write-Output "Removing provisioned packages..."
$ProvPackages = Get-AppxProvisionedPackage -Online
foreach ($Prov in $ProvPackages) {
    foreach ($App in $AppXApps) {
        if ($Prov.DisplayName -like $App) {
            Write-Output "Attempting to remove provisioned package: $($Prov.DisplayName)"
            try {
                Remove-AppxProvisionedPackage -Online -PackageName $Prov.PackageName -ErrorAction Stop
                Write-Output "Successfully removed provisioned package: $($Prov.DisplayName)"
            } catch {
                Write-Warning "Failed to remove provisioned package: $($Prov.DisplayName) - $($_.Exception.Message)"
            }
        }
    }
}

# Remove all AppxPackages not whitelisted
[regex]$WhitelistedApps = 'Microsoft.Windows.FileExplorer|Microsoft.Windows.FilePicker|Microsoft.Windows.AppResolverUX|Microsoft.AccountsControl|Microsoft.AsyncTextService|Microsoft.BioEnrollment|Microsoft.CredDialogHost|Microsoft.Paint3D|Microsoft.WindowsCalculator|Microsoft.WindowsStore|Microsoft.Windows.Photos|CanonicalGroupLimited.UbuntuonWindows|Microsoft.XboxGameCallableUI|Microsoft.XboxGamingOverlay|Microsoft.XboxTCUI|Microsoft.XboxIdentityProvider|Microsoft.MicrosoftStickyNotes|Microsoft.MSPaint*|Microsoft.MicrosoftEdgeDevToolsClient|Microsoft.Win32WebViewHost|Microsoft.Windows.AppRep.ChxApp|Microsoft.Windows.AssignedAccessLockApp'

Write-Output "Removing all non-whitelisted AppX packages..."

$AllUsersPackages = Get-AppxPackage -AllUsers | Where-Object { $_.Name -notmatch $WhitelistedApps }
if ($AllUsersPackages) {
    foreach ($pkg in $AllUsersPackages) {
        Write-Output "Removing non-whitelisted package (All Users): $($pkg.Name)"
        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }
} else {
    Write-Output "No non-whitelisted packages found for All Users."
}

$CurrentUserPackages = Get-AppxPackage | Where-Object { $_.Name -notmatch $WhitelistedApps }
if ($CurrentUserPackages) {
    foreach ($pkg in $CurrentUserPackages) {
        Write-Output "Removing non-whitelisted package (Current User): $($pkg.Name)"
        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
    }
} else {
    Write-Output "No non-whitelisted packages found for Current User."
}

# Registry cleanup (Windows 10 & 11 compatible)
$Keys = @(
    'HKCR:\Extensions\ContractId\Windows.BackgroundTasks\PackageId\*',
    'HKCR:\Extensions\ContractId\Windows.File\PackageId\*',
    'HKCR:\Extensions\ContractId\Windows.Launch\PackageId\*',
    'HKCR:\Extensions\ContractId\Windows.Protocol\PackageId\*',
    'HKCR:\Extensions\ContractId\Windows.ShareTarget\PackageId\*'
)

foreach ($Key in $Keys) {
    if (Test-Path $Key) {
        Write-Output "Removing registry key: $Key"
        Remove-Item $Key -Recurse -Force
    } else {
        Write-Output "Registry key not found: $Key"
    }
}

# Disable Cortana, Search, and Feedback (Win10/11 aware)
Write-Output "Configuring policies to disable Cortana, Search, Feedback..."

New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name AllowCortana -Value 0

Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name BingSearchEnabled -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name DisableWebSearch -Value 1

$CDM = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
New-Item -Path $CDM -Force | Out-Null
@('ContentDeliveryAllowed', 'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
  'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled') | ForEach-Object {
    Set-ItemProperty -Path $CDM -Name $_ -Value 0
    Write-Output "Set $($_) = 0 in ContentDeliveryManager"
}

New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name DisableWindowsConsumerFeatures -Value 1
Write-Output "Disabled Windows Consumer Features"

# Feedback disable
$Feedback = 'HKCU:\Software\Microsoft\Siuf\Rules'
New-Item -Path $Feedback -Force | Out-Null
Set-ItemProperty -Path $Feedback -Name PeriodInNanoSeconds -Value 0
Write-Output "Disabled feedback period"

# Disable Holographic First Run (Mixed Reality Portal)
$Holo = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Holographic'
If (Test-Path $Holo) {
    Set-ItemProperty -Path $Holo -Name FirstRunSucceeded -Value 0
    Write-Output "Disabled Holographic First Run"
} else {
    Write-Output "Holographic registry key not found, skipping"
}

# Disable Wi-Fi Sense (Win11 supported)
Write-Output "Disabling Wi-Fi Sense features..."

@(
  'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting',
  'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots'
) | ForEach-Object {
    New-Item -Path $_ -Force | Out-Null
    Set-ItemProperty -Path $_ -Name Value -Value 0
    Write-Output "Set Value = 0 in $_"
}

Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' -Name AutoConnectAllowedOEM -Value 0
Write-Output "Set AutoConnectAllowedOEM = 0"

# Disable Tiles & Notifications
$Push = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications'
New-Item -Path $Push -Force | Out-Null
Set-ItemProperty -Path $Push -Name NoTileApplicationNotification -Value 1
Write-Output "Disabled tile application notifications"

# Disable telemetry
Write-Output "Disabling telemetry..."
@(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection',
  'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
) | ForEach-Object {
    if (Test-Path $_) {
        Set-ItemProperty -Path $_ -Name AllowTelemetry -Value 0
        Write-Output "Set AllowTelemetry = 0 at $_"
    } else {
        Write-Output "Telemetry policy path not found: $_"
    }
}

# Disable Location Services
Write-Output "Disabling location services..."
$Sensor = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}'
$LocConfig = 'HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration'

New-Item -Path $Sensor -Force | Out-Null
Set-ItemProperty -Path $Sensor -Name SensorPermissionState -Value 0
Write-Output "Set SensorPermissionState = 0"

New-Item -Path $LocConfig -Force | Out-Null
Set-ItemProperty -Path $LocConfig -Name Status -Value 0
Write-Output "Set Location Service Status = 0"

# Disable People Icon
$People = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People'
New-Item -Path $People -Force | Out-Null
Set-ItemProperty -Path $People -Name PeopleBand -Value 0
Write-Output "Disabled People Icon"

# Disable unnecessary scheduled tasks
Write-Output "Disabling unnecessary scheduled tasks..."
$ScheduledTasks = @('XblGameSaveTaskLogon', 'XblGameSaveTask', 'Consolidator', 'UsbCeip', 'DmClient', 'DmClientOnScenarioDownload')

foreach ($task in $ScheduledTasks) {
    try {
        Get-ScheduledTask -TaskName $task -ErrorAction Stop | Disable-ScheduledTask
        Write-Output "Disabled scheduled task: $task"
    } catch {
        Write-Warning "Scheduled task not found or failed to disable: $task"
    }
}

# Disable tracking services
Write-Output "Stopping and disabling tracking services..."
$Services = @('dmwappushservice', 'DiagTrack')
foreach ($svc in $Services) {
    try {
        if (Get-Service $svc -ErrorAction SilentlyContinue) {
            Stop-Service $svc -Force -ErrorAction SilentlyContinue
            Set-Service $svc -StartupType Disabled
            Write-Output "Stopped and disabled service: $svc"
        } else {
            Write-Output "Service not found: $svc"
        }
    } catch {
        Write-Warning "Failed to stop or disable service: $svc - $($_.Exception.Message)"
    }
}

Write-Output "Debloat process completed."
