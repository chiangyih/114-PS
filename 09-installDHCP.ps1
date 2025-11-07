# ===============================
#  Windows Server 2022 - 安裝與設定 DHCP 伺服器
#  範圍：172.16.xx.150-200
#  包含 HR-xx 的固定保留
# ===============================

# 匯入必要模組
Import-Module DhcpServer  # 匯入 DHCP 伺服器管理模組

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  安裝與設定 DHCP 伺服器" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 提示使用者輸入崗位編號
$XX = Read-Host "請輸入崗位編號（例如：01）"  # 取得崗位編號
if ([string]::IsNullOrWhiteSpace($XX)) {  # 檢查是否為空
    $XX = "01"  # 使用預設值
    Write-Host "使用預設崗位編號：$XX" -ForegroundColor Yellow  # 顯示使用預設值
}

# 移除前導零
$XXNum = $XX -replace '^0+', ''  # 移除前導零
if ([string]::IsNullOrWhiteSpace($XXNum)) { $XXNum = "0" }  # 若為空則設為 0

# 設定 DHCP 參數
$ScopeId = "172.16.$XXNum.0"  # DHCP 範圍 ID（網路位址）
$StartRange = "172.16.$XXNum.150"  # DHCP 起始 IP 位址
$EndRange = "172.16.$XXNum.200"  # DHCP 結束 IP 位址
$SubnetMask = "255.255.255.0"  # 子網路遮罩
$Router = "172.16.$XXNum.1"  # 預設閘道（路由器）
$DNSServer = "172.16.$XXNum.254"  # DNS 伺服器（Branch-xx 本機）
$DomainName = "tcivs.com.tw"  # 網域名稱
$LeaseDuration = New-TimeSpan -Days 8  # 租約期限設定為 8 天

# HR-xx 的保留設定
$HRName = "HR-$XX"  # HR 主機名稱
$HRIPAddress = "172.16.$XXNum.200"  # HR 的固定 IP 位址
$HRMacAddress = Read-Host "請輸入 HR-$XX 的 MAC 位址（格式：AA-BB-CC-DD-EE-FF）"  # 提示輸入 MAC 位址

# 顯示設定資訊
Write-Host "`n即將設定的 DHCP 參數：" -ForegroundColor Cyan
Write-Host "  範圍 ID：$ScopeId" -ForegroundColor White
Write-Host "  IP 範圍：$StartRange - $EndRange" -ForegroundColor White
Write-Host "  子網路遮罩：$SubnetMask" -ForegroundColor White
Write-Host "  預設閘道：$Router" -ForegroundColor White
Write-Host "  DNS 伺服器：$DNSServer" -ForegroundColor White
Write-Host "  網域名稱：$DomainName" -ForegroundColor White
Write-Host "  租約期限：$($LeaseDuration.Days) 天" -ForegroundColor White
if (-not [string]::IsNullOrWhiteSpace($HRMacAddress)) {  # 若有輸入 MAC 位址
    Write-Host "  HR 保留：$HRIPAddress (MAC: $HRMacAddress)" -ForegroundColor White  # 顯示 HR 保留資訊
}
Write-Host ""  # 空行

