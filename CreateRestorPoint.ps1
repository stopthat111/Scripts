# Ensure C:\Temp exists
if (-not (Test-Path "C:\Temp")) {
    New-Item -Path "C:\Temp" -ItemType Directory -Force
}

# Define script path
$scriptPath = "C:\Temp\CreateRestorePoint.ps1"

# ---- Define Functions ----
function Start-VSSService {
    $vssService = Get-Service -Name VSS -ErrorAction SilentlyContinue
    if ($vssService.Status -ne 'Running') {
        Start-Service -Name VSS
        Start-Sleep -Seconds 2
    }
}

function Enable-SystemProtection {
    $drive = "C:"
    $protectionStatus = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $drive }
    
    if ($protectionStatus.ProtectionStatus -ne 1) {
        Enable-ComputerRestore -Drive $drive
        Start-Sleep -Seconds 2
    }
}

function Check-FreeDiskSpace {
    $drive = "C:"
    $freeSpace = (Get-PSDrive -Name C).Used
    $totalSpace = (Get-PSDrive -Name C).Used + (Get-PSDrive -Name C).Free
    $freeSpacePercentage = ($freeSpace / $totalSpace) * 100
    if ($freeSpacePercentage -lt 10) {
        Write-Host "Warning: Low disk space on $drive."
    }
}

function ReRegister-VSSComponents {
    $vssFiles = @("ole32.dll", "oleaut32.dll", "vss_ps.dll", "swprv.dll", "eventcls.dll", "es.dll", "comsvcs.dll", "msxml.dll", "msxml3.dll", "msxml4.dll")
    foreach ($file in $vssFiles) {
        regsvr32 /s $file
        Start-Sleep -Seconds 1
    }
}

function Create-RestorePoint {
    try {
        Checkpoint-Computer -Description "Scheduled Restore Point" -RestorePointType "MODIFY_SETTINGS"
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
    }
}

function Limit-RestorePoints {
    $maxRestorePoints = 4
    $restorePoints = Get-WmiObject -Class Win32_SystemRestore | Sort-Object -Property CreationTime -Descending
    if ($restorePoints.Count -gt $maxRestorePoints) {
        $restorePointsToDelete = $restorePoints | Select-Object -Skip $maxRestorePoints
        foreach ($restorePoint in $restorePointsToDelete) {
            $restorePoint.Delete()
            Start-Sleep -Seconds 1
        }
    }
}

# ---- Write script to C:\Temp if it doesn't exist ----
if (-not (Test-Path $scriptPath)) {
    $scriptContent = @'
function Start-VSSService {
    $vssService = Get-Service -Name VSS -ErrorAction SilentlyContinue
    if ($vssService.Status -ne 'Running') {
        Start-Service -Name VSS
        Start-Sleep -Seconds 2
    }
}

function Enable-SystemProtection {
    $drive = "C:"
    $protectionStatus = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $drive }
    
    if ($protectionStatus.ProtectionStatus -ne 1) {
        Enable-ComputerRestore -Drive $drive
        Start-Sleep -Seconds 2
    }
}

function Check-FreeDiskSpace {
    $drive = "C:"
    $freeSpace = (Get-PSDrive -Name C).Used
    $totalSpace = (Get-PSDrive -Name C).Used + (Get-PSDrive -Name C).Free
    $freeSpacePercentage = ($freeSpace / $totalSpace) * 100
    if ($freeSpacePercentage -lt 10) {
        Write-Host "Warning: Low disk space on $drive."
    }
}

function ReRegister-VSSComponents {
    $vssFiles = @("ole32.dll", "oleaut32.dll", "vss_ps.dll", "swprv.dll", "eventcls.dll", "es.dll", "comsvcs.dll", "msxml.dll", "msxml3.dll", "msxml4.dll")
    foreach ($file in $vssFiles) {
        regsvr32 /s $file
        Start-Sleep -Seconds 1
    }
}

function Create-RestorePoint {
    try {
        Checkpoint-Computer -Description "Scheduled Restore Point" -RestorePointType "MODIFY_SETTINGS"
    } catch {
        Write-Host "Error: $($_.Exception.Message)"
    }
}

function Limit-RestorePoints {
    $maxRestorePoints = 4
    $restorePoints = Get-WmiObject -Class Win32_SystemRestore | Sort-Object -Property CreationTime -Descending
    if ($restorePoints.Count -gt $maxRestorePoints) {
        $restorePointsToDelete = $restorePoints | Select-Object -Skip $maxRestorePoints
        foreach ($restorePoint in $restorePointsToDelete) {
            $restorePoint.Delete()
            Start-Sleep -Seconds 1
        }
    }
}

# Execute functions
Start-VSSService
Enable-SystemProtection
Check-FreeDiskSpace
ReRegister-VSSComponents
Limit-RestorePoints
Create-RestorePoint
'@

    $scriptContent | Out-File -FilePath $scriptPath -Encoding utf8 -Force
    Write-Host "Script written to $scriptPath"
} else {
    Write-Host "Script already exists. Skipping file creation."
}

# ---- Execute the first restore immediately ----
Write-Host "Running first restore point immediately..."
Start-VSSService
Enable-SystemProtection
Check-FreeDiskSpace
ReRegister-VSSComponents
Limit-RestorePoints
Create-RestorePoint
Write-Host "First restore point created successfully."

# ---- Create the scheduled task ----
function Create-ScheduledTask {
    $taskName = 'CreateRestorePoint'
    
    $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File $scriptPath"
    $taskTrigger = New-ScheduledTaskTrigger -Weekly -At '12:30PM' -DaysOfWeek Monday
    $taskSettings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -StartWhenAvailable
    $taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount

    # Remove existing task if it exists
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Write-Host "Removing existing scheduled task: $taskName"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Start-Sleep -Seconds 2
    }

    # Register the new task
    try {
        Register-ScheduledTask -Action $taskAction -Principal $taskPrincipal -Trigger $taskTrigger -Settings $taskSettings -TaskName $taskName
        Write-Host "Scheduled task '$taskName' created successfully to run every Monday at 12:30PM."
    } catch {
        Write-Host "Error creating scheduled task: $($_.Exception.Message)"
    }
}

# Create the scheduled task
Create-ScheduledTask
