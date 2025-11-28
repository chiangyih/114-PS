# ===============================
#  Windows Server 2022 - 建立 AD DS 網域（可自訂網域名稱）
#  預設網域：tcivs.com.tw；自動推算 NetBIOS 名稱（取第一段，轉大寫，最多 15 字）
# ===============================

# ---- 基本檢查：需系統管理員權限 ----
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host "[錯誤] 請以系統管理員身分執行此腳本。" -ForegroundColor Red
    exit 1
}

# ---- 取得網域名稱（可按 Enter 使用預設）----
$defaultDomain = "tcivs.com.tw"
$DomainNameInput = Read-Host "輸入網域 FQDN（預設：$defaultDomain）"
$DomainName = if ([string]::IsNullOrWhiteSpace($DomainNameInput)) { $defaultDomain } else { $DomainNameInput.Trim() }

# ---- 推算 NetBIOS 名稱並允許覆寫 ----
function Get-NetBIOSNameFromDomain {
    param([string]$fqdn)
    $label = ($fqdn -split '\.')[0]
    if ([string]::IsNullOrWhiteSpace($label)) { return "ADDOMAIN" }
    $label = $label.ToUpper() -replace '[^A-Z0-9-]', ''
    $label = $label.Trim('-')
    if ([string]::IsNullOrWhiteSpace($label)) { return "ADDOMAIN" }
    return $label.Substring(0, [Math]::Min(15, $label.Length))
}

$DomainNetBIOS = Get-NetBIOSNameFromDomain -fqdn $DomainName
$DomainNetBIOSInput = Read-Host "輸入 NetBIOS 名稱（預設：$DomainNetBIOS）"
if (-not [string]::IsNullOrWhiteSpace($DomainNetBIOSInput)) {
    $DomainNetBIOS = $DomainNetBIOSInput.Trim().ToUpper()
}

# ---- 輸入 DSRM 密碼 ----
$SafeModePassword = Read-Host "輸入 DSRM 管理員密碼（不會顯示）" -AsSecureString

Write-Host "`n將安裝 AD DS 並建立新樹系：" -ForegroundColor Cyan
Write-Host "  FQDN     : $DomainName"
Write-Host "  NetBIOS  : $DomainNetBIOS"
Write-Host "  安裝 DNS : 是" -ForegroundColor White
$confirm = Read-Host "確認開始？ (Y/N)"
if ($confirm -notin @('Y', 'y')) {
    Write-Host "[取消] 未進行安裝。" -ForegroundColor Yellow
    exit 0
}

# ---- 檢查是否已經有網域（若已存在則中止）----
$existingDomain = $null
if (Get-Command Get-ADDomain -ErrorAction SilentlyContinue) {
    try { $existingDomain = Get-ADDomain -ErrorAction Stop } catch { }
}
if ($existingDomain) {
    Write-Host "[錯誤] 本機已屬於網域 '$($existingDomain.Name)'，不再建立新樹系。" -ForegroundColor Red
    exit 1
}

# ---- 安裝 AD DS 角色與管理工具 ----
Write-Host "`n安裝 AD DS 角色與管理工具..." -ForegroundColor Cyan
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# ---- 建立樹系與網域並安裝 DNS ----
Write-Host "開始建立樹系與網域（將會自動重開機）..." -ForegroundColor Cyan
Install-ADDSForest `
  -DomainName $DomainName `
  -DomainNetbiosName $DomainNetBIOS `
  -InstallDNS `
  -SafeModeAdministratorPassword $SafeModePassword `
  -Force

# ---- 完成提示 ----
Write-Host "`n[完成] AD DS 安裝程序已觸發，伺服器將自動重新啟動。" -ForegroundColor Green
