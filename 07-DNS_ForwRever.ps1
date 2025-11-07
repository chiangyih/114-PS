<# 
===============================================================================
  Windows Server 2022 - DNS 正反向查詢區一鍵部署
  113 年工科技藝競賽 電腦修護第一站（DNS 正反解 + 主機紀錄）
===============================================================================
  
  前置需求：
   - 已執行 01-creatAD.ps1 或 03-installADDSForest.ps1（建立 AD DS 和基本 DNS）
   - 伺服器已成為網域控制站
   - DNS 服務已啟動
  
  腳本功能：
   1. 確認並安裝 DNS Server 角色（如尚未安裝）
   2. 建立 AD 整合的正向查詢區（Forward Lookup Zone: tcivs.com.tw）
   3. 建立 AD 整合的反向查詢區（Reverse Lookup Zone: 172.16.xx.0/24）
   4. 新增主機記錄（A Records）：
      - Branch-xx   (172.16.xx.254) - 主要伺服器
      - Business-xx (172.16.xx.100) - Fedora 商務主機
      - HR-xx       (172.16.xx.200) - 人力資源主機
      - Customer-xx (172.16.xx.50)  - 客戶主機（僅 A 記錄）
      - www         (指向 Branch-xx) - 網站服務
      - linux       (指向 Business-xx) - Linux 主機別名
   5. 自動建立對應的 PTR 記錄（反向解析）
  
  使用範例：
   .\07-DNS_ForwRever.ps1 -XX "01"
   .\07-DNS_ForwRever.ps1 -XX "15" -BranchName "Branch-15"
===============================================================================
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(HelpMessage = "網域的完整網域名稱（FQDN），應與 01-creatAD.ps1 中設定一致")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainFqdn = "tcivs.com.tw",
    
    [Parameter(HelpMessage = "IP 位址前綴（前兩個八位元組）")]
    [ValidatePattern('^\d{1,3}\.\d{1,3}$')]
    [string]$SitePrefix = "172.16",
    
    [Parameter(HelpMessage = "崗位編號（01-99），用於組成 IP 位址的第三個八位元組")]
    [ValidatePattern('^\d{1,2}$')]
    [string]$XX = "01",
    
    [Parameter(HelpMessage = "Branch 主機名稱")]
    [ValidateNotNullOrEmpty()]
    [string]$BranchName = "Branch-01",
    
    [Parameter(HelpMessage = "Business 主機名稱（Fedora）")]
    [ValidateNotNullOrEmpty()]
    [string]$BusinessName = "Business-01",
    
    [Parameter(HelpMessage = "HR 主機名稱")]
    [ValidateNotNullOrEmpty()]
    [string]$HRName = "HR-01",
    
    [Parameter(HelpMessage = "Customer 主機名稱")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomerName = "Customer-01"
)

### ======================================================================
### Step 0. 前置檢查（確保能接續 01~06 腳本）
### ======================================================================
Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "  DNS 正反向查詢區部署腳本" -ForegroundColor Cyan
Write-Host "======================================`n" -ForegroundColor Cyan

# 檢查是否為網域控制站
Write-Host "正在檢查前置條件..." -ForegroundColor Yellow

