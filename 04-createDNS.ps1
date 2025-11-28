[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "網域 FQDN，預設 tcivs.com.tw")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainFqdn = "tcivs.com.tw",

    [Parameter(HelpMessage = "IPv4 網段前兩段，例如 172.16")]
    [ValidatePattern('^\d{1,3}\.\d{1,3}$')]
    [string]$SitePrefix = "172.16",

    [Parameter(HelpMessage = "組別編號（01-99），用於第三段位址")]
    [ValidatePattern('^\d{1,2}$')]
    [string]$XX = "01",

    [Parameter(HelpMessage = "Branch 主機名稱，預設 Branch-XX")]
    [string]$BranchName,

    [Parameter(HelpMessage = "Business/Fedora 主機名稱，預設 Business-XX")]
    [string]$BusinessName,

    [Parameter(HelpMessage = "HR 主機名稱，預設 HR-XX")]
    [string]$HRName,

    [Parameter(HelpMessage = "Customer 主機名稱，預設 Customer-XX")]
    [string]$CustomerName
)

# ===== 共用輸出 =====
function Write-Result {
    param([bool]$Ok, [string]$Message)
    if ($Ok) { Write-Host "[通過] $Message" -ForegroundColor Green }
    else { Write-Host "[失敗] $Message" -ForegroundColor Red }
}

function Write-Warn($msg) { Write-Host "[警告] $msg" -ForegroundColor Yellow }

# ===== 權限檢查 =====
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Result $false "請以系統管理員身分執行此腳本。"
    exit 1
}

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  Windows Server 2022 - 安裝/建立 DNS 正反向解析區並新增主機紀錄" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# ===== 載入模組 =====
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Result $true "已載入 ActiveDirectory 模組"
} catch {
    Write-Result $false "無法載入 ActiveDirectory 模組：$($_.Exception.Message)"
    exit 1
}

try {
    Import-Module DnsServer -ErrorAction Stop
    Write-Result $true "已載入 DnsServer 模組"
} catch {
    Write-Result $false "無法載入 DnsServer 模組：$($_.Exception.Message)"
    exit 1
}

# ===== 確認本機為網域控制站 =====
try {
    $domainInfo = Get-ADDomain -ErrorAction Stop
} catch {
    Write-Result $false "無法取得 AD 網域資訊，請先完成 AD DS 安裝。"
    exit 1
}

$role = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
if ($role -lt 4) {
    Write-Result $false "本機並非網域控制站，請先建立 AD DS。"
    exit 1
}

if ($domainInfo.DNSRoot -ne $DomainFqdn) {
    Write-Warn "目前網域為 $($domainInfo.DNSRoot)，改用此網域建立 DNS 區域。"
    $DomainFqdn = $domainInfo.DNSRoot
}

# ===== 處理組別編號與預設主機名 =====
$xxInt = [int]$XX
$xxStr = $xxInt.ToString()

if ([string]::IsNullOrWhiteSpace($BranchName))   { $BranchName   = "Branch-$xxStr" }
if ([string]::IsNullOrWhiteSpace($BusinessName)) { $BusinessName = "Business-$xxStr" }
if ([string]::IsNullOrWhiteSpace($HRName))       { $HRName       = "HR-$xxStr" }
if ([string]::IsNullOrWhiteSpace($CustomerName)) { $CustomerName = "Customer-$xxStr" }

# ===== 計算網段與區域名稱 =====
$netIdParts = "$SitePrefix.$xxStr.0".Split(".")
if ($netIdParts.Count -lt 3) {
    Write-Result $false "SitePrefix/XX 無法組成有效 IPv4 網段，請確認。"
    exit 1
}
$net24Prefix = "$($netIdParts[0]).$($netIdParts[1]).$($netIdParts[2])"
$NetworkId   = "$net24Prefix.0/24"
$ReverseZone = "$($netIdParts[2]).$($netIdParts[1]).$($netIdParts[0]).in-addr.arpa"

$BranchIP   = "$net24Prefix.254"
$BusinessIP = "$net24Prefix.100"
$HRIP       = "$net24Prefix.200"
$CustomerIP = "$net24Prefix.50"
$WWWIP      = $BranchIP
$LinuxIP    = $BusinessIP

Write-Host "將建立/確保以下區域與主機記錄：" -ForegroundColor Cyan
Write-Host "  Forward Zone : $DomainFqdn"
Write-Host "  Reverse Zone : $ReverseZone (NetworkId $NetworkId)"
Write-Host "  Branch IP    : $BranchIP"
Write-Host "  Business IP  : $BusinessIP"
Write-Host "  HR IP        : $HRIP"
Write-Host "  Customer IP  : $CustomerIP"
Write-Host ""

# ===== 安裝並啟動 DNS 服務 =====
$dnsFeature = Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue
if (-not $dnsFeature -or -not $dnsFeature.Installed) {
    Write-Host "安裝 DNS Server 角色與管理工具..." -ForegroundColor Yellow
    Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
}
$dnsSvc = Get-Service -Name DNS -ErrorAction SilentlyContinue
if ($dnsSvc -and $dnsSvc.Status -ne 'Running') {
    Start-Service -Name DNS
}
Write-Result $true "DNS 服務已啟用"

