# 1) 參數（可依需要調整 NetBIOS 名稱；不填時會自動推導）
$DomainName       = "tcivs.com.tw"
$DomainNetBIOS    = "TCIVS"              # 可省略，讓系統自判
$SafeModePassword = Read-Host "輸入 DSRM 安全模式密碼" -AsSecureString

# 2) 安裝 AD DS 角色與管理工具
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# 3) 新建樹系與網域（同時安裝整合 DNS）
#    備註：未指定 -NoRebootOnCompletion 時，安裝完成後會自動重新開機
Install-ADDSForest `
  -DomainName $DomainName `
  -DomainNetbiosName $DomainNetBIOS `
  -InstallDNS `
  -SafeModeAdministratorPassword $SafeModePassword `
  -Force
