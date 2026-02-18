<#
.SYNOPSIS
Entra IR Containment Toolkit (GUI default) using Microsoft Graph PowerShell.

.DESCRIPTION
Targets Enabled/Licensed/Member accounts (configurable), excluding break-glass UPN prefixes and optionally excluding members of specified groups.
Actions:
- Disable Accounts
- Revoke Sessions
- Reset MFA methods (removes supported auth methods)
- Reset Passwords (cloud-only by default; hybrid-synced skipped unless overridden)

Includes:
- GUI by default (unless -NoGui)
- Headless flags support
- CSV action log (per user / per action)
- Optional password export CSV (separate from action log)
- Preview Targets (count + sample)
- Safety confirm phrase "RESET" gate in GUI when WhatIf is OFF
- Safety confirm phrase in headless mode when WhatIf is OFF
- AdminUPN prompt (like EXO pattern) and hard enforcement of signed-in account
- Disables WAM preference to avoid auto-using current Windows account (best effort)

.NOTES
Requires Graph scopes:
User.ReadWrite.All, Directory.ReadWrite.All, UserAuthenticationMethod.ReadWrite.All, User.RevokeSessions.All, Group.Read.All, Organization.Read.All
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    # GUI behavior: GUI is DEFAULT unless -NoGui
    [switch]$NoGui,

    # Actions (flags)
    [switch]$DisableAccounts,
    [switch]$RevokeSessions,
    [switch]$ResetMfa,
    [switch]$ResetPasswords,

    # Targeting
    [bool]$LicensedOnly = $true,
    [bool]$MembersOnly  = $true,
    [bool]$EnabledOnly  = $true,

    # Optional exclusion by group(s)
    [string[]]$ExcludeGroupIds = @(),

    # Hybrid-safe behavior for passwords
    [bool]$SkipHybridPasswordReset = $true,

    # Password options
    [ValidateRange(8,128)]
    [int]$PasswordLength = 20,
    [bool]$ForceChangePasswordNextSignIn = $true,

    [switch]$ExportPasswordResets,
    [string]$PasswordExportPath = ".\PasswordResets_$((Get-Date).ToString('yyyyMMdd_HHmmss')).csv",

    # Break-glass handling
    [string[]]$BreakGlassUpnPrefixes = @("andy.dolittle","danny.dolittle","andy.glass","administrator"),

    # Action logging (CSV)
    [switch]$NoActionLog,
    [string]$ActionLogPath = ".\IR_ActionLog_$((Get-Date).ToString('yyyyMMdd_HHmmss')).csv",

    # Optional: smooth throttling bursts in large tenants
    [ValidateRange(0,2000)]
    [int]$PerUserDelayMs = 0,

    # Auth (headless/CLI; no GUI integration requested)
    [string]$AdminUPN = ""
)

# -----------------------------
# NORMALIZE INPUTS
# -----------------------------
if ($BreakGlassUpnPrefixes) {
    $BreakGlassUpnPrefixes = $BreakGlassUpnPrefixes | ForEach-Object { $_.ToLowerInvariant() }
}

function Normalize-GroupIds {
    param([string[]]$Ids)

    if (-not $Ids) { return @() }

    $flat = @()
    foreach ($i in $Ids) {
        if (-not $i) { continue }
        # allow comma/semicolon/space/newline-separated
        $flat += ($i -split '[,\s;]+' | Where-Object { $_ -and $_.Trim() })
    }
    $flat | Select-Object -Unique
}

$ExcludeGroupIds = Normalize-GroupIds $ExcludeGroupIds

# -----------------------------
# REQUIRED GRAPH MODULES
# -----------------------------
$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Users",
    "Microsoft.Graph.Identity.SignIns",
    "Microsoft.Graph.Users.Actions",
    "Microsoft.Graph.Groups"
)

# Determine install scope (avoid requiring elevation)
$installScope = 'CurrentUser'
try {
    if ($IsWindows) {
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isAdmin) { $installScope = 'AllUsers' }
    }
} catch {}

foreach ($module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing missing module: $module (Scope: $installScope)" -ForegroundColor Yellow
        Install-Module $module -Repository PSGallery -Scope $installScope -Force -AllowClobber -ErrorAction Stop
    }
    Import-Module $module -ErrorAction Stop
}

# -----------------------------
# GRAPH RETRY WRAPPER (429/5xx)
# -----------------------------
function Invoke-GraphWithRetry {
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [int]$MaxRetries = 8
    )

    $attempt = 0
    while ($true) {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            if ($attempt -gt $MaxRetries) { throw }

            $sleep = [int][Math]::Min(60, [Math]::Pow(2, $attempt))
            $msg = $_.Exception.Message
            if ($msg -match '(?i)retry-?after[: ]+(\d+)') { $sleep = [int]$Matches[1] }

            Write-Host "Transient Graph error (attempt $attempt/$MaxRetries). Sleeping $sleep sec. Error: $msg" -ForegroundColor Yellow
            Start-Sleep -Seconds $sleep
        }
    }
}

# -----------------------------
# CONNECT TO GRAPH (AdminUPN pattern)
# -----------------------------
$Scopes = @(
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "UserAuthenticationMethod.ReadWrite.All",
    "User.RevokeSessions.All",
    "Group.Read.All",
    "Organization.Read.All"
)

