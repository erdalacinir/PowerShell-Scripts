Ön Gereksinimler
Microsoft 365 Global Administrator veya Application Administrator rolü
Azure Portal erişimi: https://portal.azure.com

Adım 1: Azure Active Directory'e Git

https://portal.azure.com adresine giriş yap
Microsoft Entra ID uygulamasını seç
Sol panelden App registrations tıkla
Sağ üstten + New registration tıkla

Adım 2: Uygulamayı Kaydet
Açılan formda şunları doldur:
Uygulama adı ve desteklenen hesap türünü seç
Register butonuna tıkla.

Adım 3: Kimlik Bilgilerini Not Al
Kayıt sonrası açılan sayfada iki değeri kopyala ve bir yere not et:
Bilgi nerede Bulunur Application (client) IDOverview sayfası, üst kısımDirectory (tenant) IDOverview sayfası, üst kısım

Adım 4: Client Secret Oluştur
Sol panelden Certificates & secrets tıkla
Client secrets sekmesinde + New client secret tıkla
Description: OneDrive-Report-Secret
Expires: İhtiyacına göre seç (örn: 24 months)
Add tıkla
Oluşturulan Value sütunundaki değeri hemen kopyala

Adım 5: API İzinlerini Ekle
Sol panelden API permissions tıkla
+ Add a permission tıkla
Microsoft Graph seç
Application permissions seç
Aşağıdaki izinleri tek tek ara ve ekle:
User.Read.All
Files.Read.All
Sites.Read.All
Add permissions tıkla

Adım 6: Admin Consent Ver
İzinler eklendikten sonra yeşil tik görmüyorsan:
API permissions sayfasında Grant admin consent for [şirket adı] butonuna tıkla
Onay isteğini kabul et
Tüm izinlerin yanında yeşil tik ✅ görünmeli
Bu adım olmadan script Access Denied hatası verir.

Adım 7: Script Ayarlarını Doldur
Script dosyasının en üstündeki AYARLAR bölümünü doldur:
powershell
$TenantId     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Adım 3'ten
$ClientId     = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # Adım 3'ten
$ClientSecret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"     # Adım 4'ten
