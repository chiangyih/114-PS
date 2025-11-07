#!/bin/bash
# ===============================
#  Linux (Fedora) 加入 Active Directory 網域
#  用於 Business-xx 等 Linux 電腦加入 tcivs.com.tw 網域
# ===============================

echo "==============================================================================="
echo "  Linux 電腦加入 Active Directory 網域"
echo "==============================================================================="
echo ""

# 設定參數
DOMAIN="tcivs.com.tw"  # 網域名稱
DOMAIN_UPPER="TCIVS.COM.TW"  # 大寫網域名稱（Kerberos 使用）
REALM="TCIVS.COM.TW"  # Kerberos realm
WORKGROUP="TCIVS"  # 工作群組名稱（NetBIOS）

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 檢查是否以 root 執行
if [ "$EUID" -ne 0 ]; then  # 檢查是否為 root 使用者
    echo -e "${RED}✗ 請使用 root 權限執行此腳本${NC}"  # 顯示錯誤訊息
    echo "  執行方式：sudo $0"  # 提示正確執行方式
    exit 1  # 結束腳本
fi

echo -e "${CYAN}步驟 1：安裝必要套件...${NC}"  # 顯示進度
# 安裝加入網域所需的套件
dnf install -y realmd sssd oddjob oddjob-mkhomedir adcli samba-common-tools krb5-workstation  # 使用 dnf 安裝套件

if [ $? -ne 0 ]; then  # 檢查安裝是否成功
    echo -e "${RED}✗ 套件安裝失敗${NC}"  # 顯示錯誤訊息
    exit 1  # 結束腳本
fi
echo -e "${GREEN}✓ 套件安裝完成${NC}"  # 安裝完成

echo ""
echo -e "${CYAN}步驟 2：設定 DNS...${NC}"  # 顯示進度
# 提示輸入 DNS 伺服器 IP
read -p "請輸入網域控制站的 IP 位址（例如：172.16.1.254）: " DC_IP  # 讀取 DNS IP

if [ -z "$DC_IP" ]; then  # 檢查是否為空
    echo -e "${RED}✗ DNS IP 不能為空${NC}"  # 顯示錯誤訊息
    exit 1  # 結束腳本
fi

# 設定 DNS（使用 NetworkManager）
nmcli con mod $(nmcli -t -f NAME con show --active | head -1) ipv4.dns "$DC_IP"  # 修改活動連線的 DNS 設定
nmcli con down $(nmcli -t -f NAME con show --active | head -1)  # 停用連線
nmcli con up $(nmcli -t -f NAME con show --active | head -1)  # 啟用連線以套用設定

echo -e "${GREEN}✓ DNS 已設定為：$DC_IP${NC}"  # 設定完成

echo ""
echo -e "${CYAN}步驟 3：測試網域連線...${NC}"  # 顯示進度
# 測試網域是否可達
realm discover $DOMAIN  # 使用 realm 探索網域

if [ $? -ne 0 ]; then  # 檢查是否成功
    echo -e "${RED}✗ 無法連線到網域 $DOMAIN${NC}"  # 顯示錯誤訊息
    echo -e "${YELLOW}請檢查：${NC}"
    echo "  - DNS 設定是否正確"
    echo "  - 網路連線是否正常"
    echo "  - 網域控制站是否可連線"
    exit 1  # 結束腳本
fi
echo -e "${GREEN}✓ 網域連線測試成功${NC}"  # 測試成功

echo ""
echo -e "${CYAN}步驟 4：加入網域...${NC}"  # 顯示進度
echo -e "${YELLOW}請輸入網域管理員帳號（例如：administrator）${NC}"  # 提示輸入管理員帳號

# 使用 realm 加入網域
realm join --user=administrator $DOMAIN  # 執行加入網域命令，會提示輸入密碼

if [ $? -ne 0 ]; then  # 檢查是否成功
    echo -e "${RED}✗ 加入網域失敗${NC}"  # 顯示錯誤訊息
    exit 1  # 結束腳本
fi
echo -e "${GREEN}✓ 已成功加入網域：$DOMAIN${NC}"  # 加入完成

echo ""
echo -e "${CYAN}步驟 5：設定 SSSD...${NC}"  # 顯示進度
# 允許所有網域使用者登入
realm permit --all  # 允許所有網域使用者

# 設定使用者家目錄自動建立
authconfig --enablemkhomedir --update  # 啟用自動建立家目錄

# 重新啟動 SSSD 服務
systemctl restart sssd  # 重新啟動 SSSD 服務以套用設定
systemctl enable sssd  # 設定 SSSD 開機自動啟動

echo -e "${GREEN}✓ SSSD 設定完成${NC}"  # 設定完成

echo ""
echo -e "${CYAN}步驟 6：驗證設定...${NC}"  # 顯示進度
# 檢查網域加入狀態
realm list  # 列出已加入的網域資訊

echo ""
echo "==============================================================================="
echo -e "  ${GREEN}加入網域完成${NC}"
echo "==============================================================================="
echo ""
echo -e "${YELLOW}驗證命令：${NC}"
echo "  realm list                          # 查看網域資訊"
echo "  id administrator@$DOMAIN            # 查看網域使用者資訊"
echo "  getent passwd administrator@$DOMAIN # 取得使用者帳號資訊"
echo ""
echo -e "${YELLOW}使用網域帳號登入：${NC}"
echo "  ssh administrator@$DOMAIN@localhost"
echo "  或在圖形介面登入時輸入：administrator@$DOMAIN"
echo ""
