# ===============================
#  Windows Server 2022 - 建立 RD 使用者批次
#  依附表 B：RD01~RD50，群組 RDGroup，密碼 RD2024@
# ===============================

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

$GroupName = "RDGroup"
$Password = ConvertTo-SecureString "RD2024@" -AsPlainText -Force
$UserCount = 50

$domain = Get-ADDomain
$DomainDN = $domain.DistinguishedName
$UPNSuffix = $domain.DNSRoot
$OUPath = "CN=Users,$DomainDN"

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  建立 RD 使用者（RD01~RD50）" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  群組：$GroupName" -ForegroundColor White
Write-Host "  密碼：RD2024@" -ForegroundColor White
Write-Host "  網域：$UPNSuffix" -ForegroundColor White
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 確保群組存在
try {
    Get-ADGroup -Identity $GroupName -ErrorAction Stop | Out-Null
    Write-Result $true "$GroupName 已存在"
} catch {
    New-ADGroup -Name $GroupName -GroupScope Global -GroupCategory Security -Path $OUPath -Description "RD Department Group"
    Write-Result $true "已建立群組 $GroupName"
}

Write-Host "`n開始建立使用者..." -ForegroundColor Cyan
$created = 0
$skipped = 0

for ($i = 1; $i -le $UserCount; $i++) {
    $UserNumber = "{0:D2}" -f $i
    $UserName = "RD$UserNumber"
    $UPN = "$UserName@$UPNSuffix"
    try {
        Get-ADUser -Identity $UserName -ErrorAction Stop | Out-Null
        Write-Host "  已存在：$UserName（略過）" -ForegroundColor Yellow
        $skipped++
    } catch {
        New-ADUser `
            -Name $UserName `
            -SamAccountName $UserName `
            -UserPrincipalName $UPN `
            -AccountPassword $Password `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -ChangePasswordAtLogon $false `
            -Description "RD Department User" `
            -Path $OUPath
        Add-ADGroupMember -Identity $GroupName -Members $UserName
        Write-Host "  建立完成：$UserName" -ForegroundColor Green
        $created++
    }
}

Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  建立結果" -ForegroundColor Cyan
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  新增：$created"
Write-Host "  已存在略過：$skipped"
Write-Host "===============================================================================`n" -ForegroundColor Cyan

Write-Host "群組 $GroupName 目前成員數：" -ForegroundColor Cyan
$members = Get-ADGroupMember -Identity $GroupName
Write-Host "  $($members.Count) 位成員" -ForegroundColor Green
