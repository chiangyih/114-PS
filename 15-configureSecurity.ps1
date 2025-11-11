# ===============================
#  Windows Server 2022 - 安全性與系統設定
#  包含 Windows Defender、Edge 瀏覽器設定等
# ===============================

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  系統安全性與設定" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# ==========================================
# 第 1 部分：Windows Defender 設定
# ==========================================
Write-Host "第 1 部分：Windows Defender 設定" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan

# 步驟 1-1：確認 Windows Defender 狀態
Write-Host "步驟 1-1：檢查 Windows Defender 狀態..." -ForegroundColor Cyan  # 顯示進度
try {
    $DefenderStatus = Get-MpComputerStatus  # 取得 Windows Defender 狀態
    if ($DefenderStatus.AntivirusEnabled) {  # 檢查防毒是否已啟用
        Write-Host "✓ Windows Defender 防毒已啟用" -ForegroundColor Green  # 已啟用
    } else {
        Write-Host "⊙ Windows Defender 防毒未啟用" -ForegroundColor Yellow  # 未啟用
    }
    
    Write-Host "  即時保護：$($DefenderStatus.RealTimeProtectionEnabled)" -ForegroundColor White  # 顯示即時保護狀態
    Write-Host "  病毒定義版本：$($DefenderStatus.AntivirusSignatureVersion)" -ForegroundColor White  # 顯示病毒定義版本
} catch {
    Write-Host "✗ 無法取得 Windows Defender 狀態：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 1-2：啟用 Windows Defender 功能
Write-Host "`n步驟 1-2：啟用 Windows Defender 即時保護..." -ForegroundColor Cyan  # 顯示進度
try {
    Set-MpPreference -DisableRealtimeMonitoring $false  # 啟用即時監視
    Write-Host "✓ 即時保護已啟用" -ForegroundColor Green  # 啟用完成
} catch {
    Write-Host "⊙ 即時保護設定可能需要管理員權限：$($_.Exception.Message)" -ForegroundColor Yellow  # 顯示警告
}

# 步驟 1-3：更新病毒定義
Write-Host "`n步驟 1-3：更新病毒與威脅定義..." -ForegroundColor Cyan  # 顯示進度
try {
    Update-MpSignature  # 更新病毒定義
    Write-Host "✓ 病毒定義更新完成" -ForegroundColor Green  # 更新完成
} catch {
    Write-Host "⊙ 更新病毒定義失敗（可能需要網路連線）：$($_.Exception.Message)" -ForegroundColor Yellow  # 顯示警告
}

# 步驟 1-4：執行快速掃描
Write-Host "`n步驟 1-4：執行快速掃描..." -ForegroundColor Cyan  # 顯示進度
$RunScan = Read-Host "是否要執行快速掃描？(Y/N)"  # 詢問是否執行掃描

if ($RunScan -eq 'Y' -or $RunScan -eq 'y') {  # 若選擇執行
    try {
        Write-Host "⊙ 正在掃描系統（請稍候）..." -ForegroundColor Yellow  # 顯示掃描訊息
        Start-MpScan -ScanType QuickScan  # 執行快速掃描
        Write-Host "✓ 快速掃描完成" -ForegroundColor Green  # 掃描完成
        
        # 顯示掃描結果
        $ScanStatus = Get-MpThreatDetection  # 取得威脅偵測結果
        if ($ScanStatus.Count -eq 0) {  # 若未發現威脅
            Write-Host "✓ 未發現威脅" -ForegroundColor Green  # 顯示結果
        } else {
            Write-Host "⚠  發現 $($ScanStatus.Count) 個威脅" -ForegroundColor Yellow  # 顯示威脅數量
        }
    } catch {
        Write-Host "✗ 掃描失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    }
} else {
    Write-Host "⊙ 已略過快速掃描" -ForegroundColor Yellow  # 略過掃描
}

# ==========================================
# 第 2 部分：Microsoft Edge 設定
# ==========================================
Write-Host "`n`n第 2 部分：Microsoft Edge 瀏覽器設定" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan

# 步驟 2-1：設定 Edge 首頁
Write-Host "步驟 2-1：設定 Edge 預設首頁..." -ForegroundColor Cyan  # 顯示進度
$HomePage = "https://www.tcivs.com.tw"  # 設定首頁網址

try {
    # Edge 的設定透過登錄檔進行
    $EdgeRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"  # Edge 群組原則登錄路徑
    
    # 建立登錄機碼（如果不存在）
    if (-not (Test-Path $EdgeRegPath)) {  # 檢查路徑是否存在
        New-Item -Path $EdgeRegPath -Force | Out-Null  # 建立登錄機碼
    }
    
    # 設定首頁 URL
    Set-ItemProperty -Path $EdgeRegPath -Name "HomepageLocation" -Value $HomePage -Type String  # 設定首頁位置
    Set-ItemProperty -Path $EdgeRegPath -Name "HomepageIsNewTabPage" -Value 0 -Type DWord  # 設定首頁不是新分頁
    
    # 設定啟動頁面
    Set-ItemProperty -Path $EdgeRegPath -Name "RestoreOnStartup" -Value 4 -Type DWord  # 設定啟動時開啟特定頁面
    
    # 建立啟動頁面清單
    $StartupUrlsPath = "$EdgeRegPath\RestoreOnStartupURLs"  # 啟動 URL 登錄路徑
    if (-not (Test-Path $StartupUrlsPath)) {  # 檢查是否存在
        New-Item -Path $StartupUrlsPath -Force | Out-Null  # 建立登錄機碼
    }
    Set-ItemProperty -Path $StartupUrlsPath -Name "1" -Value $HomePage -Type String  # 設定第一個啟動頁面
    
    Write-Host "✓ Edge 首頁已設定為：$HomePage" -ForegroundColor Green  # 設定完成
} catch {
    Write-Host "✗ 設定 Edge 首頁失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 2-2：設定 Edge 安全性選項
Write-Host "`n步驟 2-2：設定 Edge 安全性選項..." -ForegroundColor Cyan  # 顯示進度
try {
    # 啟用 SmartScreen
    Set-ItemProperty -Path $EdgeRegPath -Name "SmartScreenEnabled" -Value 1 -Type DWord  # 啟用 SmartScreen 篩選工具
    Write-Host "✓ SmartScreen 篩選工具已啟用" -ForegroundColor Green  # 啟用完成
    
    # 啟用安全 DNS
    Set-ItemProperty -Path $EdgeRegPath -Name "BuiltInDnsClientEnabled" -Value 1 -Type DWord  # 啟用內建 DNS 用戶端（安全 DNS）
    Write-Host "✓ 安全 DNS 已啟用" -ForegroundColor Green  # 啟用完成
    
    # 停用密碼管理員（依組織政策）
    # Set-ItemProperty -Path $EdgeRegPath -Name "PasswordManagerEnabled" -Value 0 -Type DWord  # 如需停用密碼管理員，取消此行註解
    
} catch {
    Write-Host "✗ 設定 Edge 安全性選項失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# ==========================================
# 第 3 部分：Windows 更新設定
# ==========================================
Write-Host "`n`n第 3 部分：Windows 更新設定" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan

Write-Host "步驟 3-1：檢查 Windows 更新服務狀態..." -ForegroundColor Cyan  # 顯示進度
try {
    $UpdateService = Get-Service -Name wuauserv  # 取得 Windows Update 服務狀態
    Write-Host "✓ Windows Update 服務狀態：$($UpdateService.Status)" -ForegroundColor Green  # 顯示服務狀態
    
    if ($UpdateService.Status -ne 'Running') {  # 若服務未執行
        Write-Host "⊙ 正在啟動 Windows Update 服務..." -ForegroundColor Yellow  # 顯示啟動訊息
        Start-Service wuauserv  # 啟動服務
        Write-Host "✓ Windows Update 服務已啟動" -ForegroundColor Green  # 啟動完成
    }
} catch {
    Write-Host "✗ Windows Update 服務檢查失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# ==========================================
# 第 4 部分：防火牆設定
# ==========================================
Write-Host "`n`n第 4 部分：Windows 防火牆設定" -ForegroundColor Cyan
Write-Host "───────────────────────────────────────────────────────────────────────────────`n" -ForegroundColor Cyan

Write-Host "步驟 4-1：檢查防火牆狀態..." -ForegroundColor Cyan  # 顯示進度
try {
    $FirewallProfiles = Get-NetFirewallProfile  # 取得所有防火牆設定檔
    
    foreach ($Profile in $FirewallProfiles) {  # 遍歷每個設定檔
        $StatusColor = if ($Profile.Enabled) { "Green" } else { "Yellow" }  # 根據狀態設定顏色
        Write-Host "  $($Profile.Name) 設定檔：$($Profile.Enabled)" -ForegroundColor $StatusColor  # 顯示設定檔狀態
    }
    
    Write-Host "✓ 防火牆檢查完成" -ForegroundColor Green  # 檢查完成
} catch {
    Write-Host "✗ 防火牆檢查失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# ==========================================
# 顯示完成訊息
# ==========================================
Write-Host "`n`n===============================================================================" -ForegroundColor Cyan
Write-Host "  系統安全性與設定完成" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "`n驗證命令：" -ForegroundColor Yellow
Write-Host "  Get-MpComputerStatus                    # 檢查 Defender 狀態" -ForegroundColor Gray
Write-Host "  Get-MpPreference                        # 檢查 Defender 偏好設定" -ForegroundColor Gray
Write-Host "  Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\*'  # 檢查 Edge 設定" -ForegroundColor Gray
Write-Host "  Get-NetFirewallProfile                  # 檢查防火牆狀態" -ForegroundColor Gray
Write-Host ""  # 空行
