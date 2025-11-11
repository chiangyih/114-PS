# ===============================
#  Windows Server 2022 - 設定 IIS HTTPS 綁定
#  為 www.tcivs.com.tw 網站設定 HTTPS
#  使用企業根 CA 核發的憑證
# ===============================

Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "  設定 IIS HTTPS 綁定" -ForegroundColor Cyan
Write-Host "===============================================================================`n" -ForegroundColor Cyan

# 匯入必要模組
Import-Module WebAdministration  # 匯入 IIS 管理模組

# 設定參數
$WebsiteName = "www.tcivs.com.tw"  # 網站名稱
$HostHeader = "www.tcivs.com.tw"  # 主機標頭
$WebRootPath = "C:\web\www"  # 網站根目錄路徑
$IndexFile = "index.html"  # 首頁檔案名稱

# 步驟 1：建立網站根目錄
Write-Host "步驟 1：建立網站根目錄..." -ForegroundColor Cyan  # 顯示進度
try {
    if (-not (Test-Path $WebRootPath)) {  # 檢查目錄是否存在
        New-Item -ItemType Directory -Path $WebRootPath -Force | Out-Null  # 建立目錄
        Write-Host "✓ 已建立目錄：$WebRootPath" -ForegroundColor Green  # 建立完成
    } else {
        Write-Host "✓ 目錄已存在：$WebRootPath" -ForegroundColor Green  # 目錄已存在
    }
    
    # 建立首頁檔案（如果不存在）
    $IndexPath = Join-Path $WebRootPath $IndexFile  # 組合首頁完整路徑
    if (-not (Test-Path $IndexPath)) {  # 檢查首頁是否存在
        $HtmlContent = @"
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TCIVS 企業網站</title>
    <style>
        body { font-family: 'Microsoft JhengHei', Arial, sans-serif; margin: 0; padding: 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .container { max-width: 800px; margin: 100px auto; padding: 40px; background: white; border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,0.3); text-align: center; }
        h1 { color: #333; margin-bottom: 20px; }
        p { color: #666; font-size: 18px; line-height: 1.6; }
        .info { background: #f0f0f0; padding: 20px; border-radius: 5px; margin-top: 20px; }
        .success { color: #28a745; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>✅ 歡迎來到 TCIVS 企業網站</h1>
        <p class="success">HTTPS 安全連線已成功建立！</p>
        <div class="info">
            <p><strong>網站名稱：</strong>www.tcivs.com.tw</p>
            <p><strong>憑證核發者：</strong>TCIVS-ROOT-CA</p>
            <p><strong>建置日期：</strong>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
        <p style="margin-top: 30px; color: #999; font-size: 14px;">
            Windows Server 2022 | IIS | Active Directory Certificate Services
        </p>
    </div>
</body>
</html>
"@
        $HtmlContent | Out-File -FilePath $IndexPath -Encoding UTF8  # 建立首頁檔案
        Write-Host "✓ 已建立首頁檔案：$IndexPath" -ForegroundColor Green  # 建立完成
    } else {
        Write-Host "✓ 首頁檔案已存在：$IndexPath" -ForegroundColor Green  # 檔案已存在
    }
} catch {
    Write-Host "✗ 建立網站目錄失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 步驟 2：檢查或建立 IIS 網站
Write-Host "`n步驟 2：檢查或建立 IIS 網站..." -ForegroundColor Cyan  # 顯示進度
try {
    $Website = Get-Website -Name $WebsiteName -ErrorAction SilentlyContinue  # 嘗試取得網站
    
    if ($null -eq $Website) {  # 若網站不存在
        # 停止預設網站以避免連接埠衝突
        Stop-Website -Name "Default Web Site" -ErrorAction SilentlyContinue  # 停止預設網站
        
        # 建立新網站
        New-Website -Name $WebsiteName -PhysicalPath $WebRootPath -Force | Out-Null  # 建立新網站
        Write-Host "✓ 已建立網站：$WebsiteName" -ForegroundColor Green  # 建立完成
    } else {
        Write-Host "✓ 網站已存在：$WebsiteName" -ForegroundColor Green  # 網站已存在
    }
} catch {
    Write-Host "✗ 建立網站失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    exit  # 結束腳本
}

# 步驟 3：設定 HTTP 綁定（Port 80）
Write-Host "`n步驟 3：設定 HTTP 綁定..." -ForegroundColor Cyan  # 顯示進度
try {
    # 移除現有的 HTTP 綁定
    Get-WebBinding -Name $WebsiteName -Protocol "http" | Remove-WebBinding -ErrorAction SilentlyContinue  # 移除現有綁定
    
    # 新增 HTTP 綁定
    New-WebBinding -Name $WebsiteName -Protocol "http" -Port 80 -HostHeader $HostHeader  # 新增 HTTP 綁定到 Port 80
    Write-Host "✓ 已設定 HTTP 綁定：$HostHeader :80" -ForegroundColor Green  # 設定完成
} catch {
    Write-Host "✗ 設定 HTTP 綁定失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 4：向 CA 申請網站伺服器憑證
Write-Host "`n步驟 4：向 CA 申請網站伺服器憑證..." -ForegroundColor Cyan  # 顯示進度
try {
    # 檢查是否已有憑證
    $ExistingCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { 
        $_.Subject -like "*CN=$HostHeader*" -and $_.NotAfter -gt (Get-Date)
    } | Select-Object -First 1  # 尋找符合主機名稱且未過期的憑證
    
    if ($null -ne $ExistingCert) {  # 若找到憑證
        Write-Host "✓ 找到現有憑證（指紋：$($ExistingCert.Thumbprint)）" -ForegroundColor Green  # 顯示憑證指紋
        $CertThumbprint = $ExistingCert.Thumbprint  # 使用現有憑證
    } else {  # 若沒有憑證
        Write-Host "⊙ 正在申請新憑證..." -ForegroundColor Yellow  # 顯示申請訊息
        
        # 建立憑證申請檔案
        $InfFile = "$env:TEMP\cert_request.inf"  # INF 檔案路徑
        $ReqFile = "$env:TEMP\cert_request.req"  # REQ 檔案路徑
        $CerFile = "$env:TEMP\cert_request.cer"  # CER 檔案路徑
        
        # INF 檔案內容
        $InfContent = @"
[NewRequest]
Subject = "CN=$HostHeader"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
SMIME = FALSE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = FALSE
ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
ProviderType = 12
RequestType = PKCS10
KeyUsage = 0xa0

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.1 ; Server Authentication

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns=$HostHeader&"
"@
        $InfContent | Out-File -FilePath $InfFile -Encoding ASCII  # 建立 INF 檔案
        
        # 使用 certreq 建立憑證申請
        certreq -new $InfFile $ReqFile | Out-Null  # 建立憑證申請檔
        
        # 向 CA 提交申請並取得憑證
        certreq -submit -attrib "CertificateTemplate:WebServer" $ReqFile $CerFile | Out-Null  # 向 CA 提交申請
        
        # 安裝憑證
        certreq -accept $CerFile | Out-Null  # 安裝憑證到本機憑證存放區
        
        # 取得剛安裝的憑證
        Start-Sleep -Seconds 2  # 等待 2 秒讓憑證完成安裝
        $NewCert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { 
            $_.Subject -like "*CN=$HostHeader*" -and $_.NotAfter -gt (Get-Date)
        } | Select-Object -First 1  # 取得新安裝的憑證
        
        if ($null -ne $NewCert) {  # 若成功取得憑證
            $CertThumbprint = $NewCert.Thumbprint  # 儲存憑證指紋
            Write-Host "✓ 憑證申請成功（指紋：$CertThumbprint）" -ForegroundColor Green  # 顯示成功訊息
        } else {
            throw "無法取得憑證"  # 拋出錯誤
        }
        
        # 清理暫存檔案
        Remove-Item $InfFile, $ReqFile, $CerFile -ErrorAction SilentlyContinue  # 刪除暫存檔案
    }
} catch {
    Write-Host "✗ 申請憑證失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
    Write-Host "⊙ 請確認 AD CS 已正確安裝且 WebServer 範本已啟用" -ForegroundColor Yellow  # 顯示提示
    Write-Host "⊙ 您也可以使用憑證管理員手動申請憑證" -ForegroundColor Yellow  # 顯示替代方案
    exit  # 結束腳本
}

# 步驟 5：設定 HTTPS 綁定（Port 443）
Write-Host "`n步驟 5：設定 HTTPS 綁定..." -ForegroundColor Cyan  # 顯示進度
try {
    # 移除現有的 HTTPS 綁定
    Get-WebBinding -Name $WebsiteName -Protocol "https" | Remove-WebBinding -ErrorAction SilentlyContinue  # 移除現有綁定
    
    # 新增 HTTPS 綁定
    New-WebBinding -Name $WebsiteName -Protocol "https" -Port 443 -HostHeader $HostHeader -SslFlags 1  # 新增 HTTPS 綁定，使用 SNI
    
    # 綁定憑證
    $Binding = Get-WebBinding -Name $WebsiteName -Protocol "https"  # 取得 HTTPS 綁定
    $Binding.AddSslCertificate($CertThumbprint, "My")  # 將憑證綁定到 HTTPS
    
    Write-Host "✓ 已設定 HTTPS 綁定：$HostHeader :443" -ForegroundColor Green  # 設定完成
} catch {
    Write-Host "✗ 設定 HTTPS 綁定失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 步驟 6：啟動網站
Write-Host "`n步驟 6：啟動網站..." -ForegroundColor Cyan  # 顯示進度
try {
    Start-Website -Name $WebsiteName  # 啟動網站
    Write-Host "✓ 網站已啟動" -ForegroundColor Green  # 啟動完成
} catch {
    Write-Host "✗ 啟動網站失敗：$($_.Exception.Message)" -ForegroundColor Red  # 顯示錯誤訊息
}

# 顯示完成訊息和驗證資訊
Write-Host "`n===============================================================================" -ForegroundColor Cyan
Write-Host "  IIS HTTPS 設定完成" -ForegroundColor Green
Write-Host "===============================================================================" -ForegroundColor Cyan
Write-Host "`n存取網址：" -ForegroundColor Yellow
Write-Host "  HTTP:  http://$HostHeader" -ForegroundColor White  # HTTP 網址
Write-Host "  HTTPS: https://$HostHeader" -ForegroundColor White  # HTTPS 網址
Write-Host "`n驗證命令：" -ForegroundColor Yellow
Write-Host "  Get-Website -Name '$WebsiteName'" -ForegroundColor Gray  # 查看網站
Write-Host "  Get-WebBinding -Name '$WebsiteName'" -ForegroundColor Gray  # 查看綁定
Write-Host "  Get-ChildItem Cert:\LocalMachine\My | Where-Object { `$_.Subject -like '*$HostHeader*' }" -ForegroundColor Gray  # 查看憑證
Write-Host ""  # 空行
