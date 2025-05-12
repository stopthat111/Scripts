# Define the timeframe for the last 24 hours
$startTime = (Get-Date).AddHours(-24)
$endTime = Get-Date

# Get recent detections within the last 24 hours
$detections = Get-MpThreatDetection | Where-Object {
    $_.InitialDetectionTime -ge $startTime -and $_.InitialDetectionTime -le $endTime
}

# Get recent remediations within the last 24 hours
$remediations = Get-MpThreatRemediationHistory | Where-Object {
    $_.RemediationTime -ge $startTime -and $_.RemediationTime -le $endTime
}

# Output results
Write-Host "Recent Threat Detections in the Last 24 Hours:"
$detections | Format-Table -AutoSize

Write-Host "`nRecent Threat Remediations in the Last 24 Hours:"
$remediations | Format-Table -AutoSize
