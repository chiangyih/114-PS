# ===============================
#  Windows Server 2022 - 刪除使用者帳號
#  刪除 Sales01 ~ Sales100 中的偶數或奇數編號使用者
#  可由使用者選擇刪除奇數或偶數編號
# ===============================

# 匯入 Active Directory 模組
Import-Module ActiveDirectory  # 匯入 AD 模組以使用 AD 相關的 Cmdlet

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  刪除 Sales 使用者帳號" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan

# 提示使用者選擇刪除奇數或偶數編號
Write-Host "`n請選擇要刪除的使用者編號類型：" -ForegroundColor Yellow
Write-Host "  1) 奇數編號（Sales01, Sales03, Sales05, ..., Sales99）" -ForegroundColor White
Write-Host "  2) 偶數編號（Sales02, Sales04, Sales06, ..., Sales100）" -ForegroundColor White
Write-Host ""  # 空行

$Choice = Read-Host "請輸入選項（1 或 2）"  # 讀取使用者選擇

# 驗證輸入
if ($Choice -ne "1" -and $Choice -ne "2") {  # 檢查輸入是否有效
    Write-Host "❌ 錯誤：無效的選項！請輸入 1 或 2。" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 設定刪除類型
if ($Choice -eq "1") {  # 若選擇 1
    $DeleteType = "奇數"  # 設定刪除類型為奇數
    $StartNumber = 1  # 起始編號為 1
    $Step = 2  # 步進值為 2（1, 3, 5, ...）
} else {  # 若選擇 2
    $DeleteType = "偶數"  # 設定刪除類型為偶數
    $StartNumber = 2  # 起始編號為 2
    $Step = 2  # 步進值為 2（2, 4, 6, ...）
}

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  即將刪除 $DeleteType 編號的使用者（共 50 個）" -ForegroundColor Yellow
Write-Host "===============================================================================" -ForegroundColor Cyan

# 顯示即將刪除的使用者範例
Write-Host "`n範例使用者名稱：" -ForegroundColor White
for ($i = $StartNumber; $i -le 10; $i += $Step) {  # 顯示前 5 個範例
    $UserNumber = "{0:D2}" -f $i  # 格式化為兩位數
    Write-Host "  - Sales$UserNumber" -ForegroundColor Gray  # 顯示範例使用者名稱
}
Write-Host "  ... (共 50 個)" -ForegroundColor Gray  # 顯示省略符號

# 確認是否繼續
Write-Host ""  # 空行
$Confirm = Read-Host "確定要刪除這些使用者嗎？(Y/N)"  # 要求確認

if ($Confirm -ne 'Y' -and $Confirm -ne 'y') {  # 若使用者未確認
    Write-Host "❌ 已取消刪除作業" -ForegroundColor Red  # 顯示取消訊息
    exit  # 結束腳本
}

# 開始刪除使用者
Write-Host "`n開始刪除使用者..." -ForegroundColor Cyan  # 顯示進度訊息
$DeletedCount = 0  # 初始化刪除計數器
$NotFoundCount = 0  # 初始化未找到計數器

for ($i = $StartNumber; $i -le 100; $i += $Step) {  # 迴圈從起始編號到 100，每次增加步進值
    $UserNumber = "{0:D2}" -f $i  # 格式化數字為兩位數
    $UserName = "Sales$UserNumber"  # 組合使用者名稱
    
    try {
        # 嘗試刪除使用者
        Remove-ADUser -Identity $UserName -Confirm:$false -ErrorAction Stop  # 刪除使用者，不顯示確認提示
        Write-Host "  ✓ 已刪除：$UserName" -ForegroundColor Green  # 顯示刪除成功訊息
        $DeletedCount++  # 刪除計數器加 1
    } catch {
        # 使用者不存在或刪除失敗
        Write-Host "  ✗ 找不到：$UserName（可能已被刪除）" -ForegroundColor Yellow  # 顯示未找到訊息
        $NotFoundCount++  # 未找到計數器加 1
    }
}

# 顯示結果摘要
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  刪除作業完成" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  成功刪除：$DeletedCount 個使用者" -ForegroundColor Green  # 顯示成功刪除的數量
Write-Host "  未找到：$NotFoundCount 個使用者" -ForegroundColor Yellow  # 顯示未找到的數量
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 驗證剩餘使用者
Write-Host "驗證剩餘的 Sales 使用者..." -ForegroundColor Cyan  # 顯示驗證訊息
$RemainingUsers = Get-ADUser -Filter 'Name -like "Sales*"' | Measure-Object  # 取得所有 Sales 開頭的使用者並計數
Write-Host "✓ 目前剩餘 $($RemainingUsers.Count) 個 Sales 使用者`n" -ForegroundColor Green  # 顯示剩餘使用者數量
