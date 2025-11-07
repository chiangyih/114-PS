# Windows Server 2022 系統建置與服務部署腳本集

本專案包含一系列 PowerShell 腳本，用於自動化部署和設定 Windows Server 2022 的完整企業環境，包括 Active Directory、DNS、憑證服務、DHCP、NTP、IIS 等服務。所有腳本都包含詳細的正體中文註解，並支援互動式輸入。

## 📊 專案狀態

- **腳本總數**：16 個（15 個 PowerShell + 1 個 Shell）
- **PLAN.md 需求覆蓋率**：100% ✅
- **文件完整度**：100% ✅
- **註解語言**：正體中文
- **最後更新**：2025年11月7日

---

## 🎯 快速導覽

| 文件 | 說明 |
|------|------|
| [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) | 📖 完整執行順序指南（推薦閱讀） |
| [SCRIPT_MAPPING.md](SCRIPT_MAPPING.md) | 🗺️ 腳本對照表與功能索引 |
| [COMPLETION_REPORT.md](COMPLETION_REPORT.md) | 📋 專案完成報告 |
| [PLAN.md](PLAN.md) | 📝 原始需求文件 |

---

## 📋 完整腳本清單（按執行順序）

### 階段 1：系統初始化

#### 00-renameComputer.ps1
**功能：重新命名電腦為 Branch-XX**

- 互動式輸入電腦名稱
- 自動重新啟動系統
- 包含確認提示避免誤操作

**執行後**：系統會自動重啟

---

#### 01-setStaticIP.ps1
**功能：設定固定 IP 位址**

- 提示輸入崗位編號（例如：01）
- 自動計算 IP：172.16.XX.254
- 設定子網路遮罩：255.255.255.0
- 設定預設閘道：172.16.XX.1
- 設定 DNS 伺服器：127.0.0.1（本機）

**網路設定**：
- 自動偵測並使用第一個啟用的網路介面卡
- 移除現有 DHCP 設定
- 驗證設定結果

---

### 階段 2：Active Directory 網域服務

#### 02-installADDS.ps1
**功能：安裝 AD DS 並建立網域樹系**

- 安裝 AD-Domain-Services 角色與管理工具
- 建立新的 AD 樹系與網域（tcivs.com.tw）
- 自動安裝並整合 DNS 服務
- 設定 DSRM（目錄服務還原模式）密碼

**主要設定**：
- 網域名稱：tcivs.com.tw
- NetBIOS 名稱：TCIVS
- 整合 DNS 服務

**執行後**：系統會自動重啟

---

#### 03-verifyAD.ps1
**功能：驗證 AD 與 DNS 服務狀態**

**驗證項目**：
- 網域物件資訊（DNS 根網域、NetBIOS 名稱、基礎結構主機、網域功能等級）
- 網域控制站服務可用性測試
- DNS 區域建立狀態
- AD DS 和 DNS 服務執行狀態

---

### 階段 3：DNS 服務

#### 04-createDNS.ps1
**功能：建立 DNS 正反向查詢區及主機記錄**

**主要功能**：
- 建立 AD 整合的正向查詢區（tcivs.com.tw）
- 建立反向查詢區（172.16.xx.0/24）
- 自動新增主機記錄（A Records）：
  - Branch-xx (172.16.xx.254) + PTR
  - Business-xx (172.16.xx.100) + PTR
  - HR-xx (172.16.xx.200) + PTR
  - Customer-xx (172.16.xx.50) - 僅 A 記錄
  - www（指向 Branch-xx）+ PTR
  - linux（指向 Business-xx）+ PTR

**支援功能**：
- 互動式輸入主機名稱
- 自動建立對應 PTR 記錄
- 完整的驗證輸出

**使用範例**：
```powershell
.\04-createDNS.ps1                    # 互動式輸入
.\04-createDNS.ps1 -XX "15"           # 指定崗位
```

---

### 階段 4：憑證服務

#### 05-installADCS.ps1
**功能：安裝企業根 CA 並設定憑證範本**

**完整功能**：
- 安裝 ADCS-Cert-Authority 角色
- 建立企業根 CA（TCIVS-ROOT-CA）
- 設定 CA 參數：
  - 金鑰長度：2048 位元
  - 雜湊演算法：SHA256
  - 有效期限：10 年
- 匯出根憑證並發佈到 Active Directory
- 設定 CRL 和 AIA 發佈路徑
- 啟用 WebServer 憑證範本
- 設定網域電腦自動註冊權限
- 建立並連結群組原則（自動憑證註冊）

**輸出檔案**：
- C:\PKI\TCIVS-ROOT-CA.cer
- C:\PKI\CRL\

