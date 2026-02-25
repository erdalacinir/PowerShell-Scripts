# ==========================================================
# AYARLAR - BURASI DEĞİŞTİRİLECEK
# ==========================================================
$TenantId      = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$ClientId      = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$ClientSecret  = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
# ==========================================================

$CsvPath        = "C:\OneDrive_Lisansli_Kullanicilar.csv"
$GrowthRate     = 0.20  # Yıllık büyüme oranı (%20)
$RetentionYears = 3     # Kaç yıl saklama hesabı yapılacak
$OverheadRate   = 0.30  # Backup ek yük (%30)

Write-Host "Modül kontrolü yapılıyor..."
$RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Users",
    "Microsoft.Graph.Files"
)
foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        Write-Host "$Module yükleniyor..."
        Install-Module $Module -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module $Module -Force
}

Write-Host ""
Write-Host "Token alınıyor..." -ForegroundColor Cyan

$TokenResponse = Invoke-RestMethod -Method POST `
    -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
    -Body @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
    }

$Token = $TokenResponse.access_token

if (-not $Token) {
    Write-Error "Token alınamadı. TenantId, ClientId ve ClientSecret bilgilerini kontrol edin."
    exit
}

Write-Host "Token alındı!" -ForegroundColor Green

$SecureToken = $Token | ConvertTo-SecureString -AsPlainText -Force
Connect-MgGraph -AccessToken $SecureToken -NoWelcome

$Context = Get-MgContext
if (-not $Context) {
    Write-Error "Graph bağlantısı kurulamadı."
    exit
}
Write-Host "Bağlantı başarılı!" -ForegroundColor Green

Write-Host "Lisanslı kullanıcılar çekiliyor..."

try {
    $LicensedUsers = Get-MgUser -All `
        -Filter "assignedLicenses/`$count ne 0" `
        -ConsistencyLevel eventual `
        -Property "Id,DisplayName,UserPrincipalName,AssignedLicenses" `
        -ErrorAction Stop
}
catch {
    Write-Warning "Sunucu filtresi çalışmadı, istemci filtresi deneniyor..."
    $LicensedUsers = Get-MgUser -All `
        -Property "Id,DisplayName,UserPrincipalName,AssignedLicenses" `
        -ErrorAction Stop |
        Where-Object { $_.AssignedLicenses.Count -gt 0 }
}

Write-Host "$($LicensedUsers.Count) lisanslı kullanıcı bulundu." -ForegroundColor Cyan

Write-Host "OneDrive kullanımları hesaplanıyor..."
$Report  = [System.Collections.Generic.List[PSCustomObject]]::new()
$Counter = 0

foreach ($User in $LicensedUsers) {
    $Counter++
    Write-Progress -Activity "OneDrive kontrol ediliyor" `
                   -Status "$Counter / $($LicensedUsers.Count) — $($User.UserPrincipalName)" `
                   -PercentComplete (($Counter / $LicensedUsers.Count) * 100)
    try {
        $Drive = Get-MgUserDrive -UserId $User.Id -ErrorAction Stop

        if ($null -eq $Drive -or $null -eq $Drive.Quota) {
            $Report.Add([PSCustomObject]@{
                DisplayName       = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                UsedStorageGB     = 0
                QuotaGB           = 0
                Durum             = "Quota bilgisi yok"
            })
            continue
        }

        # op_Division hatasını önlemek için tip kontrolü
        $UsedRaw  = $Drive.Quota.Used
        $TotalRaw = $Drive.Quota.Total
        $UsedGB   = if ($UsedRaw  -is [array]) { [math]::Round([long]$UsedRaw[0]  / 1GB, 2) }
                    else                        { [math]::Round([long]$UsedRaw     / 1GB, 2) }
        $TotalGB  = if ($TotalRaw -is [array]) { [math]::Round([long]$TotalRaw[0] / 1GB, 2) }
                    else                        { [math]::Round([long]$TotalRaw    / 1GB, 2) }

        $Report.Add([PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            UsedStorageGB     = $UsedGB
            QuotaGB           = $TotalGB
            Durum             = "OK"
        })
    }
    catch {
        $Report.Add([PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            UsedStorageGB     = 0
            QuotaGB           = 0
            Durum             = $_.Exception.Message
        })
    }
}

$Sorted = $Report | Sort-Object UsedStorageGB -Descending
$Sorted | Export-Csv $CsvPath -NoTypeInformation -Encoding UTF8

$TotalUsedGB = ($Report | Where-Object { $_.Durum -eq "OK" } | Measure-Object UsedStorageGB -Sum).Sum

$Year1              = [math]::Round($TotalUsedGB * [math]::Pow(1 + $GrowthRate, 1), 2)
$Year2              = [math]::Round($TotalUsedGB * [math]::Pow(1 + $GrowthRate, 2), 2)
$Year3              = [math]::Round($TotalUsedGB * [math]::Pow(1 + $GrowthRate, 3), 2)
$TotalWithRetention = [math]::Round($TotalUsedGB * $RetentionYears * (1 + $OverheadRate), 2)

$OkCount    = ($Report | Where-Object { $_.Durum -eq "OK" }).Count
$ErrorCount = ($Report | Where-Object { $_.Durum -ne "OK" }).Count

Write-Host ""
Write-Host "===========================================" -ForegroundColor Yellow
Write-Host "Başarılı  : $OkCount kullanıcı"
Write-Host "Hatalı    : $ErrorCount kullanıcı"
Write-Host ""
Write-Host "Mevcut Toplam OneDrive Kullanımı:"
Write-Host "  $([math]::Round($TotalUsedGB, 2)) GB / $([math]::Round($TotalUsedGB / 1024, 2)) TB"
Write-Host ""
Write-Host "Büyüme Projeksiyonu (%$($GrowthRate * 100) yıllık):"
Write-Host "  1. Yıl : $Year1 GB / $([math]::Round($Year1/1024,2)) TB"
Write-Host "  2. Yıl : $Year2 GB / $([math]::Round($Year2/1024,2)) TB"
Write-Host "  3. Yıl : $Year3 GB / $([math]::Round($Year3/1024,2)) TB"
Write-Host ""
Write-Host "Retention ($RetentionYears yıl) + Overhead (%$($OverheadRate*100)) ile Toplam İhtiyaç:"
Write-Host "  $TotalWithRetention GB / $([math]::Round($TotalWithRetention/1024,2)) TB"
Write-Host "===========================================" -ForegroundColor Yellow
Write-Host "CSV oluşturuldu: $CsvPath" -ForegroundColor Green
Write-Host ""
$Sorted | Format-Table -AutoSize