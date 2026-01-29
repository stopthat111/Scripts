# ======================================================================
# Inbox Rule IoC Audit
# ======================================================================

# ---------------- CLEAN SESSION ----------------
Get-PSSession | Remove-PSSession -ErrorAction SilentlyContinue
Get-Module Exchange* | Remove-Module -Force -ErrorAction SilentlyContinue
Import-Module ExchangeOnlineManagement -Force

# ---------------- PATHS ----------------
$BasePath = "C:\Temp"
$CsvOut   = "$BasePath\InboxRules_IoC_WithGeoIP.csv"
$TxtOut   = "$BasePath\AllInboxRules.txt"
$LogFile  = "$BasePath\InboxRules_IoC_Log.txt"

if (-not (Test-Path $BasePath)) { New-Item $BasePath -ItemType Directory | Out-Null }
foreach ($f in @($CsvOut,$TxtOut,$LogFile)) {
    if (-not (Test-Path $f)) { New-Item $f -ItemType File | Out-Null }
}

# ---------------- AUTH ----------------
$AdminUPN = Read-Host "Enter Exchange Online admin UPN"
Connect-ExchangeOnline -UserPrincipalName $AdminUPN -ShowProgress:$true -ShowBanner:$false

# ---------------- MODE CHECK ----------------
$Cmd = Get-Command Get-InboxRule
$IsRPS = $Cmd.ModuleName -like "tmpEXO*"
Write-Host "Exchange Mode: $(if($IsRPS){'RPS (Legacy)'}else{'REST'})" -ForegroundColor Yellow

# ---------------- CONFIG ----------------
$StartDate = (Get-Date).AddDays(-30)
$GeoApi = "https://ipinfo.io/{0}/json"
$Results = @()

# ---------------- MAILBOX ENUM ----------------
$Mailboxes = Get-Mailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox

foreach ($Mailbox in $Mailboxes) {

    $UPN = $Mailbox.UserPrincipalName
    Write-Host "Scanning: $UPN" -ForegroundColor Cyan

    try {
        # ✅ CORRECT: Explicit mailbox identity
        $Rules   = Get-InboxRule -Mailbox $UPN -ErrorAction Stop
        $Folders = Get-MailboxFolderStatistics -Identity $UPN
    }
    catch {
        Add-Content $LogFile "Mailbox scan failed | $UPN | $($_.Exception.Message)"
        continue
    }

    foreach ($Rule in $Rules) {

@"
Mailbox      : $UPN
Rule Name    : $($Rule.Name)
Enabled      : $($Rule.Enabled)
Priority     : $($Rule.Priority)
Description  : $($Rule.Description -replace "`r`n"," ")
ForwardTo    : $($Rule.ForwardTo -join ", ")
RedirectTo   : $($Rule.RedirectTo -join ", ")
MoveToFolder : $($Rule.MoveToFolder)
DeleteMessage: $($Rule.DeleteMessage)
MarkAsRead   : $($Rule.MarkAsRead)
CreatedTime  : $($Rule.WhenCreated)
ModifiedTime : $($Rule.WhenChanged)
--------------------------------------------------------------------------------
"@ | Add-Content $TxtOut

        # Skip old rules
        if ($Rule.WhenCreated -lt $StartDate -and $Rule.WhenChanged -lt $StartDate) { continue }

        $Score = 0
        $Flags = @()

        if ($Rule.ForwardTo -or $Rule.RedirectTo) { $Score+=50; $Flags+="Forward/Redirect" }
        if ($Rule.MarkAsRead) { $Score+=20; $Flags+="Mark As Read" }
        if ($Rule.DeleteMessage) { $Score+=30; $Flags+="Hard Delete" }

        if ($Rule.MoveToFolder) {
            $Folder = $Folders | Where-Object { $_.FolderPath -match "Deleted Items" }
            if ($Folder) { $Score+=30; $Flags+="Move to Deleted Items" }
        }

        # ---------------- AUDIT ----------------
        $RuleTime = if ($Rule.WhenChanged -gt $Rule.WhenCreated) { $Rule.WhenChanged } else { $Rule.WhenCreated }

        $Audit = Search-UnifiedAuditLog `
            -StartDate ($RuleTime.AddMinutes(-60)) `
            -EndDate ($RuleTime.AddMinutes(60)) `
            -UserIds $UPN `
            -Operations New-InboxRule,Set-InboxRule `
            -ResultSize 10 |
            Where-Object { $_.AuditData -match [Regex]::Escape($Rule.Name) } |
            Select-Object -First 1

        $IP=$City=$Region=$Country=$ASN=$null
        if ($Audit) {
            $Data = $Audit.AuditData | ConvertFrom-Json
            $IP = $Data.ClientIP
            if ($IP) {
                try {
                    $Geo = Invoke-RestMethod ($GeoApi -f $IP)
                    $City=$Geo.city; $Region=$Geo.region; $Country=$Geo.country; $ASN=$Geo.org
                } catch {
                    Add-Content $LogFile "GeoIP failed | $IP | $UPN"
                }
            }
        }

        $Results += [PSCustomObject]@{
            Mailbox       = $UPN
            RuleName      = $Rule.Name
            Enabled       = $Rule.Enabled
            ThreatScore   = $Score
            RiskFlags     = ($Flags -join ", ")
            MarkAsRead    = $Rule.MarkAsRead
            DeleteMessage = $Rule.DeleteMessage
            MoveToFolder  = $Rule.MoveToFolder
            SourceIP      = $IP
            IP_City       = $City
            IP_Region     = $Region
            IP_Country    = $Country
            IP_ASN        = $ASN
        }
    }
}

# ---------------- EXPORT ----------------
$Results | Sort-Object ThreatScore -Descending |
    Export-Csv $CsvOut -NoTypeInformation -Encoding UTF8

Write-Host "Scan complete" -ForegroundColor Green
Write-Host "IoC CSV : $CsvOut" -ForegroundColor Yellow
Write-Host "Rules TXT: $TxtOut" -ForegroundColor Yellow
Write-Host "Log File: $LogFile" -ForegroundColor Yellow

Disconnect-ExchangeOnline -Confirm:$false
