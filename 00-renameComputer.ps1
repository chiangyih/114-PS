# ===============================
#  Windows Server 2022 - 重新命名電腦
#  根據 113 年工科技藝競賽要求
# ===============================

# 提示使用者輸入新的電腦名稱
$NewComputerName = Read-Host "請輸入伺服器主機名稱（例如：Branch-01）"  # 提示使用者輸入新的電腦名稱，並儲存在變數中

# 驗證輸入不為空
if ([string]::IsNullOrWhiteSpace($NewComputerName)) {  # 檢查使用者輸入是否為空白或空字串
    Write-Host "❌ 錯誤：主機名稱不能為空！" -ForegroundColor Red  # 以紅色顯示錯誤訊息
    exit  # 結束腳本執行
}

# 顯示即將執行的動作
Write-Host "`n即將重新命名電腦為：$NewComputerName" -ForegroundColor Yellow  # 以黃色顯示即將執行的動作
Write-Host "重新命名後系統將自動重新啟動！" -ForegroundColor Yellow  # 警告使用者系統將重新啟動

# 確認是否繼續
$Confirm = Read-Host "是否繼續？(Y/N)"  # 要求使用者確認是否繼續

if ($Confirm -eq 'Y' -or $Confirm -eq 'y') {  # 檢查使用者輸入是否為 Y 或 y
    Write-Host "`n正在重新命名電腦..." -ForegroundColor Cyan  # 以青色顯示執行訊息
    Rename-Computer -NewName $NewComputerName -Restart  # 執行重新命名電腦的命令，並在完成後自動重新啟動系統
} else {  # 使用者選擇不繼續
    Write-Host "❌ 已取消重新命名作業" -ForegroundColor Red  # 以紅色顯示取消訊息
}
