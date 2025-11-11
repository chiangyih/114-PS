# ===============================
#  Windows Server 2022 - 設定兩張網卡固定 IP 位址
#  根據表A規格：LAN (172.16.xx.254/24) 與 WAN (120.118.xx.1/24)
# ===============================

# 顯示目前所有網路介面卡
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  目前系統中的網路介面卡" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Get-NetAdapter | Format-Table Name, InterfaceDescription, Status, MacAddress -AutoSize  # 列出所有網路介面卡的詳細資訊
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# ==================== 輸入崗位編號 ====================
$XX = Read-Host "請輸入崗位編號（例如：01）"  # 取得崗位編號，用於產生 IP 位址中的 xx 部分

# 驗證輸入
if ([string]::IsNullOrWhiteSpace($XX)) {  # 檢查輸入是否為空
    $XX = "01"  # 若為空則使用預設值 01
    Write-Host "使用預設崗位編號：$XX" -ForegroundColor Yellow  # 以黃色顯示使用預設值訊息
}

# 移除前導零以符合 IP 格式（例如 01 -> 1）
$XXNum = $XX -replace '^0+', ''  # 使用正規表示式移除前導零，將 01 轉換為 1
if ([string]::IsNullOrWhiteSpace($XXNum)) { $XXNum = "0" }  # 若結果為空（輸入為 00）則設為 0

# 根據表A規格產生 IP 位址
$LAN_IP = "172.16.$XXNum.254"  # LAN 介面 IP：172.16.xx.254
$LAN_Prefix = 24  # LAN 子網路遮罩長度：/24
$LAN_Gateway = "172.16.$XXNum.1"  # LAN 預設閘道：172.16.xx.1（可選）
$LAN_DNS = "127.0.0.1"  # LAN DNS 伺服器：本機（因為是網域控制站）

$WAN_IP = "120.118.$XXNum.1"  # WAN 介面 IP：120.118.xx.1
$WAN_Prefix = 24  # WAN 子網路遮罩長度：/24

# ==================== 輸入網卡介面名稱 ====================
Write-Host "`n【請輸入網卡介面名稱】" -ForegroundColor Yellow

# 輸入 LAN 網卡的 Interface 名稱
$Interface_LAN = Read-Host "請輸入 LAN 網卡的 Interface 名稱（例如：Ethernet、乙太網路）"  # 取得 LAN 網卡的介面名稱

