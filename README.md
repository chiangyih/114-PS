# Windows Server 2022 AD 環境部署腳本集

本專案包含一系列 PowerShell 腳本，用於自動化部署和設定 Windows Server 2022 的 Active Directory 環境，包括 AD DS、DNS、AD CS 及 IIS 等服務。

## 📋 腳本清單

### 01-creatAD.ps1
**功能：建立 Active Directory 網域服務（AD DS）**

安裝並設定第一個網域控制站，建立新的 Active Directory 樹系。

**主要步驟：**
- 安裝 AD-Domain-Services 角色與管理工具
- 建立新的 AD 樹系與網域（tcivs.com.tw）
- 自動安裝並整合 DNS 服務
- 設定 DSRM（目錄服務還原模式）安全模式密碼

**執行後：** 系統會自動重新啟動以完成設定

---

### 02-verifyAD-DNS_status.ps1
**功能：驗證 AD 與 DNS 服務狀態**

檢查 Active Directory 和 DNS 服務是否正確安裝並正常運作。

**驗證項目：**
- 網域物件資訊（DNS 根網域、NetBIOS 名稱、基礎結構主機、網域功能等級）
- 網域控制站服務可用性測試
- DNS 區域建立狀態（正向查詢區）
- AD DS 和 DNS 服務執行狀態

---

### 03-installADDSForest.ps1
**功能：安裝 AD DS 樹系並整合 DNS**

與 01 腳本功能類似，提供另一個安裝 AD DS 樹系的版本。

**主要設定：**
- 網域名稱：tcivs.com.tw
- NetBIOS 名稱：TCIVS
- 整合安裝 DNS 伺服器
- 設定 DSRM 密碼

---

### 04-installADCS-rootCA.ps1
**功能：部署企業根憑證授權單位（Enterprise Root CA）**

安裝並設定 AD CS 角色，建立企業根 CA，提供憑證管理服務。

**主要功能：**
- 安裝 ADCS-Cert-Authority 角色及管理工具
- 建立企業根 CA（TCIVS-ROOT-CA）
- 設定 CA 參數：
  - 金鑰長度：2048 位元
  - 雜湊演算法：SHA256
  - 有效期限：10 年
- 匯出根憑證並發佈到 Active Directory
- 建立 PKI 目錄結構（C:\PKI）
- 設定 CRL（憑證撤銷清單）發佈路徑
- 設定群組原則以啟用自動憑證註冊

**輸出檔案：**
- 根憑證：C:\PKI\TCIVS-ROOT-CA.cer
- CRL 目錄：C:\PKI\CRL

---

### 05-verrify-CA.ps1
**功能：驗證憑證授權單位設定**

檢查 AD CS 安裝後的各項設定是否正確。

**驗證項目：**
- 憑證服務（CertSvc）執行狀態
- CA 詳細資訊
- Active Directory 中已發佈的根憑證狀態
- NTAuth 憑證存放區狀態
- CA 已啟用的憑證範本清單
- 客戶端是否已信任根 CA

---

### 06-install-IIS.ps1
**功能：安裝 IIS 網頁伺服器**

安裝完整的 IIS（Internet Information Services）及相關功能模組。

**安裝的功能模組：**
- Web-Server（核心網頁伺服器）
- Web-Common-Http（一般 HTTP 功能）
- Web-Default-Doc（預設文件）
- Web-Static-Content（靜態內容）
- Web-Http-Errors（HTTP 錯誤頁面）
- Web-Http-Logging（HTTP 記錄）
- Web-Request-Monitor（要求監視器）
- Web-Http-Redirect（HTTP 重新導向）
- Web-Health（健全狀況與診斷）
- Web-Performance（效能功能）
- Web-Stat-Compression（靜態內容壓縮）
- Web-Security（安全性）
- Web-Filtering（要求篩選）
- Web-Windows-Auth（Windows 驗證）
- Web-Mgmt-Tools（IIS 管理工具）

---

### 07-DNS_ForwRever.ps1
**功能：一鍵部署 DNS 正反向查詢區及主機記錄**

自動化設定 DNS 正向和反向查詢區，並新增所需的主機記錄和 PTR 記錄。

**主要功能：**
- 安裝 DNS Server 角色
- 建立正向查詢區（Forward Lookup Zone）：tcivs.com.tw
- 建立反向查詢區（Reverse Lookup Zone）：172.16.xx.0/24
- 自動新增主機記錄：
  - Branch-xx (172.16.xx.254)
  - Business-xx (172.16.xx.100)
  - HR-xx (172.16.xx.200)
  - Customer-xx (172.16.xx.50)
  - www（指向 Branch-xx）
  - linux（指向 Business-xx）
- 自動新增對應的 PTR（反向解析）記錄

**參數：**
- `DomainFqdn`：網域名稱（預設：tcivs.com.tw）
- `SitePrefix`：IP 前綴（預設：172.16）
- `XX`：崗位編號（預設：01）
- `BranchName`、`BusinessName`、`HRName`、`CustomerName`：各主機名稱

---

## 🚀 使用順序建議

1. **01-creatAD.ps1** 或 **03-installADDSForest.ps1** - 建立 AD 網域和 DNS
2. **02-verifyAD-DNS_status.ps1** - 驗證 AD 和 DNS 安裝成功
3. **04-installADCS-rootCA.ps1** - 安裝企業根 CA
4. **05-verrify-CA.ps1** - 驗證 CA 設定
5. **06-install-IIS.ps1** - 安裝 IIS 網頁伺服器
6. **07-DNS_ForwRever.ps1** - 設定完整的 DNS 正反向查詢

## ⚠️ 注意事項

- 執行腳本前請確認具有系統管理員權限
- 部分腳本會要求輸入 DSRM 密碼，請妥善記錄
- 安裝 AD DS 後系統會自動重新啟動
- 建議在測試環境中先執行並驗證
- 網域名稱預設為 tcivs.com.tw，可依需求修改腳本中的變數

## 📝 環境需求

- 作業系統：Windows Server 2022
- 網路環境：已設定靜態 IP 位址
- 權限：系統管理員（Administrator）
- 記憶體：建議 4GB 以上
- 硬碟空間：建議 60GB 以上

## 📌 參考資訊

- 網域名稱：tcivs.com.tw
- NetBIOS 名稱：TCIVS
- CA 名稱：TCIVS-ROOT-CA
- IP 範圍：172.16.xx.0/24（xx 為崗位編號）

---

**最後更新：2025年11月7日**

