# ===============================
#  Windows Server 2022 - 安裝 AD CS 企業根 CA (Enterprise Root CA)
#  目標：Branch-XX 為 tcivs.com.tw 網域的企業根 CA，發行 Web/遠端服務憑證，網域成員自動信任
#  調整：加入系統管理員/DC/模組檢查，建立 CA、匯出並發佈根憑證，設定 WebServer 模板權限與自動註冊 GPO
# ===============================

param(
    [string]$DomainFqdn   = "tcivs.com.tw",
    [string]$CaCommonName = "TCIVS-ROOT-CA",
    [int]   $KeyLength    = 2048,
    [string]$HashAlgorithm = "SHA256",
    [int]   $ValidityYears = 10,
    [string]$RootCerPath   = "C:\PKI\TCIVS-ROOT-CA.cer",
    [string]$CRLPath       = "C:\PKI\CRL",
    [string]$GpoName       = "TCIVS-Cert-AutoEnrollment",
    [string]$WebTemplate   = "WebServer"
)

function Write-Result {
    param([bool]$Ok,[string]$Message)
    if ($Ok) { Write-Host "[通過] $Message" -ForegroundColor Green }
    else { Write-Host "[失敗] $Message" -ForegroundColor Red }
}
function Write-Warn($msg){ Write-Host "[警告] $msg" -ForegroundColor Yellow }

# ===== 權限與角色檢查 =====
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Result $false "請以系統管理員身分執行此腳本。"
    exit 1
}

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module DnsServer -ErrorAction SilentlyContinue | Out-Null
} catch {
    Write-Result $false "無法載入必要模組 (ActiveDirectory/DnsServer)：$($_.Exception.Message)"
    exit 1
}

# 確認為網域控制站
$role = (Get-CimInstance -ClassName Win32_ComputerSystem).DomainRole
if ($role -lt 4) {
    Write-Result $false "本機不是網域控制站，請先完成 AD DS 安裝。"
    exit 1
}

# 將網域名稱與 AD 同步
try {
    $adDomain = Get-ADDomain -ErrorAction Stop
    if ($adDomain.DNSRoot -ne $DomainFqdn) {
        Write-Warn "目前網域為 $($adDomain.DNSRoot)，改用此網域。"
        $DomainFqdn = $adDomain.DNSRoot
    }
} catch {
    Write-Result $false "無法取得 AD 網域資訊：$($_.Exception.Message)"
    exit 1
}

# ===== 建立必要資料夾 =====
New-Item -ItemType Directory -Path (Split-Path $RootCerPath) -Force | Out-Null
New-Item -ItemType Directory -Path $CRLPath -Force | Out-Null

# ===== 安裝 AD CS 角色 =====
Write-Host "`n安裝 AD CS (Enterprise Root CA)..." -ForegroundColor Cyan
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools | Out-Null

# ===== 安裝/設定 CA =====
Write-Host "建立企業根 CA..." -ForegroundColor Cyan
Install-AdcsCertificationAuthority `
  -CAType EnterpriseRootCA `
  -CACommonName $CaCommonName `
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
  -KeyLength $KeyLength `
  -HashAlgorithm $HashAlgorithm `
  -ValidityPeriod Years `
  -ValidityPeriodUnits $ValidityYears `
  -Force

Restart-Service CertSvc

# ===== 匯出並發佈根憑證 =====
$root = Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object { $_.Subject -like "*CN=$CaCommonName*" } | Select-Object -First 1
if (-not $root) {
    Write-Result $false "找不到根憑證，請檢查 CA 安裝。"
    exit 1
}
Export-Certificate -Cert $root -FilePath $RootCerPath | Out-Null
Write-Result $true "根憑證已匯出到 $RootCerPath"

certutil -dspublish -f $RootCerPath RootCA  | Out-Null
certutil -dspublish -f $RootCerPath NTAuthCA | Out-Null
Write-Result $true "根憑證已發佈至 AD (RootCA/NTAuthCA)"

# ===== 設定 CRL/AIA 發佈路徑 (使用 AD 與本機檔案) =====
certutil -setreg CA\CRLPeriodUnits 1 | Out-Null
certutil -setreg CA\CRLPeriod "Weeks" | Out-Null
certutil -setreg CA\CRLPublicationURLs "1:%WINDIR%\system32\CertSrv\CertEnroll\%3%8%9.crl|2:ldap:///CN=%7,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10" | Out-Null
certutil -setreg CA\CACertPublicationURLs "1:%WINDIR%\system32\CertSrv\CertEnroll\%1_%3%4.crt|2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11" | Out-Null

Restart-Service CertSvc

# ===== 公布 WebServer 模板並賦予 Domain Computers Enroll/Autoenroll =====
certutil -setcatemplates +$WebTemplate | Out-Null

$rootDse   = [ADSI]"LDAP://RootDSE"
$configNC  = $rootDse.configurationNamingContext
$template  = [ADSI]("LDAP://CN=$WebTemplate,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC")

$domComputers = New-Object System.Security.Principal.NTAccount("Domain Computers")
$domComputersSid = $domComputers.Translate([System.Security.Principal.SecurityIdentifier])
$ENROLL     = [Guid]"0e8a5346-9e87-4a0d-8c9a-62b731e4c2a9"
$AUTOENROLL = [Guid]"a05b8cc2-17bc-4802-a710-e7c15ab866a2"
$rights     = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
$allow      = [System.Security.AccessControl.AccessControlType]::Allow

$ace1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($domComputersSid, $rights, $allow, $ENROLL)
$ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($domComputersSid, $rights, $allow, $AUTOENROLL)
$sd = $template.ObjectSecurity
$sd.AddAccessRule($ace1) | Out-Null
$sd.AddAccessRule($ace2) | Out-Null
$template.ObjectSecurity = $sd
$template.CommitChanges()
Write-Result $true "已允許 Domain Computers 使用 $WebTemplate 模板 (Enroll/Autoenroll)"

# ===== 建立並連結 AutoEnrollment GPO (電腦) =====
Import-Module GroupPolicy
if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {
    New-GPO -Name $GpoName | Out-Null
}
$domainDN = "DC=" + $DomainFqdn.Replace(".",",DC=")
New-GPLink -Name $GpoName -Target $domainDN -Enforced:$true -ErrorAction SilentlyContinue | Out-Null

Set-GPRegistryValue -Name $GpoName `
  -Key "HKLM\Software\Policies\Microsoft\Cryptography\AutoEnrollment" `
  -ValueName "AEPolicy" -Type DWord -Value 7

Write-Result $true "已建立/連結 GPO '$GpoName' 至 $domainDN，啟用電腦自動註冊"

Write-Host "`n請稍待 GPO 複寫；如需立即套用可在用戶端執行 gpupdate /force。" -ForegroundColor Yellow
Write-Host "[完成] 企業根 CA 安裝與自動信任設定已完成。" -ForegroundColor Green
