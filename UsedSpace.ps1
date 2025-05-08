# Get the logical disk for the C: drive
$logicalDisks = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }

# Loop through each logical disk (in this case, just the C: drive) to calculate disk usage
foreach ($disk in $logicalDisks) {
    # Get total and used space
    $totalSpace = [math]::round($disk.Size / 1GB, 2)     # Total space in GB
    $usedSpace = [math]::round(($disk.Size - $disk.FreeSpace) / 1GB, 2) # Used space in GB

    # Calculate disk usage percentage
    $usagePercentage = if ($totalSpace -ne 0) { [math]::round(($usedSpace / $totalSpace) * 100, 2) } else { 0 }

    # Set Ninja properties with percentage sign for disk usage and formatted total space
    Ninja-Property-Set -Name diskUsage -Value "$usagePercentage%"
    Ninja-Property-Set -Name diskSize -Value "$totalSpace GB"

    # Output the result
    Write-Host "Drive: $($disk.DeviceID), Total Space: $totalSpace GB, Used Space: $usedSpace GB, Usage: $usagePercentage%"
}
