# ===============================
#  Windows Server 2022 - 刪除 Sales 使用者（依附表 B）
#  目標：刪除 Branch-xx 的 Sales01~Sales100，可選奇數或偶數（50 個帳號）
# ===============================

[CmdletBinding()]
param(
    [ValidateSet('Odd','Even')]
    [string]$DeleteMode
)

function Write-Result {
    param([bool]$Ok,[string]$Message)
    if ($Ok) { Write-Host "[通過] $Message" -ForegroundColor Green }
    else { Write-Host "[失敗] $Message" -ForegroundColor Red }
}

# 權限檢查
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Result $false "請以系統管理員身分執行此腳本。"
    exit 1
}

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  刪除 Sales 使用者（Sales01~Sales100，奇/偶數可選）" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

if (-not $DeleteMode) {
    Write-Host "請選擇刪除範圍：" -ForegroundColor Yellow
    Write-Host "  1) 奇數帳號（Sales01, Sales03, ... Sales99）"
    Write-Host "  2) 偶數帳號（Sales02, Sales04, ... Sales100）"
    $choice = Read-Host "輸入 1 或 2"
    switch ($choice) {
        '1' { $DeleteMode = 'Odd' }
        '2' { $DeleteMode = 'Even' }
        default { Write-Result $false "輸入無效，請輸入 1 或 2。"; exit 1 }
    }
}

$start = if ($DeleteMode -eq 'Even') { 2 } else { 1 }
$label = if ($DeleteMode -eq 'Even') { "偶數" } else { "奇數" }

Write-Host "`n將刪除 $label Sales 帳號（共 50 個）：" -ForegroundColor Yellow
for ($i = $start; $i -le 10; $i += 2) {
    $num = "{0:D2}" -f $i
    Write-Host "  - Sales$num" -ForegroundColor Gray
}
Write-Host "  ... (共 50 個)" -ForegroundColor Gray

$confirm = Read-Host "`n確認刪除？ (Y/N)"
if ($confirm -notin @('Y','y')) {
    Write-Host "[取消] 未執行刪除。" -ForegroundColor Red
    exit 0
}

Write-Host "`n開始刪除..." -ForegroundColor Cyan
$deleted = 0
$missing = 0
for ($i = $start; $i -le 100; $i += 2) {
    $num = "{0:D2}" -f $i
    $user = "Sales$num"
    try {
        Remove-ADUser -Identity $user -Confirm:$false -ErrorAction Stop
        Write-Host "  已刪除：$user" -ForegroundColor Green
        $deleted++
    } catch {
        Write-Host "  找不到帳號或已刪除：$user" -ForegroundColor Yellow
        $missing++
    }
}

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  刪除結果" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  成功刪除：$deleted"
Write-Host "  未找到：$missing"
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "目前剩餘 Sales* 帳號數量：" -ForegroundColor Cyan
$remaining = Get-ADUser -Filter 'Name -like "Sales*"' | Measure-Object
Write-Host "  $($remaining.Count) 個帳號" -ForegroundColor Green