# Prompt for AdminUPN if not supplied (matches EXO style)
if (-not $AdminUPN) {
    $AdminUPN = Read-Host "Enter Entra tenant admin UPN to sign in with"
}
if (-not $AdminUPN) { throw "AdminUPN is required." }

# Best effort to prevent WAM from silently preferring the current Windows account
# (This variable is respected by Azure.Identity in many environments.)
$env:AZURE_IDENTITY_DISABLE_WAM = "true"

$connectParams = @{
    Scopes      = $Scopes
    ErrorAction = 'Stop'
}

# Best effort: LoginHint if supported by this module version
try {
    $connectCmd = Get-Command Connect-MgGraph -ErrorAction Stop
    if ($connectCmd.Parameters.ContainsKey('LoginHint')) {
        $connectParams['LoginHint'] = $AdminUPN
        Write-Host "Login hint set to: $AdminUPN" -ForegroundColor DarkCyan
    } else {
        Write-Host "This Graph module does not support -LoginHint. Select $AdminUPN manually in the sign-in prompt." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not inspect Connect-MgGraph parameters; continuing with interactive sign-in." -ForegroundColor Yellow
}

Invoke-GraphWithRetry { Connect-MgGraph @connectParams } | Out-Null
$ctx = Get-MgContext
Write-Host "Connected as $($ctx.Account) to TenantId $($ctx.TenantId)" -ForegroundColor Green

# Hard enforcement: abort if signed-in account is not the admin UPN provided
if ($ctx.Account -ne $AdminUPN) {
    Disconnect-MgGraph -ErrorAction SilentlyContinue
    throw "Signed in as '$($ctx.Account)' but expected '$AdminUPN'. Re-run and select the correct admin account."
}

# Tenant display name for logging (best effort)
$TenantDisplayName = $null
try {
    $org = Invoke-GraphWithRetry { Get-MgOrganization -ErrorAction Stop }
    if ($org -is [System.Array]) { $TenantDisplayName = $org[0].DisplayName } else { $TenantDisplayName = $org.DisplayName }
    if ($TenantDisplayName) { Write-Host "Tenant: $TenantDisplayName" -ForegroundColor Green }
} catch {
    Write-Host "Could not read organization display name (continuing): $($_.Exception.Message)" -ForegroundColor Yellow
}

# -----------------------------
# ACTION LOG (CSV)
# -----------------------------
$RunId = [guid]::NewGuid()
$ActionLog = New-Object System.Collections.Generic.List[object]

function Add-ActionLogEntry {
    param(
        [string]$UserPrincipalName,
        [string]$UserId,
        [string]$Action,
        [string]$Status,
        [string]$Details = ""
    )
    if ($NoActionLog) { return }

    $ActionLog.Add([pscustomobject]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
        RunId        = $RunId
        TenantId     = $ctx.TenantId
        TenantName   = $TenantDisplayName
        Operator     = $ctx.Account
        TargetUPN    = $UserPrincipalName
        TargetId     = $UserId
        Action       = $Action
        Status       = $Status
        Details      = $Details
    })
}

function Save-ActionLog {
    if ($NoActionLog) { return }
    if ($ActionLog.Count -eq 0) { return }

    $dir = Split-Path -Parent $ActionLogPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $ActionLog | Export-Csv -NoTypeInformation -Path $ActionLogPath -Force
    Write-Host "Action log exported to: $ActionLogPath" -ForegroundColor Green
}

# -----------------------------
# HELPERS
# -----------------------------
function New-RandomPassword {
    param([ValidateRange(8,128)][int]$Length = 20)

    $upper   = "ABCDEFGHJKLMNPQRSTUVWXYZ".ToCharArray()
    $lower   = "abcdefghijkmnopqrstuvwxyz".ToCharArray()
    $digits  = "23456789".ToCharArray()
    $symbols = "!@#$%^&*()-_=+[]{}:,.?".ToCharArray()
    $all     = ($upper + $lower + $digits + $symbols)

    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

    function Get-RngInt([int]$maxExclusive) {
        $b = New-Object byte[] 4
        do {
            $rng.GetBytes($b)
            $v = [BitConverter]::ToUInt32($b,0)
        } while ($v -ge ([uint32]::MaxValue - ([uint32]::MaxValue % [uint32]$maxExclusive)))
        return [int]($v % $maxExclusive)
    }

    $chars = New-Object char[] $Length

    # Force complexity
    $chars[0] = $upper[(Get-RngInt $upper.Length)]
    $chars[1] = $lower[(Get-RngInt $lower.Length)]
    $chars[2] = $digits[(Get-RngInt $digits.Length)]
    $chars[3] = $symbols[(Get-RngInt $symbols.Length)]

    for ($i = 4; $i -lt $Length; $i++) {
        $chars[$i] = $all[(Get-RngInt $all.Length)]
    }

    # Fisher-Yates shuffle
    for ($i = $chars.Length - 1; $i -gt 0; $i--) {
        $j = Get-RngInt ($i + 1)
        $tmp = $chars[$i]
        $chars[$i] = $chars[$j]
        $chars[$j] = $tmp
    }

    -join $chars
}

function Get-UpnPrefix {
    param([string]$Upn)
    if (-not $Upn) { return $null }
    ($Upn -split "@")[0].ToLowerInvariant()
}

