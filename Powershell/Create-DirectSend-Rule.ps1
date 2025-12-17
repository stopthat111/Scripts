# =====================================================
# Hardened Direct Send Protection Script
# =====================================================

param(
    [switch]$WhatIf
)

# =====================================================
# STA relaunch using host-agnostic current process path
# =====================================================
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $currentProcessPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    Start-Process -FilePath $currentProcessPath -ArgumentList "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# =====================================================
# Module install/import with Try/Catch & AllowClobber
# =====================================================
try {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Install-Module ExchangeOnlineManagement -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
    }
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Failed to install or import ExchangeOnlineManagement module: $_"
    exit
}

# =====================================================
# GUI: Domains + Enforce Toggle + WhatIf Toggle
# =====================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Direct Send Protection (Dual-Rule, Hardened)"
$form.Size = New-Object System.Drawing.Size(520, 500)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# Domain label and textbox
$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter internal domains (one per line):"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10, 10)
$form.Controls.Add($label)

$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Multiline = $true
$textBox.ScrollBars = "Vertical"
$textBox.Size = New-Object System.Drawing.Size(480, 260)
$textBox.Location = New-Object System.Drawing.Point(10, 35)
$textBox.AcceptsReturn = $true
$textBox.AcceptsTab = $true
$textBox.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq 'Enter') {
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    }
})
$form.Controls.Add($textBox)

# Enforce checkbox
$checkbox = New-Object System.Windows.Forms.CheckBox
$checkbox.Text = "Enable enforcement (block unauthorized direct send)"
$checkbox.AutoSize = $true
$checkbox.Location = New-Object System.Drawing.Point(10, 305)
$form.Controls.Add($checkbox)

# Audit warning label
$warning = New-Object System.Windows.Forms.Label
$warning.Text = "Audit rule will always remain enabled."
$warning.AutoSize = $true
$warning.ForeColor = [System.Drawing.Color]::DarkRed
$warning.Location = New-Object System.Drawing.Point(10, 330)
$form.Controls.Add($warning)

# WhatIf checkbox
$whatIfCheckbox = New-Object System.Windows.Forms.CheckBox
$whatIfCheckbox.Text = "WhatIf (dry-run, no changes will be made)"
$whatIfCheckbox.AutoSize = $true
$whatIfCheckbox.Location = New-Object System.Drawing.Point(10, 355)
$form.Controls.Add($whatIfCheckbox)

# OK / Cancel buttons
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(330, 400)
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Location = New-Object System.Drawing.Point(415, 400)
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelButton)

# Show form
if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }

# =====================================================
# Capture user selections
# =====================================================
$EnableEnforce = $checkbox.Checked
$WhatIf = $whatIfCheckbox.Checked

# =====================================================
# Process input domains with regex validation
# =====================================================
$InternalDomains = $textBox.Lines |
    ForEach-Object { $_.Trim().ToLower() } |
    Where-Object { $_ -match '^(?:[a-z0-9-]+\.)+[a-z]{2,}$' } |
    Sort-Object -Unique

if ($InternalDomains.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show("No valid domains entered. Exiting.","Error","OK","Error")
    exit
}

# =====================================================
# Prompt for admin UPN + validation + connect with progress
# =====================================================
$adminUPN = (Read-Host "Enter Exchange Online admin UPN").Trim()
if (-not $adminUPN -or $adminUPN -notmatch '^[^@]+@[^@]+\.[^@]+$') {
    Write-Host "Invalid UPN. Exiting."
    exit
}

try {
    Connect-ExchangeOnline -UserPrincipalName $adminUPN -ShowBanner:$false -ShowProgress:$true
}
catch {
    Write-Host "ERROR: Failed to connect to Exchange Online: $($_.Exception.Message)"
    exit
}

# =====================================================
# Rule Names + Common Params
# =====================================================
$AuditRuleName   = "AUDIT - Unauthorized Direct Send"
$EnforceRuleName = "ENFORCE - Block Unauthorized Direct Send"