# 驗證 LAN 網卡是否存在
$Adapter_LAN = Get-NetAdapter | Where-Object { $_.Name -eq $Interface_LAN }  # 搜尋指定名稱的網路介面卡
if ($null -eq $Adapter_LAN) {  # 檢查網卡是否存在
    Write-Host "[錯誤] 找不到名稱為 '$Interface_LAN' 的網路介面卡！" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 輸入 WAN 網卡的 Interface 名稱
$Interface_WAN = Read-Host "請輸入 WAN 網卡的 Interface 名稱（例如：Ethernet 2、乙太網路 2）"  # 取得 WAN 網卡的介面名稱

# 驗證 WAN 網卡是否存在
$Adapter_WAN = Get-NetAdapter | Where-Object { $_.Name -eq $Interface_WAN }  # 搜尋指定名稱的網路介面卡
if ($null -eq $Adapter_WAN) {  # 檢查網卡是否存在
    Write-Host "[錯誤] 找不到名稱為 '$Interface_WAN' 的網路介面卡！" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 檢查兩張網卡是否相同
if ($Interface_LAN -eq $Interface_WAN) {  # 檢查是否為同一張網卡
    Write-Host "[錯誤] LAN 和 WAN 不能是同一張網卡！請重新執行腳本。" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# ==================== 顯示設定摘要 ====================
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  即將設定兩張網卡（根據表A規格）" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  崗位編號：$XX" -ForegroundColor White
Write-Host "`n【LAN 網卡】" -ForegroundColor Yellow
Write-Host "  目前名稱：$Interface_LAN"  # 顯示 LAN 網卡目前名稱
Write-Host "  新名稱：LAN"  # 根據表A規格，重新命名為 LAN
Write-Host "  IP 位址：$LAN_IP"  # 顯示 LAN IP 位址（172.16.xx.254）
Write-Host "  子網路遮罩：/$LAN_Prefix"  # 顯示子網路遮罩（/24）
Write-Host "  預設閘道：無（內部網路）"  # LAN 通常不需要閘道
Write-Host "  DNS 伺服器：$LAN_DNS"  # 顯示 DNS 伺服器（本機）
Write-Host "`n【WAN 網卡】" -ForegroundColor Yellow
Write-Host "  目前名稱：$Interface_WAN"  # 顯示 WAN 網卡目前名稱
Write-Host "  新名稱：WAN"  # 根據表A規格，重新命名為 WAN
Write-Host "  IP 位址：$WAN_IP"  # 顯示 WAN IP 位址（120.118.xx.1）
Write-Host "  子網路遮罩：/$WAN_Prefix"  # 顯示子網路遮罩（/24）
Write-Host "  預設閘道：無"  # WAN 不設定閘道（根據表A）
Write-Host "  DNS 伺服器：無"  # WAN 不設定 DNS
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 確認是否繼續
$Confirm = Read-Host "是否繼續設定？(Y/N)"  # 要求使用者確認
if ($Confirm -ne 'Y' -and $Confirm -ne 'y') {  # 若使用者未輸入 Y 或 y
    Write-Host "[取消] 已取消設定作業" -ForegroundColor Red  # 顯示取消訊息
    exit  # 結束腳本
}

# ==================== 設定 LAN 網卡 ====================
Write-Host "`n【設定 LAN 網卡】" -ForegroundColor Green

# 步驟 1：重新命名網卡為 LAN（根據表A規格）
Write-Host "正在重新命名網卡為 'LAN'..." -ForegroundColor Cyan  # 顯示進度訊息
Rename-NetAdapter -Name $Interface_LAN -NewName "LAN"  # 將網卡重新命名為 LAN
$Interface_LAN = "LAN"  # 更新變數為新名稱

# 步驟 2：移除現有 IP 設定
Write-Host "正在移除 LAN 網卡的現有 IP 設定..." -ForegroundColor Cyan  # 顯示進度訊息
Remove-NetIPAddress -InterfaceAlias $Interface_LAN -Confirm:$false -ErrorAction SilentlyContinue  # 移除現有 IP 位址
Remove-NetRoute -InterfaceAlias $Interface_LAN -Confirm:$false -ErrorAction SilentlyContinue  # 移除現有路由

# 步驟 3：設定固定 IP 位址
Write-Host "正在設定 LAN 網卡的固定 IP 位址..." -ForegroundColor Cyan  # 顯示進度訊息
New-NetIPAddress -InterfaceAlias $Interface_LAN -IPAddress $LAN_IP -PrefixLength $LAN_Prefix | Out-Null  # 設定 LAN IP 位址（172.16.xx.254/24），不設定閘道

# 步驟 4：設定 DNS 伺服器
Write-Host "正在設定 LAN 網卡的 DNS 伺服器..." -ForegroundColor Cyan  # 顯示進度訊息
Set-DnsClientServerAddress -InterfaceAlias $Interface_LAN -ServerAddresses $LAN_DNS  # 設定 DNS 伺服器為本機（127.0.0.1）

Write-Host "[完成] LAN 網卡設定完成！" -ForegroundColor Green  # 顯示完成訊息

# ==================== 設定 WAN 網卡 ====================
Write-Host "`n【設定 WAN 網卡】" -ForegroundColor Green

# 步驟 1：重新命名網卡為 WAN（根據表A規格）
Write-Host "正在重新命名網卡為 'WAN'..." -ForegroundColor Cyan  # 顯示進度訊息
Rename-NetAdapter -Name $Interface_WAN -NewName "WAN"  # 將網卡重新命名為 WAN
$Interface_WAN = "WAN"  # 更新變數為新名稱

# 步驟 2：移除現有 IP 設定
Write-Host "正在移除 WAN 網卡的現有 IP 設定..." -ForegroundColor Cyan  # 顯示進度訊息
Remove-NetIPAddress -InterfaceAlias $Interface_WAN -Confirm:$false -ErrorAction SilentlyContinue  # 移除現有 IP 位址
Remove-NetRoute -InterfaceAlias $Interface_WAN -Confirm:$false -ErrorAction SilentlyContinue  # 移除現有路由

# 步驟 3：設定固定 IP 位址
Write-Host "正在設定 WAN 網卡的固定 IP 位址..." -ForegroundColor Cyan  # 顯示進度訊息
New-NetIPAddress -InterfaceAlias $Interface_WAN -IPAddress $WAN_IP -PrefixLength $WAN_Prefix | Out-Null  # 設定 WAN IP 位址（120.118.xx.1/24），不設定閘道和 DNS

Write-Host "[完成] WAN 網卡設定完成！" -ForegroundColor Green  # 顯示完成訊息

# ==================== 驗證設定 ====================
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  驗證網卡設定結果（根據表A規格）" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan

# 驗證 LAN 網卡
Write-Host "`n【LAN 網卡】" -ForegroundColor Yellow
$IPConfig_LAN = Get-NetIPAddress -InterfaceAlias "LAN" -AddressFamily IPv4  # 取得 LAN 網卡的 IPv4 設定
$DNS_LAN_Config = Get-DnsClientServerAddress -InterfaceAlias "LAN" -AddressFamily IPv4  # 取得 LAN 網卡的 DNS 設定
Write-Host "  介面名稱：LAN"  # 顯示網卡名稱（已重新命名為 LAN）
Write-Host "  IP 位址：$($IPConfig_LAN.IPAddress)"  # 顯示 IP 位址（應為 172.16.xx.254）
Write-Host "  子網路遮罩長度：$($IPConfig_LAN.PrefixLength)"  # 顯示子網路遮罩長度（應為 24）
Write-Host "  DNS 伺服器：$($DNS_LAN_Config.ServerAddresses)"  # 顯示 DNS 伺服器（應為 127.0.0.1）

# 驗證 WAN 網卡
Write-Host "`n【WAN 網卡】" -ForegroundColor Yellow
$IPConfig_WAN = Get-NetIPAddress -InterfaceAlias "WAN" -AddressFamily IPv4  # 取得 WAN 網卡的 IPv4 設定
Write-Host "  介面名稱：WAN"  # 顯示網卡名稱（已重新命名為 WAN）
Write-Host "  IP 位址：$($IPConfig_WAN.IPAddress)"  # 顯示 IP 位址（應為 120.118.xx.1）
Write-Host "  子網路遮罩長度：$($IPConfig_WAN.PrefixLength)"  # 顯示子網路遮罩長度（應為 24）
Write-Host "  DNS 伺服器：無"  # WAN 網卡不設定 DNS

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "[完成] 網卡名稱與 IP 位址設定完成！（符合表A規格）" -ForegroundColor Green  # 顯示完成訊息
Write-Host "  LAN 網卡: 172.16.$XXNum.254/24" -ForegroundColor White  # 顯示 LAN IP
Write-Host "  WAN 網卡: 120.118.$XXNum.1/24" -ForegroundColor White  # 顯示 WAN IP
Write-Host "===============================================================================`n" -ForegroundColor Cyan
