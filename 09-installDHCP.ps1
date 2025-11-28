# ===============================
#  Windows Server 2022 - 安裝與設定 DHCP
#  範圍：172.16.xx.150 - 172.16.xx.200
#  排除：172.16.xx.185 - 172.16.xx.200
#  保留：172.16.xx.200 給 HR-xx (選填 MAC)
# ===============================

[CmdletBinding()]
param(
    [string]$DomainFqdn = "tcivs.com.tw",
    [ValidatePattern('^\d{1,2}$')][string]$XX = "01",
    [string]$ScopeName = "TCIVS-DHCP-Scope"
)

function Write-Result { param([bool]$Ok,[string]$Message)
    if ($Ok) { Write-Host "[通過] $Message" -ForegroundColor Green }
    else { Write-Host "[失敗] $Message" -ForegroundColor Red }
}
function Write-Warn($msg){ Write-Host "[警告] $msg" -ForegroundColor Yellow }

# ===== 權限與環境檢查 =====
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Result $false "請以系統管理員身分執行此腳本。"
    exit 1
}

try {
    Import-Module DhcpServer -ErrorAction Stop
} catch {
    Write-Result $false "無法載入 DhcpServer 模組：$($_.Exception.Message)"
    exit 1
}

try {
    $adDomain = Get-ADDomain -ErrorAction Stop
} catch {
    Write-Result $false "無法取得 AD 網域資訊，請確認已安裝 AD DS：$($_.Exception.Message)"
    exit 1
}
if ($adDomain.DNSRoot -ne $DomainFqdn) {
    Write-Warn "目前網域為 $($adDomain.DNSRoot)，改用此網域。"
    $DomainFqdn = $adDomain.DNSRoot
}

$role = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
if ($role -lt 4) {
    Write-Result $false "本機不是網域控制站，請先完成 AD DS 安裝。"
    exit 1
}

# ===== 組別與地址計算 =====
$xxNum = $XX -replace '^0+', ''
if ([string]::IsNullOrWhiteSpace($xxNum)) { $xxNum = "0" }
$ScopeId = "172.16.$xxNum.0"
$StartRange = "172.16.$xxNum.150"
$EndRange = "172.16.$xxNum.200"
$SubnetMask = "255.255.255.0"
$Router = "172.16.$xxNum.1"
$DNSServer = "172.16.$xxNum.254"
$HRIPAddress = "172.16.$xxNum.200"
$DomainName = $DomainFqdn
$LeaseDuration = New-TimeSpan -Days 8

$HRMacAddress = Read-Host "若要為 HR-$XX 保留 $HRIPAddress，請輸入 MAC (AA-BB-CC-DD-EE-FF)，跳過請直接 Enter"

Write-Host "`n將設定 DHCP：" -ForegroundColor Cyan
Write-Host "  範圍：$StartRange - $EndRange"
Write-Host "  排除：172.16.$xxNum.185 - 172.16.$xxNum.200"
Write-Host "  Gateway：$Router"
Write-Host "  DNS：$DNSServer"
Write-Host "  Domain：$DomainName"
if (-not [string]::IsNullOrWhiteSpace($HRMacAddress)) {
    Write-Host "  保留：$HRIPAddress -> HR-$XX (MAC: $HRMacAddress)"
}

$confirm = Read-Host "確認開始設定？ (Y/N)"
if ($confirm -notin @('Y','y')) { Write-Host "[取消] 未變更。" -ForegroundColor Red; exit 0 }

# ===== 安裝 DHCP 角色 =====
try {
    $feature = Get-WindowsFeature -Name DHCP
    if (-not $feature.Installed) {
        Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null
        Write-Result $true "已安裝 DHCP 伺服器角色"
    } else {
        Write-Result $true "DHCP 伺服器角色已存在"
    }
} catch {
    Write-Result $false "安裝 DHCP 角色失敗：$($_.Exception.Message)"
    exit 1
}

