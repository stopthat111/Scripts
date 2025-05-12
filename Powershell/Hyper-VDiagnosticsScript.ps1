# Hyper-V Diagnostics Script

Write-Host "=== Checking Hyper-V Feature State ==="
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All

Write-Host "`n=== Verifying Hyper-V Services ==="
$services = "vmms", "vmcompute"
foreach ($svc in $services) {
    Get-Service -Name $svc -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
}

Write-Host "`n=== Checking if vmconnect.exe Exists ==="
$vmconnectPath = "$env:SystemRoot\System32\vmconnect.exe"
if (Test-Path $vmconnectPath) {
    Write-Host "vmconnect.exe exists: $vmconnectPath"
} else {
    Write-Warning "vmconnect.exe is missing!"
}

Write-Host "`n=== Checking Hyper-V Related Registry Keys ==="
$keys = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Virtualization",
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
)
foreach ($key in $keys) {
    if (Test-Path $key) {
        Write-Host "Registry key exists: $key"
    } else {
        Write-Warning "Missing registry key: $key"
    }
}

Write-Host "`n=== Recent Hyper-V Errors from Event Logs ==="
Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-VMMS-Admin" -MaxEvents 10 |
    Where-Object {$_.LevelDisplayName -eq "Error"} |
    Format-Table TimeCreated, Id, Message -AutoSize

Write-Host "`n=== Additional System Errors Related to Hyper-V or VMConnect ==="
Get-WinEvent -LogName System -MaxEvents 100 |
    Where-Object {
        $_.Message -match "Hyper-V|vmconnect|Virtual Machine|vmms"
    } |
    Format-Table TimeCreated, Id, Message -AutoSize

Write-Host "`n=== Script Complete ==="