---

#### 06-verifyCA.ps1
**功能：驗證憑證授權單位設定**

**驗證項目**：
- 憑證服務執行狀態
- CA 詳細資訊
- AD 中已發佈的根憑證
- NTAuth 憑證存放區
- CA 已啟用的憑證範本
- 客戶端信任狀態

---

### 階段 5：使用者管理

#### 07-createUsers.ps1
**功能：建立 Sales01-100 使用者帳號**

**功能特點**：
- 自動建立 SalesGroup 群組
- 批次建立 100 個使用者（Sales01-Sales100）
- 統一密碼：Sales2024@
- 自動加入 SalesGroup 群組
- 顯示建立進度和結果摘要

**使用者設定**：
- 密碼永不過期
- 帳號已啟用
- 登入時不需變更密碼

---

#### 08-removeUsers.ps1
**功能：刪除奇數或偶數編號使用者**

**功能特點**：
- 互動式選擇刪除奇數或偶數編號
- 刪除 50 個使用者帳號
- 顯示即將刪除的範例
- 需要確認才執行
- 顯示刪除結果摘要

**選項**：
- 選項 1：刪除奇數編號（01, 03, 05, ..., 99）
- 選項 2：刪除偶數編號（02, 04, 06, ..., 100）

---

### 階段 6：網路服務

#### 09-installDHCP.ps1
**功能：安裝與設定 DHCP 伺服器**

**完整功能**：
- 安裝 DHCP 伺服器角色
- 在 AD 中授權 DHCP 伺服器
- 建立 DHCP 範圍（172.16.xx.150-200）
- 設定 DHCP 選項：
  - 選項 3：路由器（預設閘道）
  - 選項 6：DNS 伺服器
  - 選項 15：DNS 網域名稱
- 新增 HR-xx 的固定 IP 保留

**設定參數**：
- 租約期限：8 天
- 支援輸入 HR-xx 的 MAC 位址

---

#### 10-configureNTP.ps1
**功能：設定 NTP 授時伺服器**

**功能特點**：
- 將伺服器設為可靠的時間來源
- 可選擇設定外部 NTP 伺服器（台灣標準時間）
- 設定 Windows Time 服務自動啟動
- 強制同步時間
- 網域成員自動同步

**外部 NTP 來源**：
- time.stdtime.gov.tw
- tock.stdtime.gov.tw
- watch.stdtime.gov.tw

---

### 階段 7：網頁服務

#### 11-installIIS.ps1
**功能：安裝 IIS 網頁伺服器**

**安裝模組**：
- 核心網頁伺服器
- HTTP 功能模組
- 靜態內容
- 日誌記錄
- 效能與壓縮
- 安全性與篩選
- Windows 驗證
- 管理工具

---

#### 12-configureIISHTTPS.ps1
**功能：建立網站並設定 HTTPS**

**完整流程**：
- 建立網站根目錄（C:\web\www）
- 自動產生美觀的 HTML 首頁
- 建立 IIS 網站（www.tcivs.com.tw）
- 設定 HTTP 綁定（Port 80）
- 向 CA 申請 WebServer 憑證
- 設定 HTTPS 綁定（Port 443）
- 綁定 SSL 憑證

**網站資訊**：
- 網站名稱：www.tcivs.com.tw
- HTTP：http://www.tcivs.com.tw
- HTTPS：https://www.tcivs.com.tw

---

### 階段 8：加入網域

#### 13-joinDomain-Windows.ps1
**功能：Windows 電腦加入網域**

**適用於**：HR-xx 等 Windows 客戶端

**功能**：
- 互動式輸入電腦名稱
- 重新命名電腦（如需要）
- 加入 tcivs.com.tw 網域
- 提示輸入網域管理員認證
- 自動重新啟動

**執行後**：系統會自動重啟

---

#### 14-joinDomain-Linux.sh
**功能：Linux (Fedora) 電腦加入網域**

**適用於**：Business-xx 等 Linux 客戶端

**功能**：
- 自動安裝必要套件（realmd、sssd、adcli 等）
- 設定 DNS 指向網域控制站
- 測試網域連線
- 加入 Active Directory 網域
- 設定 SSSD 和自動建立家目錄
- 允許網域使用者登入

**使用方式**：
```bash
sudo chmod +x 14-joinDomain-Linux.sh
sudo ./14-joinDomain-Linux.sh
```

---

### 階段 9：安全性設定

#### 15-configureSecurity.ps1
**功能：系統安全性與設定**

**包含功能**：