$commonParams = @{
    FromScope      = "NotInOrganization"
    SenderDomainIs = $InternalDomains
}

# =====================================================
# AUDIT RULE (always exists)
# =====================================================
$auditRule = Get-TransportRule -Identity $AuditRuleName -ErrorAction SilentlyContinue
if ($auditRule) {
    Set-TransportRule -Identity $AuditRuleName `
        @commonParams `
        -SetHeaderName "X-Audit-DirectSend" `
        -SetHeaderValue "Detected" `
        -Comments "AUDIT ONLY: Detects spoofed internal domains. Updated $(Get-Date)." `
        -Enabled $true `
        -WhatIf:$WhatIf
} else {
    New-TransportRule -Name $AuditRuleName `
        @commonParams `
        -SetHeaderName "X-Audit-DirectSend" `
        -SetHeaderValue "Detected" `
        -Comments "AUDIT ONLY: Detects spoofed internal domains. No blocking." `
        -Enabled $true `
        -WhatIf:$WhatIf
}

# Re-query AUDIT rule before priority
$auditRule = Get-TransportRule -Identity $AuditRuleName -ErrorAction SilentlyContinue

# =====================================================
# ENFORCE RULE (optional, toggle disables if unchecked)
# =====================================================
$enforceRule = Get-TransportRule -Identity $EnforceRuleName -ErrorAction SilentlyContinue
if ($EnableEnforce) {
    if ($enforceRule) {
        Set-TransportRule -Identity $EnforceRuleName `
            @commonParams `
            -RejectMessageReasonText "Unauthorized direct send using internal domain is not permitted." `
            -RejectMessageEnhancedStatusCode "5.7.1" `
            -Comments "ENFORCED: Blocking spoofed internal domains. Updated $(Get-Date)." `
            -Enabled $true `
            -WhatIf:$WhatIf
    } else {
        New-TransportRule -Name $EnforceRuleName `
            @commonParams `
            -RejectMessageReasonText "Unauthorized direct send using internal domain is not permitted." `
            -RejectMessageEnhancedStatusCode "5.7.1" `
            -Comments "ENFORCED: Blocking spoofed internal domains." `
            -Enabled $true `
            -WhatIf:$WhatIf
    }
} elseif (-not $EnableEnforce -and $enforceRule) {
    Set-TransportRule -Identity $EnforceRuleName -Enabled $false -WhatIf:$WhatIf
}

# Re-query ENFORCE rule before priority hardening
$enforceRule = Get-TransportRule -Identity $EnforceRuleName -ErrorAction SilentlyContinue

# =====================================================
# Priority hardening (ENFORCE only if exists & enabled)
# =====================================================
if ($enforceRule -and $enforceRule.Enabled) {
    Set-TransportRule -Identity $EnforceRuleName -Priority 0 -StopRuleProcessing $true -WhatIf:$WhatIf
}
if ($auditRule) {
    Set-TransportRule -Identity $AuditRuleName -Priority 1 -WhatIf:$WhatIf
}

# =====================================================
# Export configuration for audit (include AdminUPN + WhatIf)
# =====================================================
$AuditExportPath = "$env:USERPROFILE\DirectSendRulesAudit.csv"
$ExportObj = [PSCustomObject]@{
    Timestamp          = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    AdminUPN           = $adminUPN
    WhatIf             = $WhatIf
    AuditRuleName      = $AuditRuleName
    EnforceRuleName    = $EnforceRuleName
    Domains            = ($InternalDomains -join ";")
    EnforcementEnabled = $EnableEnforce
}

if (Test-Path $AuditExportPath) {
    $ExportObj | Export-Csv -Path $AuditExportPath -NoTypeInformation -Append
} else {
    $ExportObj | Export-Csv -Path $AuditExportPath -NoTypeInformation
}

# =====================================================
# Cleanup
# =====================================================
Disconnect-ExchangeOnline -Confirm:$false