# ===== 建立/確認 Forward Zone =====
try {
    $existingForward = Get-DnsServerZone -Name $DomainFqdn -ErrorAction Stop
    Write-Result $true "Forward Zone '$DomainFqdn' 已存在（$($existingForward.ZoneType)）"
} catch {
    Write-Host "建立 Forward Zone '$DomainFqdn' ..." -ForegroundColor Yellow
    try {
        Add-DnsServerPrimaryZone -Name $DomainFqdn -ReplicationScope Domain -DynamicUpdate Secure -ErrorAction Stop | Out-Null
        Write-Result $true "Forward Zone '$DomainFqdn' 建立完成"
    } catch {
        Write-Result $false "建立 Forward Zone 失敗：$($_.Exception.Message)"
        exit 1
    }
}

# ===== 建立/確認 Reverse Zone (/24) =====
try {
    $existingReverse = Get-DnsServerZone -Name $ReverseZone -ErrorAction Stop
    Write-Result $true "Reverse Zone '$ReverseZone' 已存在（$($existingReverse.ZoneType)）"
} catch {
    Write-Host "建立 Reverse Zone $ReverseZone ..." -ForegroundColor Yellow
    try {
        Add-DnsServerPrimaryZone -NetworkId $NetworkId -ReplicationScope Domain -DynamicUpdate Secure -ErrorAction Stop | Out-Null
        Write-Result $true "Reverse Zone '$ReverseZone' 建立完成"
    } catch {
        Write-Result $false "建立 Reverse Zone 失敗：$($_.Exception.Message)"
        Write-Warn "將跳過 PTR 建立。"
        $ReverseZone = $null
    }
}

# ===== 函式：新增 A / PTR =====
function Add-DnsRecordWithPtr {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$HostName,
        [Parameter(Mandatory = $true)][string]$IPv4Address,
        [bool]$CreatePtr = $true
    )
    Write-Host "  設定 $HostName -> $IPv4Address" -ForegroundColor White
    Remove-DnsServerResourceRecord -ZoneName $DomainFqdn -RRType A -Name $HostName -Force -ErrorAction SilentlyContinue
    Add-DnsServerResourceRecordA -Name $HostName -ZoneName $DomainFqdn -IPv4Address $IPv4Address -AllowUpdateAny -TimeToLive 00:05:00

    if ($CreatePtr -and $ReverseZone) {
        $lastOctet = $IPv4Address.Split(".")[-1]
        Remove-DnsServerResourceRecord -ZoneName $ReverseZone -RRType PTR -Name $lastOctet -Force -ErrorAction SilentlyContinue
        Add-DnsServerResourceRecordPtr -ZoneName $ReverseZone -Name $lastOctet -PtrDomainName "$HostName.$DomainFqdn"
    }
}

# ===== 新增主機紀錄 =====
Add-DnsRecordWithPtr -HostName $BranchName   -IPv4Address $BranchIP
Add-DnsRecordWithPtr -HostName $BusinessName -IPv4Address $BusinessIP
Add-DnsRecordWithPtr -HostName $HRName       -IPv4Address $HRIP
Add-DnsRecordWithPtr -HostName "www"         -IPv4Address $WWWIP
Add-DnsRecordWithPtr -HostName "linux"       -IPv4Address $LinuxIP
Write-Host "  設定 $CustomerName -> $CustomerIP (不建立 PTR)" -ForegroundColor White
Remove-DnsServerResourceRecord -ZoneName $DomainFqdn -RRType A -Name $CustomerName -Force -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordA -Name $CustomerName -ZoneName $DomainFqdn -IPv4Address $CustomerIP -AllowUpdateAny -TimeToLive 00:05:00

# ===== 簡易驗證 =====
Write-Host "`n檢視現有 DNS 區域：" -ForegroundColor Cyan
Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated } | Select-Object ZoneName, ZoneType, IsReverseLookupZone | Format-Table -AutoSize

Write-Host "`nForward Zone A 記錄：" -ForegroundColor Cyan
Get-DnsServerResourceRecord -ZoneName $DomainFqdn -RRType A | Where-Object { $_.HostName -ne "@" } |
    Select-Object HostName, @{Name='IPv4';Expression={$_.RecordData.IPv4Address}} | Format-Table -AutoSize

Write-Host "`nReverse Zone PTR 記錄：" -ForegroundColor Cyan
if ($ReverseZone) {
    $ptrRecords = Get-DnsServerResourceRecord -ZoneName $ReverseZone -RRType PTR -ErrorAction SilentlyContinue
    if ($ptrRecords) {
        $ptrRecords | Select-Object HostName, @{Name='PtrDomainName';Expression={$_.RecordData.PtrDomainName}} | Format-Table -AutoSize
    } else {
        Write-Host "  (尚無 PTR 記錄或區域不存在)" -ForegroundColor Gray
    }
} else {
    Write-Host "  (略過，未建立 Reverse Zone)" -ForegroundColor Gray
}

Write-Host "`n解析測試：" -ForegroundColor Cyan
$testHosts = @($BranchName, $BusinessName, $HRName, "www", "linux", $CustomerName)
foreach ($h in $testHosts) {
    $fqdn = "$h.$DomainFqdn"
    try {
        $res = Resolve-DnsName -Name $fqdn -Type A -ErrorAction Stop
        Write-Result $true "$fqdn -> $($res.IPAddress)"
    } catch {
        Write-Result $false "$fqdn 解析失敗"
    }
}

Write-Host "`n[完成] DNS 區域與主機紀錄處理完畢。" -ForegroundColor Green
