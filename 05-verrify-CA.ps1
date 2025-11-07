#驗證清單（評分前自檢）
# CA 與服務狀態
Get-Service CertSvc

# CA 資訊
certutil -ca.info

# 目錄內發佈之根憑證/NTAuth 狀態
certutil -enterprise -viewstore root
certutil -enterprise -viewstore ntauth

# 範本與 CA 對應
certutil -catemplates

# 於客戶端（網域電腦）檢查是否已信任根 CA
certutil -store -enterprise root | findstr /C:"TCIVS-ROOT-CA"