1. **Windows Defender 設定**
   - 檢查防毒狀態
   - 啟用即時保護
   - 更新病毒定義
   - 執行快速掃描（可選）

2. **Microsoft Edge 設定**
   - 設定首頁為 https://www.tcivs.com.tw
   - 啟用 SmartScreen 篩選
   - 啟用安全 DNS
   - 設定安全性選項

3. **Windows 更新**
   - 檢查更新服務狀態
   - 啟動更新服務

4. **防火牆檢查**
   - 檢查所有設定檔狀態
   - 顯示啟用情況

---

## � 建議執行順序

### Branch-XX（主伺服器）完整流程：

```powershell
# 階段 1：系統初始化（約 5 分鐘）
.\00-renameComputer.ps1          # → 重啟
.\01-setStaticIP.ps1

# 階段 2：AD DS（約 15 分鐘）
.\02-installADDS.ps1             # → 重啟
.\03-verifyAD.ps1

# 階段 3：DNS（約 2 分鐘）
.\04-createDNS.ps1

# 階段 4：憑證服務（約 10 分鐘）
.\05-installADCS.ps1
.\06-verifyCA.ps1

# 階段 5：網路服務（約 5 分鐘）
.\09-installDHCP.ps1
.\10-configureNTP.ps1

# 階段 6：網頁服務（約 8 分鐘）
.\11-installIIS.ps1
.\12-configureIISHTTPS.ps1

# 階段 7：安全性（約 5 分鐘）
.\15-configureSecurity.ps1

# 選用：使用者管理（約 7 分鐘）
.\07-createUsers.ps1
.\08-removeUsers.ps1
```

**總計時間**：約 50-70 分鐘

### HR-XX（Windows 客戶端）：

```powershell
.\13-joinDomain-Windows.ps1      # 加入網域 → 重啟
```

### Business-XX（Linux 客戶端）：

```bash
sudo ./14-joinDomain-Linux.sh    # 加入網域

```bash
sudo ./14-joinDomain-Linux.sh    # 加入網域
```

---

```

---

## ✨ 腳本特色

### 所有腳本都包含：

1. ✅ **詳細的正體中文註解** - 每行程式碼都有說明
2. ✅ **錯誤處理** - 完善的 try-catch 和錯誤訊息
3. ✅ **互動式輸入** - 支援使用者輸入參數
4. ✅ **命令列參數** - 也支援直接傳參數執行
5. ✅ **執行進度顯示** - 彩色輸出和進度訊息
6. ✅ **驗證命令** - 每個腳本都提供驗證方式
7. ✅ **使用說明** - 清楚的使用範例

### 使用者體驗：

- ✅ 清晰的視覺回饋（使用顏色區分狀態）
- ✅ 友善的錯誤訊息
- ✅ 確認提示（避免誤操作）
- ✅ 預設值提供（快速執行）
- ✅ 執行結果摘要

---

## 🔍 驗證檢查清單

執行完所有腳本後，可以使用以下命令驗證：

```powershell
# 1. AD DS
Get-ADDomain
Get-ADForest

# 2. DNS
Get-DnsServerZone
nslookup www.tcivs.com.tw

# 3. CA
Get-Service CertSvc
certutil -ca.info

# 4. 使用者
Get-ADUser -Filter 'Name -like "Sales*"' | Measure-Object

# 5. DHCP
Get-DhcpServerv4Scope
Get-DhcpServerv4Lease -ScopeId 172.16.1.0

# 6. NTP
w32tm /query /status

# 7. IIS
Get-Website
Get-WebBinding

# 8. 防火牆
Get-NetFirewallProfile

# 9. Defender
Get-MpComputerStatus
```

---

## 📌 PLAN.md 需求對照表

| PLAN.md 需求 | 腳本編號 | 狀態 |
|-------------|---------|------|
| 建立 AD DS | 02, 03 | ✅ |
| 使用者管理 (AddUser/RemoveUser) | 07, 08 | ✅ |
| 安裝 AD CS | 05, 06 | ✅ |
| 安裝 DNS | 04 | ✅ |
| 安裝 IIS | 11, 12 | ✅ |
| 設定 NTP | 10 | ✅ |
| 設定 DHCP | 09 | ✅ |
| 加入網域 | 13, 14 | ✅ |
| 安全設定 | 15 | ✅ |

**總覆蓋率：100%** ✅

---

## 📚 技術重點

### 實作的關鍵技術：

1. **Active Directory 整合**
   - 樹系與網域建立
   - 使用者與群組管理
   - 群組原則設定

2. **DNS 服務**
   - 正向與反向查詢區
   - A 記錄與 PTR 記錄
   - AD 整合 DNS