# ===== AD 授權 DHCP 伺服器 =====
try {
    $serverName = $env:COMPUTERNAME
    $serverFqdn = "$serverName.$DomainFqdn"
    $serverIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1).Name -ErrorAction Stop).IPAddress
    Add-DhcpServerInDC -DnsName $serverFqdn -IPAddress $serverIP -ErrorAction Stop
    Write-Result $true "已在 AD 授權 DHCP 伺服器：$serverFqdn ($serverIP)"
} catch {
    Write-Warn "AD 授權 DHCP 時發生問題：$($_.Exception.Message)；如已授權可忽略。"
}

# ===== 建立/重建 Scope =====
try {
    $existing = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Warn "Scope $ScopeId 已存在，將移除後重建。"
        Remove-DhcpServerv4Scope -ScopeId $ScopeId -Force
    }
    Add-DhcpServerv4Scope `
        -ScopeId $ScopeId `
        -Name $ScopeName `
        -StartRange $StartRange `
        -EndRange $EndRange `
        -SubnetMask $SubnetMask `
        -LeaseDuration $LeaseDuration `
        -State Active
    Write-Result $true "DHCP 範圍已建立：$ScopeName ($StartRange-$EndRange)"
} catch {
    Write-Result $false "建立 DHCP 範圍失敗：$($_.Exception.Message)"
    exit 1
}

# ===== 排除範圍 =====
try {
    Add-DhcpServerv4ExclusionRange -ScopeId $ScopeId -StartRange "172.16.$xxNum.185" -EndRange "172.16.$xxNum.200" -ErrorAction Stop
    Write-Result $true "已排除 172.16.$xxNum.185 - 172.16.$xxNum.200"
} catch {
    Write-Result $false "設定排除範圍失敗：$($_.Exception.Message)"
}

# ===== 範圍選項 =====
try {
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 3 -Value $Router -ErrorAction Stop
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 6 -Value $DNSServer -ErrorAction Stop
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 15 -Value $DomainName -ErrorAction Stop
    Write-Result $true "已設定範圍選項：Router/DNS/Domain"
} catch {
    Write-Result $false "設定範圍選項失敗：$($_.Exception.Message)"
}

# ===== HR 保留 (預設 200) =====
if (-not [string]::IsNullOrWhiteSpace($HRMacAddress)) {
    $cleanMac = $HRMacAddress.Trim().ToUpper()
    Write-Host "設定 HR 保留 $HRIPAddress ..." -ForegroundColor Cyan
    try {
        Remove-DhcpServerv4Reservation -ScopeId $ScopeId -ClientId $cleanMac -ErrorAction SilentlyContinue
        Add-DhcpServerv4Reservation -ScopeId $ScopeId -IPAddress $HRIPAddress -ClientId $cleanMac -Name "HR-$XX" -Description "HR Department Computer" -ErrorAction Stop
        Write-Result $true "已保留 $HRIPAddress 給 HR-$XX (MAC $cleanMac)"
    } catch {
        Write-Result $false "設定 HR 保留失敗：$($_.Exception.Message)"
    }
} else {
    Write-Warn "未輸入 HR MAC，跳過保留 172.16.$xxNum.200。"
}

# ===== 重啟服務並提示檢查 =====
try {
    Restart-Service DHCPServer
    Write-Result $true "DHCP 服務已重新啟動"
} catch {
    Write-Warn "重啟 DHCP 服務失敗：$($_.Exception.Message)"
}

Write-Host "`n請檢查：" -ForegroundColor Cyan
Write-Host "  Get-DhcpServerv4Scope"
Write-Host "  Get-DhcpServerv4ExclusionRange -ScopeId $ScopeId"
Write-Host "  Get-DhcpServerv4OptionValue -ScopeId $ScopeId"
Write-Host "  Get-DhcpServerv4Lease -ScopeId $ScopeId"
Write-Host "  Get-DhcpServerv4Reservation -ScopeId $ScopeId"

Write-Host "`n[完成] DHCP 設定流程結束。" -ForegroundColor Green
