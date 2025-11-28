# ===============================
#  Windows Server 2022 - 設定雙網卡靜態 IP
#  依校賽：LAN (172.16.xx.254/24) / WAN (120.118.xx.1/24)
#  調整：可在未插線狀態設定、僅處理 IPv4、加入錯誤處理
# ===============================

# 列出目前介面卡
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  目前主機網路介面卡列表" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, MacAddress -AutoSize
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# ==================== 輸入組別 ====================
$XX = Read-Host "請輸入組別編號（如 01）"
if ([string]::IsNullOrWhiteSpace($XX)) {
    $XX = "01"
    Write-Host "使用預設組別：$XX" -ForegroundColor Yellow
}

$XXNum = $XX -replace '^0+', ''
if ([string]::IsNullOrWhiteSpace($XXNum)) { $XXNum = "0" }

# 根據組別計算 IP
$LAN_IP = "172.16.$XXNum.254"
$LAN_Prefix = 24
$LAN_Gateway = "172.16.$XXNum.1"   # 若不需閘道可留空字串
$LAN_DNS = "127.0.0.1"

$WAN_IP = "120.118.$XXNum.1"
$WAN_Prefix = 24
$WAN_Gateway = ""  # 若要預設路由可填寫，空字串則不設

# ==================== 輸入介面名稱 ====================
Write-Host "`n請輸入介面名稱（可複製上面列表）" -ForegroundColor Yellow

$Interface_LAN = Read-Host "LAN 介面名稱（如 Ethernet）"
$Adapter_LAN = Get-NetAdapter | Where-Object { $_.Name -eq $Interface_LAN }
if ($null -eq $Adapter_LAN) {
    Write-Host "[錯誤] 找不到介面：$Interface_LAN" -ForegroundColor Red
    exit
}

$Interface_WAN = Read-Host "WAN 介面名稱（如 Ethernet 2）"
$Adapter_WAN = Get-NetAdapter | Where-Object { $_.Name -eq $Interface_WAN }
if ($null -eq $Adapter_WAN) {
    Write-Host "[錯誤] 找不到介面：$Interface_WAN" -ForegroundColor Red
    exit
}

if ($Interface_LAN -eq $Interface_WAN) {
    Write-Host "[錯誤] LAN / WAN 介面不可相同" -ForegroundColor Red
    exit
}

# ==================== 預覽設定 ====================
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  將套用設定：" -ForegroundColor Cyan
Write-Host "  LAN -> $LAN_IP/$LAN_Prefix , GW: $($LAN_Gateway -ne '' ? $LAN_Gateway : '無'), DNS: $LAN_DNS"
Write-Host "  WAN -> $WAN_IP/$WAN_Prefix , GW: $($WAN_Gateway -ne '' ? $WAN_Gateway : '無'), DNS: 無"
Write-Host "===============================================================================`n" -ForegroundColor Cyan

$Confirm = Read-Host "確認套用？ (Y/N)"
if ($Confirm -notin @('Y','y')) {
    Write-Host "[取消] 未變更" -ForegroundColor Red
    exit
}

# ==================== 定義設定流程 ====================
function Set-IPv4 {
    param(
        [string]$Alias,
        [string]$NewAlias,
        [string]$IP,
        [int]$Prefix,
        [string]$Gateway,
        [string[]]$Dns
    )

    Write-Host "`n處理介面：$Alias -> $NewAlias" -ForegroundColor Green

    Enable-NetAdapter -Name $Alias -Confirm:$false -ErrorAction SilentlyContinue
    Rename-NetAdapter -Name $Alias -NewName $NewAlias -ErrorAction Stop
    $Alias = $NewAlias

    Write-Host "移除舊 IPv4 設定..." -ForegroundColor Cyan
    Remove-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetRoute -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

    Write-Host "套用新的 IPv4 設定..." -ForegroundColor Cyan
    $ipParams = @{
        InterfaceAlias = $Alias
        IPAddress      = $IP
        PrefixLength   = $Prefix
        AddressFamily  = 'IPv4'
    }
    if ($Gateway -ne "") { $ipParams.DefaultGateway = $Gateway }
    New-NetIPAddress @ipParams | Out-Null

    if ($Dns) {
        Write-Host "設定 DNS..." -ForegroundColor Cyan
        Set-DnsClientServerAddress -InterfaceAlias $Alias -ServerAddresses $Dns
    }

    return Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue
}

# ==================== 套用設定 ====================
$LAN_Result = $null
$WAN_Result = $null
try {
    $LAN_Result = Set-IPv4 -Alias $Interface_LAN -NewAlias "LAN" -IP $LAN_IP -Prefix $LAN_Prefix -Gateway $LAN_Gateway -Dns $LAN_DNS
    $WAN_Result = Set-IPv4 -Alias $Interface_WAN -NewAlias "WAN" -IP $WAN_IP -Prefix $WAN_Prefix -Gateway $WAN_Gateway -Dns @()
    Write-Host "`n[完成] LAN / WAN 已套用設定" -ForegroundColor Green
} catch {
    Write-Host "[錯誤] 設定失敗：$($_.Exception.Message)" -ForegroundColor Red
    exit
}

# ==================== 驗證輸出 ====================
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  設定結果：" -ForegroundColor Cyan
Write-Host "  LAN -> $($LAN_Result.IPAddress)/$($LAN_Result.PrefixLength) , DNS: $LAN_DNS"
Write-Host "  WAN -> $($WAN_Result.IPAddress)/$($WAN_Result.PrefixLength) , DNS: 無"
Write-Host "===============================================================================`n" -ForegroundColor Cyan
