# ===============================
#  Windows Server 2022 - 設定 NTP 授時伺服器
#  將 Branch-xx 設為網域的授時伺服器
# ===============================

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  設定 NTP 授時伺服器" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 步驟 1：設定本機為可靠的時間來源
Write-Host "步驟 1：設定本機為可靠的時間來源..." -ForegroundColor Cyan  # 顯示進度
try {
    # 設定本機時鐘為可靠的時間來源
    w32tm /config /reliable:YES  # 將本機設定為可靠的時間來源，適用於網域的 PDC 模擬器
    Write-Host "✓ 已將本機設定為可靠的時間來源" -ForegroundColor Green  # 設定完成
} catch {
    Write-Host "✗ 設定失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 2：設定外部 NTP 伺服器（可選）
Write-Host "`n步驟 2：設定外部 NTP 伺服器..." -ForegroundColor Cyan  # 顯示進度
$UseExternalNTP = Read-Host "是否要設定外部 NTP 伺服器？(Y/N)"  # 詢問是否設定外部 NTP

if ($UseExternalNTP -eq 'Y' -or $UseExternalNTP -eq 'y') {  # 若選擇是
    # 建議使用台灣的 NTP 伺服器
    $NTPServers = "time.stdtime.gov.tw,tock.stdtime.gov.tw,watch.stdtime.gov.tw"  # 台灣國家時間與頻率標準實驗室的 NTP 伺服器
    
    Write-Host "使用 NTP 伺服器：$NTPServers" -ForegroundColor White  # 顯示 NTP 伺服器
    
    try {
        # 設定 NTP 伺服器
        w32tm /config /manualpeerlist:$NTPServers /syncfromflags:manual /update  # 手動設定 NTP 伺服器清單並更新設定
        Write-Host "✓ 已設定外部 NTP 伺服器" -ForegroundColor Green  # 設定完成
    } catch {
        Write-Host "✗ 設定外部 NTP 伺服器失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    }
} else {
    Write-Host "⊙ 略過外部 NTP 伺服器設定（使用本機時鐘）" -ForegroundColor Yellow  # 略過設定
}

# 步驟 3：設定 Windows Time 服務為自動啟動
Write-Host "`n步驟 3：設定 Windows Time 服務..." -ForegroundColor Cyan  # 顯示進度
try {
    Set-Service W32Time -StartupType Automatic  # 設定 Windows Time 服務為自動啟動
    Write-Host "✓ Windows Time 服務已設定為自動啟動" -ForegroundColor Green  # 設定完成
} catch {
    Write-Host "✗ 設定服務失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 4：重新啟動 Windows Time 服務
Write-Host "`n步驟 4：重新啟動 Windows Time 服務..." -ForegroundColor Cyan  # 顯示進度
try {
    Restart-Service W32Time  # 重新啟動 Windows Time 服務以套用設定
    Write-Host "✓ Windows Time 服務已重新啟動" -ForegroundColor Green  # 重新啟動完成
} catch {
    Write-Host "✗ 重新啟動服務失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 5：強制立即同步時間
Write-Host "`n步驟 5：強制同步時間..." -ForegroundColor Cyan  # 顯示進度
try {
    w32tm /resync /rediscover  # 重新探索時間來源並強制同步時間
    Write-Host "✓ 時間同步完成" -ForegroundColor Green  # 同步完成
} catch {
    Write-Host "⊙ 同步時可能發生警告（這是正常的）" -ForegroundColor Yellow  # 顯示警告訊息
}

# 步驟 6：設定網域時間階層（Group Policy）
Write-Host "`n步驟 6：設定網域時間階層..." -ForegroundColor Cyan  # 顯示進度
Write-Host "⊙ 網域成員電腦會自動從網域控制站同步時間" -ForegroundColor Yellow  # 說明
Write-Host "⊙ 如需強制網域電腦同步，請在各電腦上執行：w32tm /resync" -ForegroundColor Yellow  # 提示

# 顯示完成訊息和驗證資訊
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  NTP 授時伺服器設定完成" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "`n驗證命令：" -ForegroundColor Yellow
Write-Host "  w32tm /query /status" -ForegroundColor Gray  # 查詢時間服務狀態
Write-Host "  w32tm /query /configuration" -ForegroundColor Gray  # 查詢時間服務設定
Write-Host "  w32tm /query /peers" -ForegroundColor Gray  # 查詢時間對等端
Write-Host "  Get-Service W32Time" -ForegroundColor Gray  # 查詢服務狀態
Write-Host ""  # 空行

# 顯示目前狀態
Write-Host "目前時間服務狀態：" -ForegroundColor Cyan  # 顯示標題
w32tm /query /status  # 執行查詢命令顯示詳細狀態
