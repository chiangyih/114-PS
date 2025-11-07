#安裝 AD CS 角色並建立「企業根 CA」

# ===== 變數 =====
$DomainFqdn     = "tcivs.com.tw"
$CaCommonName   = "TCIVS-ROOT-CA"       # 企業根 CA 顯示名稱
$KeyLength      = 2048
$HashAlgorithm  = "SHA256"
$ValidityYears  = 10                     # 根憑證有效年限（示例 10 年）
$RootCerPath    = "C:\PKI\TCIVS-ROOT-CA.cer"   # 匯出根憑證供發佈/備份
$CRLPath_Local  = "C:\PKI\CRL"                 # CRL 輸出目錄（本機檔案）
$GpoName        = "TCIVS-Cert-AutoEnrollment"  # 啟用電腦端自動註冊之 GPO 名稱
$WebTemplate    = "WebServer"                  # 內建網站伺服器範本（預設存在）


# 建立必要目錄
New-Item -ItemType Directory -Path (Split-Path $RootCerPath) -Force | Out-Null
New-Item -ItemType Directory -Path $CRLPath_Local -Force | Out-Null

# 安裝 AD CS 角色（含管理工具）
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools

# 設定 DSRM 密碼
$DSRM = Read-Host "請輸入 DSRM 安全模式密碼" -AsSecureString

# 建立「企業根 CA」，同時建立金鑰與 CA 資料庫
Install-AdcsCertificationAuthority `
  -CAType EnterpriseRootCA `
  -CACommonName $CaCommonName `
  -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
  -KeyLength $KeyLength `
  -HashAlgorithm $HashAlgorithm `
  -ValidityPeriod Years `
  -ValidityPeriodUnits $ValidityYears `
  -Force

# 啟動 AD CS 服務
Start-Service CertSvc