function Remove-TapMethod {
    param([string]$UserId, [string]$MethodId)

    $cmd = Get-Command Remove-MgUserAuthenticationTemporaryAccessPassAuthenticationMethod -ErrorAction SilentlyContinue
    if ($cmd) {
        Invoke-GraphWithRetry { & $cmd.Name -UserId $UserId -TemporaryAccessPassAuthenticationMethodId $MethodId } | Out-Null
        return
    }

    $cmd = Get-Command Remove-MgUserAuthenticationTemporaryAccessPassMethod -ErrorAction SilentlyContinue
    if ($cmd) {
        if ($cmd.Parameters.Keys -contains 'TemporaryAccessPassAuthenticationMethodId') {
            Invoke-GraphWithRetry { & $cmd.Name -UserId $UserId -TemporaryAccessPassAuthenticationMethodId $MethodId } | Out-Null
            return
        }
        if ($cmd.Parameters.Keys -contains 'TemporaryAccessPassMethodId') {
            Invoke-GraphWithRetry { & $cmd.Name -UserId $UserId -TemporaryAccessPassMethodId $MethodId } | Out-Null
            return
        }
    }

    $v = (Get-Module Microsoft.Graph.Users.Actions -ErrorAction SilentlyContinue).Version
    throw "No compatible TAP removal cmdlet found. Microsoft.Graph.Users.Actions version: $v"
}

