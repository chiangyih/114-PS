# ===============================
#  AD CS Enterprise Root CA 一鍵部署
#  Windows Server 2022 — Branch-01
#  Domain: tcivs.com.tw
# ===============================

# ---- 變數 ----
$DomainFqdn     = "tcivs.com.tw"
$CaCommonName   = "TCIVS-ROOT-CA"
$KeyLength      = 2048
$HashAlgorithm  = "SHA256"
$ValidityYears  = 10
$RootCerPath    = "C:\PKI\TCIVS-ROOT-CA.cer"
$CRLPath        = "C:\PKI\CRL"
$GpoName        = "TCIVS-Cert-AutoEnrollment"
$WebTemplate    = "WebServer"

# ---- 建立必要目錄 ----
New-Item -ItemType Directory -Path (Split-Path $RootCerPath) -Force | Out-Null
New-Item -ItemType Directory -Path $CRLPath -Force | Out-Null

# ---- 安裝 AD CS 角色 ----
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

# ---- 建立企業根 CA ----
$DSRM = Read-Host "請輸入 DSRM 密碼" -AsSecureString

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

# ---- 匯出根憑證並發佈到 AD ----
$root = Get-ChildItem -Path Cert:\LocalMachine\CA | 
        Where-Object { $_.Subject -like "*CN=$CaCommonName*" } | 
        Select-Object -First 1

Export-Certificate -Cert $root -FilePath $RootCerPath | Out-Null

certutil -dspublish -f $RootCerPath RootCA
certutil -dspublish -f $RootCerPath NTAuthCA

# ---- 設定 CRL/AIA 發佈（使用 AD 預設為主）----
certutil -setreg CA\CRLPeriodUnits 1
certutil -setreg CA\CRLPeriod "Weeks"
certutil -setreg CA\CRLPublicationURLs "1:%WINDIR%\system32\CertSrv\CertEnroll\%3%8%9.crl|2:ldap:///CN=%7,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10"

certutil -setreg CA\CACertPublicationURLs "1:%WINDIR%\system32\CertSrv\CertEnroll\%1_%3%4.crt|2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11"

Restart-Service CertSvc

# ---- CA 啟用 WebServer 範本 ----
certutil -setcatemplates +$WebTemplate

# ---- WebServer Template 加入 "Domain Computers" Enroll/Autoenroll ----
$rootDse   = [ADSI]"LDAP://RootDSE"
$configNC  = $rootDse.configurationNamingContext
$template  = [ADSI]("LDAP://CN=$WebTemplate,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC")

$domComputers = New-Object System.Security.Principal.NTAccount("Domain Computers")
$domComputersSid = $domComputers.Translate([System.Security.Principal.SecurityIdentifier])

$ENROLL     = [Guid]"0e8a5346-9e87-4a0d-8c9a-62b731e4c2a9"
$AUTOENROLL = [Guid]"a05b8cc2-17bc-4802-a710-e7c15ab866a2"
$adRights   = [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
$allow      = [System.Security.AccessControl.AccessControlType]::Allow

$ace1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($domComputersSid, $adRights, $allow, $ENROLL)
$ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($domComputersSid, $adRights, $allow, $AUTOENROLL)

$sd = $template.ObjectSecurity
$sd.AddAccessRule($ace1) | Out-Null
$sd.AddAccessRule($ace2) | Out-Null
$template.ObjectSecurity = $sd
$template.CommitChanges()

# ---- 啟用 AutoEnrollment GPO ----
Import-Module GroupPolicy

if (-not (Get-GPO -Name $GpoName -ErrorAction SilentlyContinue)) {
  New-GPO -Name $GpoName | Out-Null
}
New-GPLink -Name $GpoName -Target ("DC=" + $DomainFqdn.Replace(".",",DC="))

Set-GPRegistryValue -Name $GpoName `
  -Key "HKLM\Software\Policies\Microsoft\Cryptography\AutoEnrollment" `
  -ValueName "AEPolicy" -Type DWord -Value 7

gpupdate /force

Write-Host "`n✅ AD CS 企業根 CA 已成功部署！"
