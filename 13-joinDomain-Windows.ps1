# ===============================
#  Windows 電腦加入網域
#  用於 HR-xx 等 Windows 電腦加入 tcivs.com.tw 網域
# ===============================

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  Windows 電腦加入網域" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 設定參數
$DomainName = "tcivs.com.tw"  # 網域名稱

# 提示輸入電腦名稱
$ComputerName = Read-Host "請輸入此電腦的名稱（例如：HR-01）"  # 讀取電腦名稱
if ([string]::IsNullOrWhiteSpace($ComputerName)) {  # 檢查是否為空
    Write-Host "❌ 錯誤：電腦名稱不能為空！" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 顯示即將執行的動作
Write-Host "`n即將執行的動作：" -ForegroundColor Cyan
Write-Host "  1. 重新命名電腦為：$ComputerName" -ForegroundColor White  # 顯示重新命名動作
Write-Host "  2. 加入網域：$DomainName" -ForegroundColor White  # 顯示加入網域動作
Write-Host "  3. 重新啟動電腦" -ForegroundColor White  # 顯示重新啟動動作
Write-Host ""  # 空行

# 確認是否繼續
$Confirm = Read-Host "是否繼續？(Y/N)"  # 要求確認
if ($Confirm -ne 'Y' -and $Confirm -ne 'y') {  # 若未確認
    Write-Host "❌ 已取消作業" -ForegroundColor Red  # 顯示取消訊息
    exit  # 結束腳本
}

# 提示輸入網域管理員認證
Write-Host "`n請輸入網域管理員認證：" -ForegroundColor Yellow  # 提示輸入認證
$Credential = Get-Credential -Message "請輸入 $DomainName 的管理員帳號密碼"  # 取得認證

# 步驟 1：重新命名電腦（如果需要）
Write-Host "`n步驟 1：檢查電腦名稱..." -ForegroundColor Cyan  # 顯示進度
$CurrentName = $env:COMPUTERNAME  # 取得目前電腦名稱

if ($CurrentName -ne $ComputerName) {  # 若名稱不同
    Write-Host "正在重新命名電腦..." -ForegroundColor Cyan  # 顯示進度
    try {
        Rename-Computer -NewName $ComputerName -Force -ErrorAction Stop  # 重新命名電腦
        Write-Host "✓ 電腦已重新命名為：$ComputerName" -ForegroundColor Green  # 重新命名完成
        $NeedReboot = $true  # 標記需要重新啟動
    } catch {
        Write-Host "✗ 重新命名失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
        exit  # 結束腳本
    }
} else {
    Write-Host "✓ 電腦名稱已是：$ComputerName" -ForegroundColor Green  # 名稱已正確
}

# 步驟 2：加入網域
Write-Host "`n步驟 2：加入網域..." -ForegroundColor Cyan  # 顯示進度
try {
    Add-Computer -DomainName $DomainName -Credential $Credential -Force -ErrorAction Stop  # 將電腦加入網域
    Write-Host "✓ 已成功加入網域：$DomainName" -ForegroundColor Green  # 加入完成
    $NeedReboot = $true  # 標記需要重新啟動
} catch {
    Write-Host "✗ 加入網域失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    Write-Host "`n可能的原因：" -ForegroundColor Yellow  # 顯示可能原因
    Write-Host "  - DNS 設定不正確（請確認 DNS 指向網域控制站）" -ForegroundColor Yellow
    Write-Host "  - 網路連線問題" -ForegroundColor Yellow
    Write-Host "  - 管理員認證錯誤" -ForegroundColor Yellow
    Write-Host "  - 網域控制站無法連線" -ForegroundColor Yellow
    exit  # 結束腳本
}

# 步驟 3：重新啟動電腦
Write-Host "`n步驟 3：重新啟動電腦..." -ForegroundColor Cyan  # 顯示進度
if ($NeedReboot) {  # 若需要重新啟動
    Write-Host "⚠  電腦將在 10 秒後自動重新啟動..." -ForegroundColor Yellow  # 顯示警告
    Write-Host "   按 Ctrl+C 可取消重新啟動" -ForegroundColor Yellow  # 提示取消方法
    Start-Sleep -Seconds 10  # 等待 10 秒
    
    try {
        Restart-Computer -Force  # 強制重新啟動電腦
    } catch {
        Write-Host "✗ 重新啟動失敗，請手動重新啟動電腦" -ForegroundColor Red  # 顯示錯誤訊息
    }
} else {
    Write-Host "⊙ 不需要重新啟動" -ForegroundColor Yellow  # 不需重新啟動
}

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  作業完成" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "`n電腦重新啟動後，請使用網域帳號登入：" -ForegroundColor Yellow
Write-Host "  使用者名稱：TCIVS\Administrator（或其他網域帳號）" -ForegroundColor White  # 顯示登入提示
Write-Host ""  # 空行