# 步驟 1：安裝 DHCP 伺服器角色
Write-Host "步驟 1：安裝 DHCP 伺服器角色..." -ForegroundColor Cyan  # 顯示進度
try {
    $Feature = Get-WindowsFeature -Name DHCP  # 取得 DHCP 功能狀態
    if ($Feature.Installed) {  # 檢查是否已安裝
        Write-Host "✓ DHCP 伺服器角色已安裝" -ForegroundColor Green  # 已安裝
    } else {
        Install-WindowsFeature -Name DHCP -IncludeManagementTools  # 安裝 DHCP 伺服器角色及管理工具
        Write-Host "✓ DHCP 伺服器角色安裝完成" -ForegroundColor Green  # 安裝完成
    }
} catch {
    Write-Host "✗ 安裝 DHCP 伺服器角色失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 步驟 2：在 Active Directory 中授權 DHCP 伺服器
Write-Host "`n步驟 2：在 Active Directory 中授權 DHCP 伺服器..." -ForegroundColor Cyan  # 顯示進度
try {
    $ServerName = $env:COMPUTERNAME  # 取得本機電腦名稱
    $ServerFqdn = "$ServerName.tcivs.com.tw"  # 組合完整網域名稱
    $ServerIP = (Get-NetIPAddress -InterfaceAlias (Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1).Name -AddressFamily IPv4).IPAddress  # 取得本機 IP 位址
    
    Add-DhcpServerInDC -DnsName $ServerFqdn -IPAddress $ServerIP  # 在 AD 中授權 DHCP 伺服器
    Write-Host "✓ DHCP 伺服器已在 AD 中授權" -ForegroundColor Green  # 授權完成
} catch {
    Write-Host "⊙ AD 授權可能已完成或需要手動設定：$($_.Exception.Message)" -ForegroundColor Yellow  # 顯示警告訊息
}

# 步驟 3：建立 DHCP 範圍
Write-Host "`n步驟 3：建立 DHCP 範圍..." -ForegroundColor Cyan  # 顯示進度
try {
    # 檢查範圍是否已存在
    $ExistingScope = Get-DhcpServerv4Scope -ScopeId $ScopeId -ErrorAction SilentlyContinue  # 嘗試取得範圍
    if ($ExistingScope) {  # 若範圍已存在
        Write-Host "⊙ DHCP 範圍已存在，將移除後重新建立" -ForegroundColor Yellow  # 顯示警告
        Remove-DhcpServerv4Scope -ScopeId $ScopeId -Force  # 移除現有範圍
    }
    
    Add-DhcpServerv4Scope `
        -Name "TCIVS-DHCP-Scope" `  # 範圍名稱
        -StartRange $StartRange `  # 起始 IP
        -EndRange $EndRange `  # 結束 IP
        -SubnetMask $SubnetMask `  # 子網路遮罩
        -LeaseDuration $LeaseDuration `  # 租約期限
        -State Active  # 啟用範圍
    
    Write-Host "✓ DHCP 範圍建立完成" -ForegroundColor Green  # 建立完成
} catch {
    Write-Host "✗ 建立 DHCP 範圍失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 步驟 4：設定 DHCP 選項
Write-Host "`n步驟 4：設定 DHCP 選項..." -ForegroundColor Cyan  # 顯示進度
try {
    # 選項 3：路由器（預設閘道）
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 3 -Value $Router  # 設定預設閘道
    Write-Host "✓ 已設定選項 3（路由器）：$Router" -ForegroundColor Green  # 設定完成
    
    # 選項 6：DNS 伺服器
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 6 -Value $DNSServer  # 設定 DNS 伺服器
    Write-Host "✓ 已設定選項 6（DNS 伺服器）：$DNSServer" -ForegroundColor Green  # 設定完成
    
    # 選項 15：DNS 網域名稱
    Set-DhcpServerv4OptionValue -ScopeId $ScopeId -OptionId 15 -Value $DomainName  # 設定網域名稱
    Write-Host "✓ 已設定選項 15（DNS 網域名稱）：$DomainName" -ForegroundColor Green  # 設定完成
} catch {
    Write-Host "✗ 設定 DHCP 選項失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 5：新增 HR-xx 的固定保留（如果有提供 MAC 位址）
if (-not [string]::IsNullOrWhiteSpace($HRMacAddress)) {  # 檢查是否有輸入 MAC 位址
    Write-Host "`n步驟 5：新增 HR-xx 的固定保留..." -ForegroundColor Cyan  # 顯示進度
    try {
        # 移除可能已存在的保留
        Remove-DhcpServerv4Reservation -ScopeId $ScopeId -ClientId $HRMacAddress -ErrorAction SilentlyContinue  # 移除現有保留
        
        Add-DhcpServerv4Reservation `
            -ScopeId $ScopeId `  # 範圍 ID
            -IPAddress $HRIPAddress `  # 保留的 IP 位址
            -ClientId $HRMacAddress `  # 用戶端 MAC 位址
            -Name $HRName `  # 保留名稱
            -Description "HR Department Computer"  # 描述
        
        Write-Host "✓ 已新增 $HRName 的固定保留：$HRIPAddress" -ForegroundColor Green  # 保留完成
    } catch {
        Write-Host "✗ 新增固定保留失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    }
} else {
    Write-Host "`n步驟 5：略過（未提供 HR MAC 位址）" -ForegroundColor Yellow  # 略過保留設定
}

# 步驟 6：啟動 DHCP 服務
Write-Host "`n步驟 6：啟動 DHCP 服務..." -ForegroundColor Cyan  # 顯示進度
try {
    Restart-Service DHCPServer  # 重新啟動 DHCP 服務
    Write-Host "✓ DHCP 服務已啟動" -ForegroundColor Green  # 服務啟動
} catch {
    Write-Host "✗ 啟動 DHCP 服務失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 顯示完成訊息和驗證資訊
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  DHCP 伺服器設定完成" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "`n驗證命令：" -ForegroundColor Yellow
Write-Host "  Get-DhcpServerv4Scope" -ForegroundColor Gray  # 查看範圍
Write-Host "  Get-DhcpServerv4OptionValue -ScopeId $ScopeId" -ForegroundColor Gray  # 查看選項
Write-Host "  Get-DhcpServerv4Lease -ScopeId $ScopeId" -ForegroundColor Gray  # 查看租約
if (-not [string]::IsNullOrWhiteSpace($HRMacAddress)) {  # 若有設定保留
    Write-Host "  Get-DhcpServerv4Reservation -ScopeId $ScopeId" -ForegroundColor Gray  # 查看保留
}
Write-Host ""  # 空行
