# ===============================
#  Windows Server 2022 - 建立使用者帳號
#  建立 Sales01 ~ Sales100 共 100 個使用者
#  群組：SalesGroup
#  密碼：Sales2024@
# ===============================

# 匯入 Active Directory 模組
Import-Module ActiveDirectory  # 匯入 AD 模組以使用 AD 相關的 Cmdlet

# 設定參數
$GroupName = "SalesGroup"  # 定義群組名稱
$Password = ConvertTo-SecureString "Sales2024@" -AsPlainText -Force  # 將明文密碼轉換為安全字串格式
$UserCount = 100  # 設定要建立的使用者數量

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  建立 Sales 使用者帳號（Sales01 ~ Sales100）" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  群組名稱：$GroupName" -ForegroundColor White
Write-Host "  密碼：Sales2024@" -ForegroundColor White
Write-Host "  使用者數量：$UserCount" -ForegroundColor White
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 取得網域 DN（Distinguished Name）
$DomainDN = (Get-ADDomain).DistinguishedName  # 取得網域的辨別名稱，例如：DC=tcivs,DC=com,DC=tw
$OUPath = "CN=Users,$DomainDN"  # 設定使用者的組織單位路徑，預設為 Users 容器

# 建立 SalesGroup 群組（如果不存在）
Write-Host "檢查並建立群組：$GroupName..." -ForegroundColor Cyan  # 顯示進度訊息
try {
    $Group = Get-ADGroup -Identity $GroupName -ErrorAction Stop  # 嘗試取得群組，若不存在會觸發錯誤
    Write-Host "✓ 群組 $GroupName 已存在" -ForegroundColor Green  # 群組已存在
} catch {
    # 群組不存在，建立新群組
    New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path "CN=Users,$DomainDN" -Description "Sales Department Group"  # 建立全域安全性群組
    Write-Host "✓ 已建立群組：$GroupName" -ForegroundColor Green  # 顯示建立成功訊息
}

# 建立使用者
Write-Host "`n開始建立使用者帳號..." -ForegroundColor Cyan  # 顯示進度訊息
$SuccessCount = 0  # 初始化成功計數器
$SkipCount = 0  # 初始化略過計數器

for ($i = 1; $i -le $UserCount; $i++) {  # 迴圈從 1 到 100
    $UserNumber = "{0:D2}" -f $i  # 格式化數字為兩位數，例如：01, 02, ..., 99, 100
    $UserName = "Sales$UserNumber"  # 組合使用者名稱，例如：Sales01
    
    try {
        # 檢查使用者是否已存在
        $ExistingUser = Get-ADUser -Identity $UserName -ErrorAction Stop  # 嘗試取得使用者
        Write-Host "  ⊙ $UserName 已存在（略過）" -ForegroundColor Yellow  # 使用者已存在，略過
        $SkipCount++  # 略過計數器加 1
    } catch {
        # 使用者不存在，建立新使用者
        New-ADUser `
            -Name $UserName `  # 設定使用者名稱
            -SamAccountName $UserName `  # 設定 SAM 帳戶名稱（登入名稱）
            -UserPrincipalName "$UserName@tcivs.com.tw" `  # 設定使用者主體名稱（UPN）
            -AccountPassword $Password `  # 設定密碼
            -Enabled $true `  # 啟用帳號
            -PasswordNeverExpires $true `  # 設定密碼永不過期
            -ChangePasswordAtLogon $false `  # 設定登入時不需要變更密碼
            -Description "Sales Department User" `  # 設定使用者描述
            -Path $OUPath  # 設定使用者所在的組織單位
        
        # 將使用者加入群組
        Add-ADGroupMember -Identity $GroupName -Members $UserName  # 將使用者加入 SalesGroup 群組
        
        Write-Host "  ✓ 已建立：$UserName" -ForegroundColor Green  # 顯示建立成功訊息
        $SuccessCount++  # 成功計數器加 1
    }
}

# 顯示結果摘要
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  建立作業完成" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  成功建立：$SuccessCount 個使用者" -ForegroundColor Green  # 顯示成功建立的數量
Write-Host "  已存在略過：$SkipCount 個使用者" -ForegroundColor Yellow  # 顯示略過的數量
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 驗證群組成員
Write-Host "驗證群組成員數量..." -ForegroundColor Cyan  # 顯示驗證訊息
$Members = Get-ADGroupMember -Identity $GroupName  # 取得群組所有成員
Write-Host "✓ $GroupName 群組目前有 $($Members.Count) 個成員`n" -ForegroundColor Green  # 顯示群組成員數量
