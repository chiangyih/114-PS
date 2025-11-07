# PLAN.md
Windows Server 2022 — 系統建置與服務部署計畫（僅描述 PowerShell 作業需求版）

---

# **0. 計畫說明**

本計畫依據競賽題目流程，重新統整 Windows Server 2022 應完成之各項服務建置要求。  

---

# **1. 建立 AD DS（Active Directory Domain Services）**

需執行或撰寫之 PowerShell 作業：

- 安裝 AD DS 功能的 PowerShell 命令  
- 建立新網域（tcivs.com.tw）所需的 PowerShell 命令  
- 安裝完成後的驗證命令（查詢網域、樹系資訊等）  

---

# **2. 建立與刪除使用者 — 作業計畫**

需執行或撰寫之 PowerShell 作業：

- 撰寫 **AddUser.ps1**腳本，其功能包括：
  - 建立(Sales01~Sales100)全部使用者帳號  
  - Group:SalesGroup，Password:Sales2024@，所有屬性需完全一致
  - 執行時需無互動、無錯誤並能完成新增   
- 檢查使用者屬性是否正確的查詢命令  
- 撰寫 **RemoveUser.ps1** 腳本，其功能包括：  
  - 自動刪除 Sales01 ~ Sales100 中由使用者決定的偶數或奇數編號 50 個帳號  
  - 必須可由評審於測試階段獨立執行  
  - 執行時需無互動、無錯誤並能完成刪除  

---

# **3. 安裝 AD CS（Active Directory Certificate Services）**

需執行或撰寫之 PowerShell 作業：

- 安裝 AD CS Certification Authority 所需命令  
- 設定企業根 CA（Enterprise Root CA）所需命令  
- 發佈憑證至 AD 的相關命令  
- 驗證是否已正確發佈並被網域內電腦信任的命令  

---

# **4. 安裝 DNS（Forward / Reverse Lookup）**

需執行或撰寫之 PowerShell 作業：

- 建立 Forward Lookup Zone 的 DNS 命令  
- 建立 Reverse Lookup Zone（172.16.xx.0/24）的 DNS 命令  
- 新增 A 記錄（Branch-xx、Business-xx、HR-xx、www、linux、Customer-xx）  
- 新增 PTR 記錄（Customer-xx 除外）  
- 驗證名稱解析結果的查詢命令  

---

# **5. 安裝 IIS（提供 https://www.tcivs.com.tw）**

需執行或撰寫之 PowerShell 作業：

- 安裝 IIS 所需命令  
- 建立網站目錄的命令  
- 建立 IIS 站台（www.tcivs.com.tw）的命令  
- 建立 HTTPS 綁定（需在 CA 發出憑證後）  
- 檢查 IIS 網站與憑證綁定狀態的命令  

---

# **6. 設定 NTP（Network Time Protocol）**

需執行或撰寫之 PowerShell 作業：

- 將 Branch-xx 設為授時伺服器的設定命令  
- 使網域內設備同步時間的命令  
- 驗證授時同步情況的命令  

---

# **7. 設定 DHCP（Dynamic Host Configuration Protocol）**

需執行或撰寫之 PowerShell 作業：

- 安裝 DHCP 角色所需的命令  
- 新增 DHCP 範圍（172.16.xx.150–200）的命令  
- 設定 DHCP 選項（Router、DNS、Domain Name）之命令  
- 新增固定保留（Reservation）給 HR-xx 的命令  
- 驗證 DHCP 租用狀態與作用情況的命令  

---

# **8. 加入網域（所有設備）**

需執行或撰寫之 PowerShell / Shell 作業：

- HR-xx 加入網域所需命令  
- Business-xx（Linux）加入網域的加入指令（Shell）  
- 驗證是否成功加入網域的查詢命令  

---

# **9. 系統安全、Edge 設定、掃描與檔案編號（摘要）**

需執行或撰寫之 PowerShell 作業：

- 啟用 Windows Defender 功能的命令  
- 執行防毒掃描的命令  
- 設定 Edge 安全性選項與預設頁面的命令  
- 題目要求的檔案編號設定相關命令  

---