3. **憑證服務**
   - 企業根 CA
   - 憑證範本管理
   - 自動註冊設定

4. **網路服務**
   - DHCP 範圍與選項
   - IP 保留設定
   - NTP 時間同步

5. **IIS 與 HTTPS**
   - 網站建立與設定
   - SSL/TLS 憑證綁定
   - 憑證自動申請

6. **跨平台整合**
   - Windows 加入網域
   - Linux (Fedora) 加入網域
   - SSSD 設定

---

## ⚠️ 注意事項

1. ⚠️ **執行權限**：所有腳本需要管理員權限
2. ⚠️ **執行順序**：請按照編號順序執行
3. ⚠️ **網路需求**：某些功能需要網際網路連線
4. ⚠️ **重啟次數**：整個流程會重啟 2-3 次
5. ⚠️ **備份建議**：重要操作前建議建立 VM 快照
6. ⚠️ **密碼記錄**：請妥善記錄 DSRM 密碼

---

## 📝 環境需求

- **作業系統**：Windows Server 2022
- **網路環境**：已設定靜態 IP 位址（或執行 01-setStaticIP.ps1）
- **權限**：系統管理員（Administrator）
- **記憶體**：建議 4GB 以上
- **硬碟空間**：建議 60GB 以上
- **虛擬化**：建議使用 VM（方便快照和還原）

---

## 📌 重要參數參考

### 網域設定
- **網域名稱**：tcivs.com.tw
- **NetBIOS 名稱**：TCIVS
- **網域功能等級**：Windows Server 2022

### 憑證服務
- **CA 名稱**：TCIVS-ROOT-CA
- **金鑰長度**：2048 位元
- **雜湊演算法**：SHA256
- **有效期限**：10 年

### 網路設定
- **IP 範圍**：172.16.xx.0/24（xx 為崗位編號）
- **伺服器 IP**：172.16.xx.254
- **預設閘道**：172.16.xx.1
- **DHCP 範圍**：172.16.xx.150-200

### 主機記錄
- **Branch-xx**：172.16.xx.254
- **Business-xx**：172.16.xx.100
- **HR-xx**：172.16.xx.200
- **Customer-xx**：172.16.xx.50

---

## 🎓 學習資源

### 相關文件
- [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) - 詳細執行指南
- [SCRIPT_MAPPING.md](SCRIPT_MAPPING.md) - 腳本功能對照
- [COMPLETION_REPORT.md](COMPLETION_REPORT.md) - 專案報告
- [PLAN.md](PLAN.md) - 需求規格

### PowerShell 技巧
- 所有腳本都可使用 `Get-Help` 查看說明
- 支援 `-WhatIf` 和 `-Verbose` 參數
- 錯誤處理使用 `Try-Catch-Finally`
- 參數驗證使用 `[ValidatePattern]` 等屬性

---

## 🔧 故障排除

### 常見問題

1. **無法執行腳本**
   ```powershell
   # 設定執行原則
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **AD DS 安裝失敗**
   - 檢查 DNS 設定是否正確
   - 確認網路介面卡已設定靜態 IP
   - 查看事件檢視器的錯誤訊息

3. **CA 憑證申請失敗**
   - 確認 AD CS 服務正在執行
   - 檢查 WebServer 範本是否已啟用
   - 驗證網域電腦是否有自動註冊權限

4. **DHCP 無法授權**
   - 確認伺服器已加入網域
   - 檢查是否有足夠的網域管理員權限
   - 查看 DHCP 服務日誌

5. **Linux 加入網域失敗**
   - 確認 DNS 指向網域控制站
   - 檢查防火牆規則
   - 驗證 Kerberos 設定

---

## 📞 支援與回饋

如有問題或建議，請：
1. 查看 [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) 詳細說明
2. 檢查腳本中的註解說明
3. 使用 PowerShell 的 `Get-Help` 命令
4. 查看 Windows 事件檢視器

---

## 📄 授權

本專案用於教育目的，配合 113 年工科技藝競賽使用。

---

**專案版本**：1.0  
**最後更新**：2025年11月7日  
**製作**：GitHub Copilot  
**狀態**：✅ 100% 完成

---

## 🎉 總結

本專案提供完整的 Windows Server 2022 企業環境自動化部署方案，涵蓋：

- ✅ 16 個功能完整的腳本
- ✅ 100% 符合 PLAN.md 需求
- ✅ 詳細的正體中文註解
- ✅ 友善的使用者介面
- ✅ 完整的文件說明
- ✅ 專業的錯誤處理

**立即開始**：請參閱 [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) 開始部署！

