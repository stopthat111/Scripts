param(
    [string]$OutputFile = "C:\temp\CPU_Usage_Report.txt",
    [int]$Interval = 5
)

# Ensure output directory exists
if (-not (Test-Path "C:\temp")) {
    New-Item -ItemType Directory -Path "C:\temp"
}

# Clear previous report if it exists
if (Test-Path $OutputFile) {
    Remove-Item $OutputFile
}

Write-Output "Timestamp, CPU Usage (%)" | Out-File -FilePath $OutputFile -Append

$endTime = (Get-Date).AddHours(24)

while ((Get-Date) -lt $endTime) {
    $cpuLoad = Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    "$timestamp, $cpuLoad" | Out-File -FilePath $OutputFile -Append
    Write-Output "$timestamp - CPU Usage: $cpuLoad%"

    Start-Sleep -Seconds $Interval
}

Write-Output "Data collection completed. Report saved to $OutputFile."
