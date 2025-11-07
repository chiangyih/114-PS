# PowerShell 腳本對照表

快速查詢腳本編號與 PLAN.md 需求的對照關係

---

## PLAN.md 需求 → 腳本對照

| PLAN.md 需求 | 腳本編號 | 腳本檔名 | 狀態 |
|-------------|---------|----------|------|
| **0. 系統初始化** |
| 重新命名電腦 | 00 | `00-renameComputer.ps1` | ✅ |
| 設定固定 IP | 01 | `01-setStaticIP.ps1` | ✅ |
| **1. 建立 AD DS** |
| 安裝 AD DS 角色 | 02 | `02-installADDS.ps1` | ✅ |
| 建立網域 tcivs.com.tw | 02 | `02-installADDS.ps1` | ✅ |
| 驗證 AD DS | 03 | `03-verifyAD.ps1` | ✅ |
| **2. 建立與刪除使用者** |
| AddUser.ps1 (Sales01-100) | 07 | `07-createUsers.ps1` | ✅ |
| RemoveUser.ps1 (刪除奇偶數) | 08 | `08-removeUsers.ps1` | ✅ |
| **3. 安裝 AD CS** |
| 安裝 AD CS 角色 | 05 | `05-installADCS.ps1` | ✅ |
| 設定企業根 CA | 05 | `05-installADCS.ps1` | ✅ |
| 發佈憑證至 AD | 05 | `05-installADCS.ps1` | ✅ |
| 驗證 CA | 06 | `06-verifyCA.ps1` | ✅ |
| **4. 安裝 DNS** |
| Forward Lookup Zone | 04 | `04-createDNS.ps1` | ✅ |
| Reverse Lookup Zone | 04 | `04-createDNS.ps1` | ✅ |
| 新增 A 記錄 | 04 | `04-createDNS.ps1` | ✅ |
| 新增 PTR 記錄 | 04 | `04-createDNS.ps1` | ✅ |
| **5. 安裝 IIS** |
| 安裝 IIS 角色 | 11 | `11-installIIS.ps1` | ✅ |
| 建立網站目錄 | 12 | `12-configureIISHTTPS.ps1` | ✅ |
| 建立 IIS 站台 | 12 | `12-configureIISHTTPS.ps1` | ✅ |
| 建立 HTTPS 綁定 | 12 | `12-configureIISHTTPS.ps1` | ✅ |
| **6. 設定 NTP** |
| 設定授時伺服器 | 10 | `10-configureNTP.ps1` | ✅ |
| 同步網域時間 | 10 | `10-configureNTP.ps1` | ✅ |
| **7. 設定 DHCP** |
| 安裝 DHCP 角色 | 09 | `09-installDHCP.ps1` | ✅ |
| 新增 DHCP 範圍 | 09 | `09-installDHCP.ps1` | ✅ |
| 設定 DHCP 選項 | 09 | `09-installDHCP.ps1` | ✅ |
| HR-xx 固定保留 | 09 | `09-installDHCP.ps1` | ✅ |
| **8. 加入網域** |
| Windows 加入網域 | 13 | `13-joinDomain-Windows.ps1` | ✅ |
| Linux 加入網域 | 14 | `14-joinDomain-Linux.sh` | ✅ |
| **9. 系統安全** |
| Windows Defender | 15 | `15-configureSecurity.ps1` | ✅ |
| 防毒掃描 | 15 | `15-configureSecurity.ps1` | ✅ |
| Edge 設定 | 15 | `15-configureSecurity.ps1` | ✅ |

---

## 功能分類索引

### 🔧 系統設定
- `00-renameComputer.ps1` - 電腦重新命名
- `01-setStaticIP.ps1` - IP 位址設定
- `15-configureSecurity.ps1` - 安全性設定

### 🌐 網域服務
- `02-installADDS.ps1` - Active Directory 安裝
- `03-verifyAD.ps1` - Active Directory 驗證
- `04-createDNS.ps1` - DNS 服務設定

### 🔐 憑證服務
- `05-installADCS.ps1` - 憑證授權單位安裝
- `06-verifyCA.ps1` - 憑證授權單位驗證

### 👥 使用者管理
- `07-createUsers.ps1` - 批次建立使用者
- `08-removeUsers.ps1` - 批次刪除使用者

### 🌍 網路服務
- `09-installDHCP.ps1` - DHCP 服務
- `10-configureNTP.ps1` - 時間同步服務

### 🌐 網頁服務
- `11-installIIS.ps1` - IIS 安裝
- `12-configureIISHTTPS.ps1` - HTTPS 設定

### 🔗 網域整合
- `13-joinDomain-Windows.ps1` - Windows 加入網域
- `14-joinDomain-Linux.sh` - Linux 加入網域

---

## 執行時間估計

| 腳本 | 預估時間 | 說明 |
|------|---------|------|
| 00 | 1-2 分鐘 | 包含重啟時間 |
| 01 | < 1 分鐘 | |
| 02 | 10-15 分鐘 | 包含重啟時間 |
| 03 | < 1 分鐘 | |
| 04 | 1-2 分鐘 | |
| 05 | 5-10 分鐘 | |
| 06 | < 1 分鐘 | |
| 07 | 2-5 分鐘 | 建立 100 個使用者 |
| 08 | 1-2 分鐘 | 刪除 50 個使用者 |
| 09 | 2-3 分鐘 | |
| 10 | 1-2 分鐘 | |
| 11 | 2-3 分鐘 | |
| 12 | 3-5 分鐘 | 包含憑證申請 |
| 13 | 2-3 分鐘 | 包含重啟時間 |
| 14 | 5-10 分鐘 | 包含套件安裝 |
| 15 | 3-5 分鐘 | 若執行掃描會更久 |

**總計**：約 40-70 分鐘（包含所有重啟時間）

---

## 快速指令參考

```powershell
# 查看所有腳本
Get-ChildItem *.ps1 | Sort-Object Name

# 依序執行所有必要腳本（Branch-XX）
$scripts = @(
    "00-renameComputer.ps1",
    "01-setStaticIP.ps1",
    "02-installADDS.ps1",
    "03-verifyAD.ps1",
    "04-createDNS.ps1",
    "05-installADCS.ps1",
    "06-verifyCA.ps1",
    "09-installDHCP.ps1",
    "10-configureNTP.ps1",
    "11-installIIS.ps1",
    "12-configureIISHTTPS.ps1",
    "15-configureSecurity.ps1"
)

# 使用者管理（選用）
# .\07-createUsers.ps1
# .\08-removeUsers.ps1
```

---

**最後更新**：2025-01-07