function Get-ExcludedUserIdsFromGroups {
    param([string[]]$GroupIds)

    $GroupIds = Normalize-GroupIds $GroupIds
    if (-not $GroupIds -or $GroupIds.Count -eq 0) {
        return [System.Collections.Generic.HashSet[string]]::new()
    }

    $excluded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($gid in $GroupIds) {
        if (-not $gid) { continue }
        Write-Host "Resolving exclusion group members: $gid" -ForegroundColor DarkCyan
        try {
            $members = Invoke-GraphWithRetry { Get-MgGroupMember -GroupId $gid -All -Property "id,@odata.type" }
            foreach ($m in $members) {
                $t = $m.AdditionalProperties.'@odata.type'
                if ($t -eq '#microsoft.graph.user' -and $m.Id) {
                    [void]$excluded.Add($m.Id)
                }
            }
        }
        catch {
            Write-Host "  -> Failed to read members for group $gid : $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    $excluded
}

function Get-TargetUsers {
    param(
        [bool]$EnabledOnly,
        [bool]$MembersOnly,
        [bool]$LicensedOnly,
        [string[]]$ExcludeGroupIds,
        [string[]]$BreakGlassUpnPrefixes
    )

    $excludedIds = Get-ExcludedUserIdsFromGroups -GroupIds $ExcludeGroupIds

    $filterParts = @()
    if ($EnabledOnly)  { $filterParts += "accountEnabled eq true" }
    if ($MembersOnly)  { $filterParts += "userType eq 'Member'" }
    if ($LicensedOnly) { $filterParts += "assignedLicenses/`$count ne 0" }
    $filter = ($filterParts -join " and ")

    $properties = "id,userPrincipalName,displayName,userType,accountEnabled,assignedLicenses,onPremisesSyncEnabled"

    try {
        $countVar = 0
        $users = Invoke-GraphWithRetry {
            Get-MgUser -All -ConsistencyLevel eventual -CountVariable countVar -Filter $filter -Property $properties
        }
        Write-Host "Target users found (server-side filter): $countVar" -ForegroundColor Green
    }
    catch {
        Write-Host "Server-side filter not supported; falling back to client-side filtering..." -ForegroundColor Yellow
        $users = Invoke-GraphWithRetry { Get-MgUser -All -Property $properties }

        if ($EnabledOnly)  { $users = $users | Where-Object {$_.AccountEnabled -eq $true} }
        if ($MembersOnly)  { $users = $users | Where-Object {$_.UserType -eq 'Member'} }
        if ($LicensedOnly) { $users = $users | Where-Object {$_.AssignedLicenses.Count -gt 0} }

        Write-Host "Target users found (client-side filter): $($users.Count)" -ForegroundColor Green
    }

    $final = New-Object System.Collections.Generic.List[object]
    $bgSkipped = 0
    $grpSkipped = 0

    foreach ($u in $users) {
        if (-not $u.UserPrincipalName) { continue }

        $prefix = Get-UpnPrefix $u.UserPrincipalName
        if ($BreakGlassUpnPrefixes -contains $prefix) {
            $bgSkipped++
            continue
        }

        if ($excludedIds.Count -gt 0 -and $excludedIds.Contains($u.Id)) {
            $grpSkipped++
            continue
        }

        $final.Add($u)
    }

    [pscustomobject]@{
        Users                    = $final.ToArray()
        BreakGlassSkipped        = $bgSkipped
        GroupExcludedSkipped     = $grpSkipped
        ExcludedGroupUserIdCount = $excludedIds.Count
    }
}

# -----------------------------
# OPTIONAL GUI (DEFAULT)
# -----------------------------
function Show-IrGui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $CONFIRM_PHRASE = "RESET"

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Entra IR Containment Toolkit"
    $form.Size = New-Object System.Drawing.Size(820, 650)
    $form.StartPosition = "CenterScreen"
    $form.Topmost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Select actions and targeting. Use Preview Targets before running."
    $lbl.AutoSize = $true
    $lbl.Location = New-Object System.Drawing.Point(10, 10)
    $form.Controls.Add($lbl)

    # Targeting group
    $grpTarget = New-Object System.Windows.Forms.GroupBox
    $grpTarget.Text = "Targeting"
    $grpTarget.Size = New-Object System.Drawing.Size(780, 150)
    $grpTarget.Location = New-Object System.Drawing.Point(10, 35)
    $form.Controls.Add($grpTarget)

    $cbEnabledOnly = New-Object System.Windows.Forms.CheckBox
    $cbEnabledOnly.Text = "Enabled accounts only"
    $cbEnabledOnly.Location = New-Object System.Drawing.Point(12, 25)
    $cbEnabledOnly.Checked = $EnabledOnly
    $grpTarget.Controls.Add($cbEnabledOnly)

    $cbMembersOnly = New-Object System.Windows.Forms.CheckBox
    $cbMembersOnly.Text = "Members only (exclude Guests)"
    $cbMembersOnly.Location = New-Object System.Drawing.Point(240, 25)
    $cbMembersOnly.Checked = $MembersOnly
    $grpTarget.Controls.Add($cbMembersOnly)

    $cbLicensedOnly = New-Object System.Windows.Forms.CheckBox
    $cbLicensedOnly.Text = "Licensed only"
    $cbLicensedOnly.Location = New-Object System.Drawing.Point(520, 25)
    $cbLicensedOnly.Checked = $LicensedOnly
    $grpTarget.Controls.Add($cbLicensedOnly)

    $lblBg = New-Object System.Windows.Forms.Label
    $lblBg.Text = "Break-glass UPN prefixes: $($BreakGlassUpnPrefixes -join ', ')"
    $lblBg.AutoSize = $true
    $lblBg.Location = New-Object System.Drawing.Point(12, 55)
    $grpTarget.Controls.Add($lblBg)

    $lblExGrp = New-Object System.Windows.Forms.Label
    $lblExGrp.Text = "Exclude members of Group ObjectId(s) (comma/space separated):"
    $lblExGrp.AutoSize = $true
    $lblExGrp.Location = New-Object System.Drawing.Point(12, 85)
    $grpTarget.Controls.Add($lblExGrp)

    $tbExcludeGroups = New-Object System.Windows.Forms.TextBox
    $tbExcludeGroups.Size = New-Object System.Drawing.Size(740, 22)
    $tbExcludeGroups.Location = New-Object System.Drawing.Point(12, 105)
    $tbExcludeGroups.Text = ($ExcludeGroupIds -join ",")
    $grpTarget.Controls.Add($tbExcludeGroups)

    # Actions group
    $grpActions = New-Object System.Windows.Forms.GroupBox
    $grpActions.Text = "Actions"
    $grpActions.Size = New-Object System.Drawing.Size(780, 220)
    $grpActions.Location = New-Object System.Drawing.Point(10, 195)
    $form.Controls.Add($grpActions)

    $cbDisable = New-Object System.Windows.Forms.CheckBox
    $cbDisable.Text = "Disable Accounts (accountEnabled = false) - strong containment"
    $cbDisable.Location = New-Object System.Drawing.Point(12, 25)
    $cbDisable.Checked = $false
    $grpActions.Controls.Add($cbDisable)

    $cbRevoke = New-Object System.Windows.Forms.CheckBox
    $cbRevoke.Text = "Revoke Sessions (refresh tokens)"
    $cbRevoke.Location = New-Object System.Drawing.Point(12, 55)
    $cbRevoke.Checked = $true
    $grpActions.Controls.Add($cbRevoke)

    $cbMfa = New-Object System.Windows.Forms.CheckBox
    $cbMfa.Text = "Reset MFA Methods (removes supported auth methods; some types non-removable)"
    $cbMfa.Location = New-Object System.Drawing.Point(12, 85)
    $cbMfa.Checked = $true
    $grpActions.Controls.Add($cbMfa)

    $cbPwd = New-Object System.Windows.Forms.CheckBox
    $cbPwd.Text = "Reset Passwords (cloud-only; hybrid-synced skipped by default)"
    $cbPwd.Location = New-Object System.Drawing.Point(12, 115)
    $cbPwd.Checked = $false
    $grpActions.Controls.Add($cbPwd)

    $cbSkipHybrid = New-Object System.Windows.Forms.CheckBox
    $cbSkipHybrid.Text = "Skip hybrid-synced users for password reset (recommended)"
    $cbSkipHybrid.Location = New-Object System.Drawing.Point(32, 140)
    $cbSkipHybrid.Checked = $SkipHybridPasswordReset
    $grpActions.Controls.Add($cbSkipHybrid)

    # Password settings (enabled only when ResetPasswords checked)
    $lblPwdLen = New-Object System.Windows.Forms.Label
    $lblPwdLen.Text = "Password length:"
    $lblPwdLen.AutoSize = $true
    $lblPwdLen.Location = New-Object System.Drawing.Point(420, 118)
    $grpActions.Controls.Add($lblPwdLen)

    $nudPwdLen = New-Object System.Windows.Forms.NumericUpDown
    $nudPwdLen.Minimum = 8
    $nudPwdLen.Maximum = 128
    $nudPwdLen.Value = [decimal]$PasswordLength
    $nudPwdLen.Location = New-Object System.Drawing.Point(530, 115)
    $nudPwdLen.Width = 80
    $grpActions.Controls.Add($nudPwdLen)

    $cbForceChange = New-Object System.Windows.Forms.CheckBox
    $cbForceChange.Text = "Force change at next sign-in"
    $cbForceChange.Location = New-Object System.Drawing.Point(420, 145)
    $cbForceChange.Checked = $ForceChangePasswordNextSignIn
    $grpActions.Controls.Add($cbForceChange)

    $togglePwdControls = {
        $enabled = [bool]$cbPwd.Checked
        $cbSkipHybrid.Enabled = $enabled
        $nudPwdLen.Enabled = $enabled
        $cbForceChange.Enabled = $enabled
    }
    $cbPwd.Add_CheckedChanged($togglePwdControls)
    & $togglePwdControls

    # Safety & output group
    $grpOps = New-Object System.Windows.Forms.GroupBox
    $grpOps.Text = "Safety and Output"
    $grpOps.Size = New-Object System.Drawing.Size(780, 150)
    $grpOps.Location = New-Object System.Drawing.Point(10, 425)
    $form.Controls.Add($grpOps)

    $cbWhatIf = New-Object System.Windows.Forms.CheckBox
    $cbWhatIf.Text = "WhatIf (simulate; no changes)"
    $cbWhatIf.Location = New-Object System.Drawing.Point(12, 25)
    $cbWhatIf.Checked = $true
    $grpOps.Controls.Add($cbWhatIf)

    $cbLog = New-Object System.Windows.Forms.CheckBox
    $cbLog.Text = "Write CSV action log"
    $cbLog.Location = New-Object System.Drawing.Point(12, 50)
    $cbLog.Checked = -not $NoActionLog
    $grpOps.Controls.Add($cbLog)

    $lblLogPath = New-Object System.Windows.Forms.Label
    $lblLogPath.Text = "Log path: $ActionLogPath"
    $lblLogPath.AutoSize = $true
    $lblLogPath.Location = New-Object System.Drawing.Point(32, 72)
    $grpOps.Controls.Add($lblLogPath)

    $cbExportPw = New-Object System.Windows.Forms.CheckBox
    $cbExportPw.Text = "Export temporary passwords to CSV (PLAINTEXT - high risk)"
    $cbExportPw.Location = New-Object System.Drawing.Point(420, 25)
    $cbExportPw.Checked = $ExportPasswordResets
    $grpOps.Controls.Add($cbExportPw)

    $lblPwPath = New-Object System.Windows.Forms.Label
    $lblPwPath.Text = "Password export: $PasswordExportPath"
    $lblPwPath.AutoSize = $true
    $lblPwPath.Location = New-Object System.Drawing.Point(440, 50)
    $grpOps.Controls.Add($lblPwPath)

    # Confirm-to-run (phrase gate)
    $lblConfirm = New-Object System.Windows.Forms.Label
    $lblConfirm.Text = "Confirm to Run: type '$CONFIRM_PHRASE' (required when WhatIf is OFF)"
    $lblConfirm.AutoSize = $true
    $lblConfirm.Location = New-Object System.Drawing.Point(12, 100)
    $grpOps.Controls.Add($lblConfirm)

    $tbConfirm = New-Object System.Windows.Forms.TextBox
    $tbConfirm.Size = New-Object System.Drawing.Size(200, 22)
    $tbConfirm.Location = New-Object System.Drawing.Point(420, 97)
    $tbConfirm.Text = ""
    $grpOps.Controls.Add($tbConfirm)

    $lblConfirmState = New-Object System.Windows.Forms.Label
    $lblConfirmState.Text = "Run is locked (turn off WhatIf and type RESET)"
    $lblConfirmState.AutoSize = $true
    $lblConfirmState.Location = New-Object System.Drawing.Point(630, 100)
    $lblConfirmState.ForeColor = [System.Drawing.Color]::DarkRed
    $grpOps.Controls.Add($lblConfirmState)

    # Preview button
    $btnPreview = New-Object System.Windows.Forms.Button
    $btnPreview.Text = "Preview Targets"
    $btnPreview.Location = New-Object System.Drawing.Point(10, 585)
    $btnPreview.Size = New-Object System.Drawing.Size(140, 28)
    $form.Controls.Add($btnPreview)

    # Run/Cancel buttons
    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "Run"
    $btnOk.Location = New-Object System.Drawing.Point(650, 585)
    $btnOk.Size = New-Object System.Drawing.Size(70, 28)
    $btnOk.Enabled = $true
    $btnOk.Add_Click({ $form.Tag = "OK"; $form.Close() })
    $form.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(730, 585)
    $btnCancel.Size = New-Object System.Drawing.Size(70, 28)
    $btnCancel.Add_Click({ $form.Tag = "CANCEL"; $form.Close() })
    $form.Controls.Add($btnCancel)

    # Gate logic: if WhatIf checked -> Run enabled. If WhatIf unchecked -> require phrase.
    $updateRunGate = {
        $whatIf = [bool]$cbWhatIf.Checked
        $phraseOk = ($tbConfirm.Text.Trim().ToUpperInvariant() -eq $CONFIRM_PHRASE)

        if ($whatIf) {
            $btnOk.Enabled = $true
            $lblConfirmState.Text = "WhatIf ON (safe simulation) - Run enabled"
            $lblConfirmState.ForeColor = [System.Drawing.Color]::DarkGreen
        }
        else {
            if ($phraseOk) {
                $btnOk.Enabled = $true
                $lblConfirmState.Text = "Confirmed - Run enabled"
                $lblConfirmState.ForeColor = [System.Drawing.Color]::DarkGreen
            }
            else {
                $btnOk.Enabled = $false
                $lblConfirmState.Text = "Run locked - type RESET"
                $lblConfirmState.ForeColor = [System.Drawing.Color]::DarkRed
            }
        }
    }

    $cbWhatIf.Add_CheckedChanged($updateRunGate)
    $tbConfirm.Add_TextChanged($updateRunGate)
    & $updateRunGate

    $btnPreview.Add_Click({
        try {
            $ex = Normalize-GroupIds @($tbExcludeGroups.Text)

            $res = Get-TargetUsers `
                -EnabledOnly ([bool]$cbEnabledOnly.Checked) `
                -MembersOnly ([bool]$cbMembersOnly.Checked) `
                -LicensedOnly ([bool]$cbLicensedOnly.Checked) `
                -ExcludeGroupIds $ex `
                -BreakGlassUpnPrefixes $BreakGlassUpnPrefixes

            $users = $res.Users
            $count = $users.Count
            $sample = ($users | Select-Object -First 25 | ForEach-Object { $_.UserPrincipalName }) -join "`r`n"

            $msg = "Targets: $count`r`n" +
                   "Break-glass skipped: $($res.BreakGlassSkipped)`r`n" +
                   "Group-excluded skipped: $($res.GroupExcludedSkipped)`r`n" +
                   "Excluded group userId set size: $($res.ExcludedGroupUserIdCount)`r`n`r`n" +
                   "First 25:`r`n$sample"

            [System.Windows.Forms.MessageBox]::Show($msg, "Target Preview", "OK", "Information") | Out-Null
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("$($_)", "Preview Failed", "OK", "Error") | Out-Null
        }
    })

    $form.ShowDialog() | Out-Null
    if ($form.Tag -ne "OK") { return $null }

    return @{
        # actions
        DisableAccounts      = [bool]$cbDisable.Checked
        RevokeSessions       = [bool]$cbRevoke.Checked
        ResetMfa             = [bool]$cbMfa.Checked
        ResetPasswords       = [bool]$cbPwd.Checked
        SkipHybridPwd        = [bool]$cbSkipHybrid.Checked

        # password settings
        PasswordLength       = [int]$nudPwdLen.Value
        ForceChangeNext      = [bool]$cbForceChange.Checked

        # targeting
        EnabledOnly          = [bool]$cbEnabledOnly.Checked
        MembersOnly          = [bool]$cbMembersOnly.Checked
        LicensedOnly         = [bool]$cbLicensedOnly.Checked
        ExcludeGroupIds      = Normalize-GroupIds @($tbExcludeGroups.Text)

        # ops/output
        WhatIf               = [bool]$cbWhatIf.Checked
        WriteLog             = [bool]$cbLog.Checked
        ExportPasswordResets = [bool]$cbExportPw.Checked
    }
}

# GUI is DEFAULT unless -NoGui
if (-not $NoGui) {
    $sel = Show-IrGui
    if (-not $sel) { Write-Host "Cancelled." -ForegroundColor Yellow; return }

    $DisableAccounts = $sel.DisableAccounts
    $RevokeSessions  = $sel.RevokeSessions
    $ResetMfa        = $sel.ResetMfa
    $ResetPasswords  = $sel.ResetPasswords
    $SkipHybridPasswordReset = $sel.SkipHybridPwd

    $PasswordLength = $sel.PasswordLength
    $ForceChangePasswordNextSignIn = $sel.ForceChangeNext

    $EnabledOnly  = $sel.EnabledOnly
    $MembersOnly  = $sel.MembersOnly
    $LicensedOnly = $sel.LicensedOnly
    $ExcludeGroupIds = $sel.ExcludeGroupIds

    $ExportPasswordResets = $sel.ExportPasswordResets

    if (-not $sel.WriteLog) { $NoActionLog = $true }
    if ($sel.WhatIf) { $WhatIfPreference = $true }
}

# If no actions selected, default to common containment pair
if (-not ($DisableAccounts -or $RevokeSessions -or $ResetMfa -or $ResetPasswords)) {
    $RevokeSessions = $true
    $ResetMfa = $true
    Write-Host "No actions selected; defaulting to RevokeSessions + ResetMfa." -ForegroundColor Yellow
}

# If WhatIf is enabled, don't export passwords (avoid creating misleading plaintext files)
if ($WhatIfPreference -and $ExportPasswordResets) {
    Write-Host "WhatIf is enabled - password export will be skipped." -ForegroundColor Yellow
    $ExportPasswordResets = $false
}

# Optional password export buffer (separate from action log)
$passwordOut = New-Object System.Collections.Generic.List[object]

# -----------------------------
# GET TARGET USERS
# -----------------------------
$targetResult = Get-TargetUsers `
    -EnabledOnly $EnabledOnly `
    -MembersOnly $MembersOnly `
    -LicensedOnly $LicensedOnly `
    -ExcludeGroupIds $ExcludeGroupIds `
    -BreakGlassUpnPrefixes $BreakGlassUpnPrefixes

$users = $targetResult.Users
Write-Host "Final targets: $($users.Count) | Break-glass skipped: $($targetResult.BreakGlassSkipped) | Group-excluded skipped: $($targetResult.GroupExcludedSkipped)" -ForegroundColor Green

# Log run configuration
Add-ActionLogEntry -UserPrincipalName "" -UserId "" -Action "RunConfig" -Status "Info" -Details ("EnabledOnly={0}; MembersOnly={1}; LicensedOnly={2}; ExcludeGroupIds={3}; SkipHybridPwd={4}; PasswordLength={5}; ForceChangeNext={6}; WhatIf={7}; PerUserDelayMs={8}; AdminUPN={9}" -f `
    $EnabledOnly, $MembersOnly, $LicensedOnly, ($ExcludeGroupIds -join ','), $SkipHybridPasswordReset, $PasswordLength, $ForceChangePasswordNextSignIn, $WhatIfPreference, $PerUserDelayMs, $AdminUPN)

if ($ExcludeGroupIds.Count -gt 0) {
    Add-ActionLogEntry -UserPrincipalName "" -UserId "" -Action "RunConfig" -Status "Info" -Details "ExcludedUserIdSetSize=$($targetResult.ExcludedGroupUserIdCount)"
}

# -----------------------------
# HEADLESS SAFETY CONFIRMATION
# -----------------------------
if ($NoGui -and -not $WhatIfPreference) {
    Write-Host ""
    Write-Host "WARNING: You are about to execute LIVE containment actions." -ForegroundColor Red
    Write-Host "Tenant:  $TenantDisplayName ($($ctx.TenantId))"
    Write-Host "Operator: $($ctx.Account)"
    Write-Host "Targets:  $($users.Count)"
    Write-Host "Actions:  Disable=$DisableAccounts Revoke=$RevokeSessions ResetMfa=$ResetMfa ResetPwd=$ResetPasswords" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Type RESET to continue"
    if ($confirm.Trim().ToUpperInvariant() -ne "RESET") {
        Write-Host "Confirmation failed. Exiting." -ForegroundColor Yellow
        Add-ActionLogEntry -UserPrincipalName "" -UserId "" -Action "Run" -Status "Aborted" -Details "Headless confirmation failed"
        Save-ActionLog
        return
    }
}

# -----------------------------
# PROCESS USERS
# -----------------------------
$processed = 0

try {
    foreach ($user in $users) {
        $upn = $user.UserPrincipalName
        if (-not $upn) { continue }

        if ($PerUserDelayMs -gt 0) { Start-Sleep -Milliseconds $PerUserDelayMs }

        Write-Host "Processing: $upn" -ForegroundColor Cyan

        # 0) Disable Accounts
        if ($DisableAccounts) {
            try {
                if ($PSCmdlet.ShouldProcess($upn, "Disable account (accountEnabled=false)")) {
                    Invoke-GraphWithRetry { Update-MgUser -UserId $user.Id -AccountEnabled:$false } | Out-Null
                    Write-Host "  -> Account disabled" -ForegroundColor Gray
                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "DisableAccount" -Status "Success"
                } else {
                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "DisableAccount" -Status "Skipped" -Details "ShouldProcess returned false (WhatIf/Not confirmed)"
                }
            }
            catch {
                Write-Host "  -> Failed to disable account: $_" -ForegroundColor Red
                Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "DisableAccount" -Status "Failed" -Details "$_"
            }
        }

        # 1) Revoke Sessions
        if ($RevokeSessions) {
            try {
                if ($PSCmdlet.ShouldProcess($upn, "Revoke sign-in sessions")) {
                    Invoke-GraphWithRetry { Revoke-MgUserSignInSession -UserId $user.Id } | Out-Null
                    Write-Host "  -> Sessions revoked" -ForegroundColor Gray
                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "RevokeSessions" -Status "Success"
                } else {
                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "RevokeSessions" -Status "Skipped" -Details "ShouldProcess returned false (WhatIf/Not confirmed)"
                }
            }
            catch {
                Write-Host "  -> Failed to revoke sessions: $_" -ForegroundColor Red
                Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "RevokeSessions" -Status "Failed" -Details "$_"
            }
        }

        # 2) Reset Passwords
        if ($ResetPasswords) {
            if ($SkipHybridPasswordReset -and $user.OnPremisesSyncEnabled -eq $true) {
                Write-Host "  -> Skipping password reset (hybrid-synced: reset in on-prem AD and sync)" -ForegroundColor Yellow
                Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetPassword" -Status "Skipped" -Details "Hybrid-synced user (OnPremisesSyncEnabled=true)"
            }
            else {
                try {
                    $newPwd = New-RandomPassword -Length $PasswordLength

                    if ($PSCmdlet.ShouldProcess($upn, "Reset password (ForceChangeNextSignIn=$ForceChangePasswordNextSignIn)")) {
                        Invoke-GraphWithRetry {
                            Update-MgUser -UserId $user.Id -PasswordProfile @{
                                Password = $newPwd
                                ForceChangePasswordNextSignIn = $ForceChangePasswordNextSignIn
                            }
                        } | Out-Null

                        Write-Host "  -> Password reset (ForceChangeNextSignIn=$ForceChangePasswordNextSignIn)" -ForegroundColor Gray
                        Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetPassword" -Status "Success" -Details "ForceChangePasswordNextSignIn=$ForceChangePasswordNextSignIn"
                    }
                    else {
                        Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetPassword" -Status "Skipped" -Details "ShouldProcess returned false (WhatIf/Not confirmed)"
                    }

                    if ($ExportPasswordResets) {
                        $passwordOut.Add([pscustomobject]@{
                            UserPrincipalName = $upn
                            TemporaryPassword = $newPwd
                        })
                    }
                }
                catch {
                    Write-Host "  -> Failed to reset password: $_" -ForegroundColor Red
                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetPassword" -Status "Failed" -Details "$_"
                }
            }
        }

        # 3) Reset MFA Methods
        if ($ResetMfa) {
            $removed = 0
            $skipped = 0
            $failed  = 0

            try {
                $methods = Invoke-GraphWithRetry { Get-MgUserAuthenticationMethod -UserId $user.Id }

                foreach ($method in $methods) {
                    $odataType = $method.AdditionalProperties.'@odata.type'
                    $methodId  = $method.Id

                    try {
                        switch ($odataType) {
                            "#microsoft.graph.phoneAuthenticationMethod" {
                                if ($PSCmdlet.ShouldProcess($upn, "Remove phone auth method $methodId")) {
                                    Invoke-GraphWithRetry { Remove-MgUserAuthenticationPhoneMethod -UserId $user.Id -PhoneAuthenticationMethodId $methodId } | Out-Null
                                    $removed++
                                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Phone" -Status "Success" -Details $methodId
                                } else { $skipped++; Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Phone" -Status "Skipped" -Details "ShouldProcess=false $methodId" }
                            }

                            "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                                if ($PSCmdlet.ShouldProcess($upn, "Remove Authenticator method $methodId")) {
                                    Invoke-GraphWithRetry { Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $user.Id -MicrosoftAuthenticatorAuthenticationMethodId $methodId } | Out-Null
                                    $removed++
                                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Authenticator" -Status "Success" -Details $methodId
                                } else { $skipped++; Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Authenticator" -Status "Skipped" -Details "ShouldProcess=false $methodId" }
                            }

                            "#microsoft.graph.emailAuthenticationMethod" {
                                if ($PSCmdlet.ShouldProcess($upn, "Remove email method $methodId")) {
                                    Invoke-GraphWithRetry { Remove-MgUserAuthenticationEmailMethod -UserId $user.Id -EmailAuthenticationMethodId $methodId } | Out-Null
                                    $removed++
                                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Email" -Status "Success" -Details $methodId
                                } else { $skipped++; Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Email" -Status "Skipped" -Details "ShouldProcess=false $methodId" }
                            }

                            "#microsoft.graph.fido2AuthenticationMethod" {
                                if ($PSCmdlet.ShouldProcess($upn, "Remove FIDO2 method $methodId")) {
                                    Invoke-GraphWithRetry { Remove-MgUserAuthenticationFido2Method -UserId $user.Id -Fido2AuthenticationMethodId $methodId } | Out-Null
                                    $removed++
                                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:FIDO2" -Status "Success" -Details $methodId
                                } else { $skipped++; Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:FIDO2" -Status "Skipped" -Details "ShouldProcess=false $methodId" }
                            }

                            "#microsoft.graph.softwareOathAuthenticationMethod" {
                                if ($PSCmdlet.ShouldProcess($upn, "Remove software OATH method $methodId")) {
                                    Invoke-GraphWithRetry { Remove-MgUserAuthenticationSoftwareOathMethod -UserId $user.Id -SoftwareOathMethodId $methodId } | Out-Null
                                    $removed++
                                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:SoftwareOATH" -Status "Success" -Details $methodId
                                } else { $skipped++; Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:SoftwareOATH" -Status "Skipped" -Details "ShouldProcess=false $methodId" }
                            }

                            "#microsoft.graph.temporaryAccessPassAuthenticationMethod" {
                                if ($PSCmdlet.ShouldProcess($upn, "Remove TAP method $methodId")) {
                                    Remove-TapMethod -UserId $user.Id -MethodId $methodId
                                    $removed++
                                    Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:TAP" -Status "Success" -Details $methodId
                                } else { $skipped++; Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:TAP" -Status "Skipped" -Details "ShouldProcess=false $methodId" }
                            }

                            default {
                                $skipped++
                                Write-Host "  -> Skipping unsupported/non-removable auth method: $odataType" -ForegroundColor DarkYellow
                                Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Unsupported" -Status "Skipped" -Details $odataType
                            }
                        }
                    }
                    catch {
                        $failed++
                        Write-Host "  -> Failed removing method $odataType ($methodId): $_" -ForegroundColor Red
                        Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Method" -Status "Failed" -Details "$odataType $methodId :: $_"
                    }
                }

                Write-Host "  -> MFA methods processed (see log for skipped/non-removable types)" -ForegroundColor Gray
                Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA:Summary" -Status "Success" -Details "Removed=$removed Skipped=$skipped Failed=$failed"
            }
            catch {
                Write-Host "  -> Failed to reset MFA: $_" -ForegroundColor Red
                Add-ActionLogEntry -UserPrincipalName $upn -UserId $user.Id -Action "ResetMFA" -Status "Failed" -Details "$_"
            }
        }

        $processed++
        if (-not $NoActionLog -and ($processed % 50 -eq 0)) { Save-ActionLog }
    }
}
finally {
    if ($ExportPasswordResets -and $passwordOut.Count -gt 0) {
        $dir2 = Split-Path -Parent $PasswordExportPath
        if ($dir2 -and -not (Test-Path $dir2)) { New-Item -ItemType Directory -Path $dir2 -Force | Out-Null }

        $passwordOut | Export-Csv -NoTypeInformation -Path $PasswordExportPath -Force
        Write-Host "Password export written to: $PasswordExportPath" -ForegroundColor Green
        Write-Host "NOTE: File contains PLAINTEXT passwords. Distribute via a secure channel only." -ForegroundColor Yellow
    }

    Save-ActionLog
    Write-Host "Completed processing all target users (break-glass and excluded groups removed)." -ForegroundColor Green
}