try {
    $dcRole = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty DomainRole
    if ($dcRole -lt 4) {  # DomainRole < 4 表示不是網域控制站
        Write-Host "❌ 錯誤：此伺服器尚未成為網域控制站" -ForegroundColor Red
        Write-Host "   請先執行 01-creatAD.ps1 或 03-installADDSForest.ps1" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ 確認：伺服器是網域控制站" -ForegroundColor Green
} catch {
    Write-Host "⚠️  警告：無法確認網域控制站狀態，繼續執行..." -ForegroundColor Yellow
}

# 檢查 AD DS 服務狀態
try {
    $adService = Get-Service -Name NTDS -ErrorAction Stop
    if ($adService.Status -ne 'Running') {
        Write-Host "❌ 錯誤：Active Directory 網域服務未執行" -ForegroundColor Red
        Write-Host "   請確認已正確安裝並啟動 AD DS" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ 確認：Active Directory 網域服務正在執行" -ForegroundColor Green
} catch {
    Write-Host "❌ 錯誤：找不到 Active Directory 網域服務" -ForegroundColor Red
    Write-Host "   請先執行 01-creatAD.ps1 安裝 AD DS" -ForegroundColor Yellow
    exit 1
}

# 驗證網域名稱是否與 AD 一致
try {
    $currentDomain = (Get-ADDomain -ErrorAction Stop).DNSRoot
    if ($currentDomain -ne $DomainFqdn) {
        Write-Host "⚠️  警告：指定的網域名稱 ($DomainFqdn) 與實際 AD 網域 ($currentDomain) 不一致" -ForegroundColor Yellow
        Write-Host "   將使用實際 AD 網域名稱：$currentDomain" -ForegroundColor Yellow
        $DomainFqdn = $currentDomain
    } else {
        Write-Host "✅ 確認：網域名稱一致 ($DomainFqdn)" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  警告：無法取得 AD 網域資訊，將使用指定的網域名稱：$DomainFqdn" -ForegroundColor Yellow
}

Write-Host "`n前置檢查完成，開始部署 DNS 設定...`n" -ForegroundColor Green

### ------------------------------
### Step 1. 計算 IP 與 Zone
### ------------------------------
$Net24 = "$SitePrefix.$XX"          # ex: 172.16.01 → 172.16.1  # 組合網路位址的前三個八位元組（例如：172.16.01）
$Net24 = $Net24.Replace(".0", ".")  # 修正格式 (01→1)  # 移除前導零，將 .01 修正為 .1

$BranchIP   = "$Net24.254"   # Branch-xx  # 設定 Branch 主機的 IP 位址為網段的 .254（例如：172.16.1.254）
$BusinessIP = "$Net24.100"   # Fedora Business-xx  # 設定 Business 主機（Fedora）的 IP 位址為網段的 .100
$HRIP       = "$Net24.200"   # HR-xx  # 設定 HR 主機的 IP 位址為網段的 .200
$CustomerIP = "$Net24.50"    # Customer-xx (WAN 給定示例，不會在本網段)  # 設定 Customer 主機的 IP 位址為網段的 .50
$WWWIP      = $BranchIP      # 題目：網站架在 Branch-xx  # 設定 www 主機記錄指向 Branch 主機的 IP 位址
$LinuxIP    = $BusinessIP    # 題目：linux = Business-xx  # 設定 linux 主機記錄指向 Business 主機的 IP 位址

$ForwardZone = $DomainFqdn  # 設定正向查詢區名稱為網域 FQDN（tcivs.com.tw）
$ReverseZone = "$XX.16.172.in-addr.arpa"   # ex: 1.16.172.in-addr.arpa  # 設定反向查詢區名稱，格式為倒序的 IP 加上 in-addr.arpa（例如：1.16.172.in-addr.arpa）

Write-Host "=== DNS Zone ===" -ForegroundColor Cyan  # 以青色顯示 DNS 區域資訊標題
Write-Host " Forward Zone : $ForwardZone"  # 顯示正向查詢區名稱
Write-Host " Reverse Zone : $ReverseZone"  # 顯示反向查詢區名稱
Write-Host " Branch-xx IP : $BranchIP"  # 顯示 Branch 主機的 IP 位址
Write-Host " Business-xx IP : $BusinessIP"  # 顯示 Business 主機的 IP 位址
Write-Host " HR-xx IP      : $HRIP"  # 顯示 HR 主機的 IP 位址
Write-Host "================`n"  # 顯示分隔線並換行

### ------------------------------
### Step 2. 確認並安裝 DNS Server 角色
### ------------------------------
Write-Host "=== Step 2. 確認 DNS Server 角色狀態 ===" -ForegroundColor Cyan

# 檢查 DNS 角色是否已安裝
$dnsFeature = Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue

if ($dnsFeature -and $dnsFeature.Installed) {
    Write-Host "✅ DNS Server 角色已安裝（可能由 01-creatAD.ps1 安裝）" -ForegroundColor Green
    
    # 檢查 DNS 服務狀態
    $dnsService = Get-Service -Name DNS -ErrorAction SilentlyContinue
    if ($dnsService -and $dnsService.Status -eq 'Running') {
        Write-Host "✅ DNS 服務正在執行中" -ForegroundColor Green
    } elseif ($dnsService) {
        Write-Host "⚠️  DNS 服務已安裝但未執行，正在啟動..." -ForegroundColor Yellow
        Start-Service -Name DNS
        Write-Host "✅ DNS 服務已啟動" -ForegroundColor Green
    }
} else {
    Write-Host "⚠️  DNS Server 角色尚未安裝，正在安裝..." -ForegroundColor Yellow
    Install-WindowsFeature DNS -IncludeManagementTools | Out-Null
    Write-Host "✅ DNS Server 角色安裝完成" -ForegroundColor Green
}

Write-Host ""

### ------------------------------
### Step 3. 建立正向查詢區（Forward Lookup Zone）
### ------------------------------
Write-Host "=== Step 3. 建立正向查詢區 ===" -ForegroundColor Cyan

$existingForwardZone = Get-DnsServerZone -Name $ForwardZone -ErrorAction SilentlyContinue

if ($existingForwardZone) {
    Write-Host "✅ 正向查詢區 '$ForwardZone' 已存在（可能由 AD DS 自動建立）" -ForegroundColor Green
    Write-Host "   區域類型: $($existingForwardZone.ZoneType)" -ForegroundColor Gray
} else {
    Write-Host "正在建立 AD 整合的主要正向查詢區..." -ForegroundColor Yellow
    try {
        Add-DnsServerPrimaryZone -Name $ForwardZone -ReplicationScope "Domain" -ErrorAction Stop | Out-Null
        Write-Host "✅ 正向查詢區 '$ForwardZone' 建立成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 錯誤：無法建立正向查詢區 - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

### ------------------------------
### Step 4. 建立反向查詢區（Reverse Lookup Zone）
### ------------------------------
Write-Host "=== Step 4. 建立反向查詢區 (IPv4 /24) ===" -ForegroundColor Cyan

$existingReverseZone = Get-DnsServerZone -Name $ReverseZone -ErrorAction SilentlyContinue

if ($existingReverseZone) {
    Write-Host "✅ 反向查詢區 '$ReverseZone' 已存在" -ForegroundColor Green
    Write-Host "   區域類型: $($existingReverseZone.ZoneType)" -ForegroundColor Gray
} else {
    Write-Host "正在建立 AD 整合的主要反向查詢區..." -ForegroundColor Yellow
    Write-Host "   網路 ID: $NetworkID" -ForegroundColor Gray
    try {
        Add-DnsServerPrimaryZone -NetworkId $NetworkID -ReplicationScope "Domain" -ErrorAction Stop | Out-Null
        Write-Host "✅ 反向查詢區 '$ReverseZone' 建立成功" -ForegroundColor Green
    } catch {
        Write-Host "❌ 錯誤：無法建立反向查詢區 - $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   將繼續執行，但 PTR 記錄可能無法建立" -ForegroundColor Yellow
    }
}

Write-Host ""

### ------------------------------
### Step 5. 新增主機紀錄（含 PTR）
### ------------------------------
Write-Host "=== Step 5. 新增 A 與 PTR 記錄 ===" -ForegroundColor Cyan  # 以青色顯示步驟 5 標題

# 定義函式：新增 DNS A 記錄和 PTR 記錄
# 符合 PowerShell 動詞-名詞命名規範
function Add-DnsRecordWithPtr {
    [CmdletBinding()]  # 啟用 Cmdlet 繫結，提供進階功能支援
    param(
        [Parameter(Mandatory = $true)]  # 必要參數：主機名稱
        [string]$HostName,
        
        [Parameter(Mandatory = $true)]  # 必要參數：IPv4 位址
        [string]$IPv4Address,
        
        [Parameter(Mandatory = $false)]  # 可選參數：是否建立 PTR 記錄
        [bool]$CreatePtr = $true
    )
    
    Write-Host "新增 $HostName  →  $IPv4Address" -ForegroundColor White
    
    # 新增或更新 A 記錄（主機名稱到 IP 位址的對應）
    Remove-DnsServerResourceRecord -ZoneName $ForwardZone -RRType A -Name $HostName -Force -ErrorAction SilentlyContinue
    Add-DnsServerResourceRecordA -Name $HostName -ZoneName $ForwardZone -IPv4Address $IPv4Address -AllowUpdateAny -TimeToLive 00:05:00
    
    # 新增 PTR 記錄（IP 位址到主機名稱的反向對應）
    if ($CreatePtr) {
        $LastOctet = $IPv4Address.Split(".")[-1]  # 取得 IP 位址的最後一個八位元組（主機部分）
        Remove-DnsServerResourceRecord -ZoneName $ReverseZone -RRType PTR -Name $LastOctet -Force -ErrorAction SilentlyContinue
        Add-DnsServerResourceRecordPtr -ZoneName $ReverseZone -Name $LastOctet -PtrDomainName "$HostName.$ForwardZone"
    }
}

# 題目要求的主機紀錄（配合前面 01~06 腳本的網域設定）
Add-DnsRecordWithPtr -HostName $BranchName -IPv4Address $BranchIP
Add-DnsRecordWithPtr -HostName $BusinessName -IPv4Address $BusinessIP
Add-DnsRecordWithPtr -HostName $HRName -IPv4Address $HRIP
Add-DnsRecordWithPtr -HostName "www" -IPv4Address $WWWIP
Add-DnsRecordWithPtr -HostName "linux" -IPv4Address $LinuxIP

# Customer-xx → 不在同一網段（可能在 WAN），僅建立 A 記錄，不建立 PTR
Write-Host "新增 $CustomerName A 記錄（無 PTR，因不在此 /24 網段）" -ForegroundColor Yellow
Remove-DnsServerResourceRecord -ZoneName $ForwardZone -RRType A -Name $CustomerName -Force -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordA -Name $CustomerName -ZoneName $ForwardZone -IPv4Address $CustomerIP -AllowUpdateAny -TimeToLive 00:05:00

Write-Host "`n✅ DNS 安裝與所有主機紀錄設定完成！" -ForegroundColor Green

### ------------------------------
### Step 6. 驗證 DNS 設定
### ------------------------------
Write-Host "`n=== Step 6. 驗證 DNS 設定 ===" -ForegroundColor Cyan

# 顯示所有 DNS 區域
Write-Host "`n【DNS 區域清單】" -ForegroundColor White
Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated } | 
    Select-Object ZoneName, ZoneType, IsReverseLookupZone | 
    Format-Table -AutoSize

# 顯示正向查詢區的 A 記錄
Write-Host "【正向查詢區 A 記錄】" -ForegroundColor White
Get-DnsServerResourceRecord -ZoneName $ForwardZone -RRType A | 
    Where-Object { $_.HostName -notlike "@" } |
    Select-Object HostName, @{Name='IPv4Address';Expression={$_.RecordData.IPv4Address}} | 
    Format-Table -AutoSize

# 顯示反向查詢區的 PTR 記錄
Write-Host "【反向查詢區 PTR 記錄】" -ForegroundColor White
$reverseRecords = Get-DnsServerResourceRecord -ZoneName $ReverseZone -RRType PTR -ErrorAction SilentlyContinue
if ($reverseRecords) {
    $reverseRecords | 
        Where-Object { $_.HostName -notlike "@" } |
        Select-Object HostName, @{Name='PtrDomainName';Expression={$_.RecordData.PtrDomainName}} | 
        Format-Table -AutoSize
} else {
    Write-Host "  (無 PTR 記錄或反向查詢區不存在)" -ForegroundColor Gray
}

# 測試 DNS 解析
Write-Host "`n【DNS 解析測試】" -ForegroundColor White
$testHosts = @($BranchName, $BusinessName, $HRName, "www", "linux", $CustomerName)
foreach ($testHost in $testHosts) {
    $fqdn = "$testHost.$DomainFqdn"
    try {
        $result = Resolve-DnsName -Name $fqdn -Type A -ErrorAction Stop
        Write-Host "  ✅ $fqdn → $($result.IPAddress)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $fqdn 解析失敗" -ForegroundColor Red
    }
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "  DNS 部署完成！接續腳本執行順序：" -ForegroundColor Cyan
Write-Host "  1. ✅ 01-creatAD.ps1 (已完成)" -ForegroundColor Gray
Write-Host "  2. ✅ 02-verifyAD-DNS_status.ps1 (建議執行)" -ForegroundColor Gray
Write-Host "  3. 🔄 04-installADCS-rootCA.ps1 (可選)" -ForegroundColor Gray
Write-Host "  4. 🔄 06-install-IIS.ps1 (可選)" -ForegroundColor Gray
Write-Host "================================================`n" -ForegroundColor Cyan
