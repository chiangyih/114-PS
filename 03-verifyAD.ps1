# ===============================
#  Windows Server 2022 - 驗證 AD DS 安裝與 DNS
#  用途：確認 02-installADDS.ps1 建立的網域與服務是否正常
#  預設網域：tcivs.com.tw，可由使用者覆寫
# ===============================

function Write-Result {
    param([bool]$Ok, [string]$Message)
    if ($Ok) { Write-Host "[通過] $Message" -ForegroundColor Green }
    else { Write-Host "[失敗] $Message" -ForegroundColor Red }
}

$defaultDomain = "tcivs.com.tw"
$DomainNameInput = Read-Host "輸入要驗證的網域 FQDN（預設：$defaultDomain）"
$DomainName = if ([string]::IsNullOrWhiteSpace($DomainNameInput)) { $defaultDomain } else { $DomainNameInput.Trim() }
$ExpectedNetBIOS = (($DomainName -split '\.')[0]).ToUpper()

Write-Host "`n=== 驗證開始 ===" -ForegroundColor Cyan

# 1) 嘗試載入 AD 模組
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Write-Result $true "已載入 ActiveDirectory 模組"
} catch {
    Write-Result $false "無法載入 ActiveDirectory 模組，請確認已安裝 RSAT/AD DS 管理工具：$($_.Exception.Message)"
    exit 1
}

# 2) 取得網域資訊並比對
$domain = $null
try {
    $domain = Get-ADDomain -ErrorAction Stop
    Write-Result $true "取得 AD 網域資訊：$($domain.DNSRoot)（NetBIOS：$($domain.NetBIOSName)）"
} catch {
    Write-Result $false "無法取得 AD 網域資訊，可能尚未安裝或服務未啟動：$($_.Exception.Message)"
    exit 1
}

if ($domain.DNSRoot -ne $DomainName) {
    Write-Host "[警告] 本機網域為 $($domain.DNSRoot)，與預期 $DomainName 不符。" -ForegroundColor Yellow
}
if ($domain.NetBIOSName -ne $ExpectedNetBIOS) {
    Write-Host "[提示] NetBIOS 名稱為 $($domain.NetBIOSName)，預期 $ExpectedNetBIOS（若手動覆寫過可忽略）。" -ForegroundColor Yellow
}

# 3) 檢查服務狀態 (NTDS/DNS/Netlogon)
$svcNames = @("NTDS","DNS","Netlogon")
foreach ($name in $svcNames) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($null -eq $svc) {
        Write-Result $false "找不到服務 $name"
        continue
    }
    Write-Result ($svc.Status -eq 'Running') "服務 $($svc.DisplayName) 狀態：$($svc.Status)"
}

# 4) DNS 區域檢查
if (Get-Command Get-DnsServerZone -ErrorAction SilentlyContinue) {
    try {
        $zones = Get-DnsServerZone -ErrorAction Stop
        $hasDomainZone = $zones | Where-Object { $_.ZoneName -eq $DomainName }
        $hasMSDCS = $zones | Where-Object { $_.ZoneName -eq "_msdcs.$DomainName" }
        Write-Result ($hasDomainZone -ne $null) "DNS 區域存在：$DomainName"
        Write-Result ($hasMSDCS -ne $null) "DNS 區域存在：_msdcs.$DomainName"
    } catch {
        Write-Result $false "讀取 DNS 區域失敗：$($_.Exception.Message)"
    }
} else {
    Write-Host "[提示] 未安裝 DNS 伺服器管理模組，略過區域檢查。" -ForegroundColor Yellow
}

# 5) DC 可用性 (nltest)
$nltestOutput = nltest /dsgetdc:$DomainName 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Result $true "nltest /dsgetdc 成功，能找到網域控制站 $DomainName"
} else {
    Write-Result $false "nltest /dsgetdc 失敗，無法找到網域控制站。輸出：$nltestOutput"
}

# 6) SRV 記錄解析（LDAP/DC）
try {
    $srv = Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.$DomainName" -Type SRV -ErrorAction Stop
    Write-Result $true "DNS SRV 記錄 (_ldap._tcp.dc._msdcs.$DomainName) 解析成功，共 $($srv.Count) 筆"
} catch {
    Write-Result $false "DNS SRV 記錄解析失敗：$($_.Exception.Message)"
}

Write-Host "`n=== 驗證完成 ===" -ForegroundColor Cyan
