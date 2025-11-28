# ===============================
#  Windows Server 2022 - 設定 NTP 時間來源
#  目的：Branch-xx 作為網域時間來源，預設指向 time.tcivs.com.tw（可自訂）
# ===============================

[CmdletBinding()]
param(
    [string]$NtpServers = "time.tcivs.com.tw"
)

function Write-Result {
    param([bool]$Ok,[string]$Message)
    if ($Ok) { Write-Host "[通過] $Message" -ForegroundColor Green }
    else { Write-Host "[失敗] $Message" -ForegroundColor Red }
}
function Write-Warn($msg){ Write-Host "[警告] $msg" -ForegroundColor Yellow }

# ===== 權限與角色檢查 =====
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Result $false "請以系統管理員身分執行此腳本。"
    exit 1
}

# 確認是否為 PDC Emulator（建議在 PDC 上設定時間來源）
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $pdc = Get-ADDomainController -Discover -Service PrimaryDC -ErrorAction Stop
    if ($pdc.HostName -ne $env:COMPUTERNAME) {
        Write-Warn "建議在 PDC Emulator ($($pdc.HostName)) 上設定外部 NTP。此機器為 $($env:COMPUTERNAME)。"
    }
} catch {
    Write-Warn "無法確認 PDC Emulator：$($_.Exception.Message)；若為單一 DC 可忽略。"
}

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  設定 NTP 時間來源" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan
Write-Host "外部時間來源：$NtpServers" -ForegroundColor White

$confirm = Read-Host "確認套用設定並重新啟動 W32Time？ (Y/N)"
if ($confirm -notin @('Y','y')) { Write-Host "[取消] 未變更。" -ForegroundColor Red; exit 0 }

# ===== 設定為可靠時間來源並指向外部 NTP =====
try {
    w32tm /config /manualpeerlist:$NtpServers /syncfromflags:manual /reliable:YES /update
    Write-Result $true "已設定 NTP 來源並標記為可靠時間來源"
} catch {
    Write-Result $false "設定 NTP 來源失敗：$($_.Exception.Message)"
    exit 1
}

# ===== 設定服務自動並重新啟動 =====
try {
    Set-Service W32Time -StartupType Automatic
    Restart-Service W32Time
    Write-Result $true "Windows Time 服務已重新啟動"
} catch {
    Write-Result $false "重啟 W32Time 服務失敗：$($_.Exception.Message)"
}

# ===== 立即同步 =====
try {
    w32tm /resync /rediscover
    Write-Result $true "已觸發立即同步"
} catch {
    Write-Warn "同步命令回傳錯誤（可能需稍後重試）：$($_.Exception.Message)"
}

Write-Host "`n可用以下指令檢查狀態：" -ForegroundColor Cyan
Write-Host "  w32tm /query /status"
Write-Host "  w32tm /query /configuration"
Write-Host "  w32tm /query /peers"
Write-Host ""
Write-Host "[完成] NTP 設定已套用。" -ForegroundColor Green
