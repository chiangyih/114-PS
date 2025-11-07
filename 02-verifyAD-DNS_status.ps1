# 驗證網域物件
Get-ADDomain | Format-List DNSRoot,NetBIOSName,InfrastructureMaster,DomainMode

# 驗證網域控制站服務可用
nltest /dsgetdc:tcivs.com.tw

# 驗證 DNS 區域是否建立（正向查詢區）
Get-DnsServerZone

# 顯示 AD DS、DNS 服務狀態
Get-Service -Name NTDS, DNS | Select-Object Status, Name, DisplayName
