# Windows Server 2022 腳本執行順序指南

本文件說明所有 PowerShell 腳本的執行順序與功能說明。

---

## 📋 完整腳本清單（按執行順序）

### 階段 1：系統初始化

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 00 | `00-renameComputer.ps1` | 重新命名電腦為 Branch-XX | ✅ | 第一步執行 |
| 01 | `01-setStaticIP.ps1` | 設定固定 IP 位址 | ❌ | 設定後建議驗證網路連線 |

### 階段 2：Active Directory 網域服務

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 02 | `02-installADDS.ps1` | 安裝 AD DS 並建立網域樹系 | ✅ | 安裝後自動重啟 |
| 03 | `03-verifyAD.ps1` | 驗證 AD 和 DNS 服務狀態 | ❌ | 用於確認 AD 安裝成功 |

### 階段 3：DNS 服務

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 04 | `04-createDNS.ps1` | 建立 DNS 正反向查詢區及主機記錄 | ❌ | 支援互動式輸入主機名稱 |

### 階段 4：憑證服務

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 05 | `05-installADCS.ps1` | 安裝企業根 CA 並設定憑證範本 | ❌ | 包含完整的 CA 設定 |
| 06 | `06-verifyCA.ps1` | 驗證 CA 服務狀態 | ❌ | 用於確認 CA 安裝成功 |

### 階段 5：使用者管理

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 07 | `07-createUsers.ps1` | 建立 Sales01-100 使用者 | ❌ | 自動建立 SalesGroup 群組 |
| 08 | `08-removeUsers.ps1` | 刪除奇數或偶數編號使用者 | ❌ | 可選擇刪除 50 個帳號 |

### 階段 6：網路服務

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 09 | `09-installDHCP.ps1` | 安裝 DHCP 並設定 IP 範圍 | ❌ | 包含 HR-XX 保留設定 |
| 10 | `10-configureNTP.ps1` | 設定 NTP 授時伺服器 | ❌ | 可選外部 NTP 來源 |

### 階段 7：網頁服務

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 11 | `11-installIIS.ps1` | 安裝 IIS 網頁伺服器及功能 | ❌ | 僅安裝角色，不建立網站 |
| 12 | `12-configureIISHTTPS.ps1` | 建立網站並設定 HTTPS | ❌ | 需先完成 CA 設定 |

### 階段 8：加入網域

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 13 | `13-joinDomain-Windows.ps1` | Windows 電腦加入網域 | ✅ | 用於 HR-XX 電腦 |
| 14 | `14-joinDomain-Linux.sh` | Linux 電腦加入網域 | ❌ | 用於 Business-XX (Fedora) |

### 階段 9：安全性設定

| 編號 | 檔案名稱 | 功能說明 | 需重啟 | 備註 |
|------|----------|----------|--------|------|
| 15 | `15-configureSecurity.ps1` | 設定 Defender、Edge、防火牆 | ❌ | 最後執行 |

---

## 🔄 建議執行流程

### Branch-XX（網域控制站）執行順序：

```powershell
# 1. 系統初始化
.\00-renameComputer.ps1          # 重新命名 → 重啟
.\01-setStaticIP.ps1             # 設定 IP

# 2. 建立網域
.\02-installADDS.ps1             # 安裝 AD DS → 重啟
.\03-verifyAD.ps1                # 驗證 AD

# 3. 建立 DNS
.\04-createDNS.ps1               # 建立 DNS 區域

# 4. 安裝憑證服務
.\05-installADCS.ps1             # 安裝 CA
.\06-verifyCA.ps1                # 驗證 CA

# 5. 建立使用者（依需求）
.\07-createUsers.ps1             # 建立 Sales 使用者
.\08-removeUsers.ps1             # 刪除部分使用者（選用）

# 6. 網路服務
.\09-installDHCP.ps1             # 安裝 DHCP
.\10-configureNTP.ps1            # 設定 NTP

# 7. 網頁服務
.\11-installIIS.ps1              # 安裝 IIS
.\12-configureIISHTTPS.ps1       # 設定 HTTPS

# 8. 安全性
.\15-configureSecurity.ps1       # 安全性設定
```

### HR-XX（Windows 客戶端）執行順序：

```powershell
# 在 HR-XX 電腦上執行
.\13-joinDomain-Windows.ps1      # 加入網域 → 重啟
```

### Business-XX（Linux 客戶端）執行順序：

```bash
# 在 Business-XX (Fedora) 上執行
sudo chmod +x 14-joinDomain-Linux.sh
sudo ./14-joinDomain-Linux.sh    # 加入網域
```

---

## ⚠️ 重要注意事項

1. **執行順序很重要**：某些腳本依賴前面步驟的完成
2. **需要重啟的腳本**：執行後系統會自動重啟
3. **互動式輸入**：大部分腳本支援使用者輸入，也可透過參數指定
4. **錯誤處理**：每個腳本都有詳細的錯誤訊息和驗證步驟
5. **網路連線**：某些步驟需要網路連線（如更新病毒定義）

---

## 📝 參數使用範例

### 使用預設值（互動式）：
```powershell
.\04-createDNS.ps1
```

### 使用命令列參數：
```powershell
.\04-createDNS.ps1 -XX "15" -BranchName "Branch-15"
```

---

## 🔍 驗證命令

每個腳本執行完成後都會顯示相關的驗證命令，例如：

```powershell
# 驗證 AD
Get-ADDomain

# 驗證 DNS
Get-DnsServerZone

# 驗證 CA
Get-Service CertSvc

# 驗證使用者
Get-ADUser -Filter 'Name -like "Sales*"'

# 驗證 DHCP
Get-DhcpServerv4Scope

# 驗證 IIS
Get-Website
```

---

## 📚 相關文件

- `PLAN.md` - 完整計畫說明
- `README.md` - 專案說明

---

**更新日期**：2025-01-07  
**版本**：1.0
