<# 
  Windows Server 2022 - DNS 一鍵部署
  113 年工科技藝競賽 電腦修護第一站（DNS 正反解 + 主機紀錄）
  
  內容包含：
   - 安裝 DNS Server 角色
   - 建立 Forward Lookup Zone（tcivs.com.tw）
   - 建立 Reverse Lookup Zone（172.16.xx.0/24）
   - 新增 Branch-xx / Business-xx / HR-xx / Customer-xx / www / linux 主機記錄
   - 自動新增 PTR
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()] [string] $DomainFqdn = "tcivs.com.tw",
    [Parameter()] [string] $SitePrefix = "172.16",       # 固定題目格式
    [Parameter()] [string] $XX = "01",                   # 崗位編號
    [Parameter()] [string] $BranchName   = "Branch-01",
    [Parameter()] [string] $BusinessName = "Business-01",
    [Parameter()] [string] $HRName       = "HR-01",
    [Parameter()] [string] $CustomerName = "Customer-01"
)

### ------------------------------
### Step 1. 計算 IP 與 Zone
### ------------------------------
$Net24 = "$SitePrefix.$XX"          # ex: 172.16.01 → 172.16.1
$Net24 = $Net24.Replace(".0", ".")  # 修正格式 (01→1)

$BranchIP   = "$Net24.254"   # Branch-xx
$BusinessIP = "$Net24.100"   # Fedora Business-xx
$HRIP       = "$Net24.200"   # HR-xx
$CustomerIP = "$Net24.50"    # Customer-xx (WAN 給定示例，不會在本網段)
$WWWIP      = $BranchIP      # 題目：網站架在 Branch-xx
$LinuxIP    = $BusinessIP    # 題目：linux = Business-xx

$ForwardZone = $DomainFqdn
$ReverseZone = "$XX.16.172.in-addr.arpa"   # ex: 1.16.172.in-addr.arpa

Write-Host "=== DNS Zone ===" -ForegroundColor Cyan
Write-Host " Forward Zone : $ForwardZone"
Write-Host " Reverse Zone : $ReverseZone"
Write-Host " Branch-xx IP : $BranchIP"
Write-Host " Business-xx IP : $BusinessIP"
Write-Host " HR-xx IP      : $HRIP"
Write-Host "================`n"

### ------------------------------
### Step 2. 安裝 DNS Server 角色
### ------------------------------
Write-Host "=== Step 2. 安裝 DNS Server 角色 ===" -ForegroundColor Cyan
Install-WindowsFeature DNS -IncludeManagementTools | Out-Null

### ------------------------------
### Step 3. 建立 Forward Lookup Zone
### ------------------------------
Write-Host "=== Step 3. 建立正向查詢區 (Forward Lookup Zone) ===" -ForegroundColor Cyan

if (-not (Get-DnsServerZone -Name $ForwardZone -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name $ForwardZone -ReplicationScope "Domain" | Out-Null
} else {
    Write-Host "Forward Zone $ForwardZone 已存在（略過）"
}

### ------------------------------
### Step 4. 建立 Reverse Lookup Zone
### ------------------------------
Write-Host "=== Step 4. 建立反向查詢區 (Reverse Lookup Zone - /24) ===" -ForegroundColor Cyan

$NetworkID = "$Net24.0/24"

if (-not (Get-DnsServerZone -Name $ReverseZone -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkId $NetworkID -ZoneName $ReverseZone -ReplicationScope "Domain" | Out-Null
} else {
    Write-Host "Reverse Zone $ReverseZone 已存在（略過）"
}

### ------------------------------
### Step 5. 新增主機紀錄（含 PTR）
### ------------------------------
Write-Host "=== Step 5. 新增 A 與 PTR 記錄 ===" -ForegroundColor Cyan

function Add-A-and-PTR($host, $ip){
    Write-Host "新增 $host  →  $ip"
    # A Record
    Remove-DnsServerResourceRecord -ZoneName $ForwardZone -RRType A -Name $host -Force -ErrorAction SilentlyContinue
    Add-DnsServerResourceRecordA -Name $host -ZoneName $ForwardZone -IPv4Address $ip -AllowUpdateAny -TimeToLive 00:05:00

    # PTR Record
    $last = $ip.Split(".")[-1]
    Remove-DnsServerResourceRecord -ZoneName $ReverseZone -RRType PTR -Name $last -Force -ErrorAction SilentlyContinue
    Add-DnsServerResourceRecordPtr -ZoneName $ReverseZone -Name $last -PtrDomainName "$host.$ForwardZone"
}

# 題目要求的主機紀錄
Add-A-and-PTR -host $BranchName   -ip $BranchIP
Add-A-and-PTR -host $BusinessName -ip $BusinessIP
Add-A-and-PTR -host $HRName       -ip $HRIP
Add-A-and-PTR -host "www"         -ip $WWWIP
Add-A-and-PTR -host "linux"       -ip $LinuxIP

# Customer-xx → 不在同一網段，不加入反解
Write-Host "新增 Customer-xx A 記錄（無 PTR，因不在此 /24）"
Remove-DnsServerResourceRecord -ZoneName $ForwardZone -RRType A -Name $CustomerName -Force -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordA -Name $CustomerName -ZoneName $ForwardZone -IPv4Address $CustomerIP -AllowUpdateAny

Write-Host "`n✅ DNS 安裝與所有主機紀錄設定完成！" -ForegroundColor Green
