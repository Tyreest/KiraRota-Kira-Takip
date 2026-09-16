# Gizlilik politikası — GitHub Pages kurulumu

Play Console **App content → Privacy policy** alanı HTTPS URL ister.

| Dosya | Rol |
|-------|-----|
| `docs/privacy-policy.html` | Production gizlilik politikası (ana metin) |
| `docs/index.html` | `privacy-policy.html`’e yönlendirir (eski kök URL uyumu) |
| `docs/terms.html` | Kullanım şartları |
| `docs/yasal.html` | Yasal uyarı |

Uygulama sabiti: `AppConstants.privacyUrl` →  
`https://tyreest.github.io/KiraRota-Kira-Takip/privacy-policy.html`

> Not: Repo eski adı `kira-artisi-hesapla` idi. GitHub Pages yolu repo adını kullandığı
> için eski `…/kira-artisi-hesapla/…` URL’leri **404** verir. Büyük/küçük harf
> duyarlıdır (`kirarota-kira-takip` de 404).

## 1) Değişiklikleri main’e gönder

```powershell
cd C:\Users\yigit\Desktop\Projeler\KiraRota–KiraTakip
git status
git add docs/privacy-policy.html docs/index.html store/PRIVACY_POLICY_SETUP.md
# İlgili sabit güncellendiyse:
git add lib/core/constants.dart
git commit -m "fix: repair privacy policy and production URLs"
git push origin main
```

Repo: `https://github.com/Tyreest/KiraRota-Kira-Takip` (public olmalı; Pages için gerekli).

## 2) GitHub Pages’i aç / doğrula

1. GitHub → **Tyreest/KiraRota-Kira-Takip** → **Settings** → **Pages**
2. **Build and deployment**
   - Source: **Deploy from a branch**
   - Branch: **main**
   - Folder: **/docs**
3. **Save**
4. Birkaç dakika sonra site adresi:
   - Kök: `https://tyreest.github.io/KiraRota-Kira-Takip/`
   - Politika: `https://tyreest.github.io/KiraRota-Kira-Takip/privacy-policy.html`

## 3) Tarayıcı kontrolü

- [ ] `privacy-policy.html` açılıyor (HTTPS, JavaScript gerekmez)
- [ ] Başlık: **Gizlilik Politikası**
- [ ] Geliştirici / gizlilik iletişim bölümü görünüyor
- [ ] Hesap silme bölümü **yok**
- [ ] Kök URL (`/`) politikaya yönleniyor

## 4) Play Console

1. **Play Console** → uygulama `com.tyreest.kiraartisi`
2. **Policy → App content → Privacy policy**
3. URL yapıştır:
   ```
   https://tyreest.github.io/KiraRota-Kira-Takip/privacy-policy.html
   ```
4. Kaydet

## 5) Data Safety (kısa hatırlatma)

Politika ile uyumlu beyan için (ayrıntı metinde):

- Hesap / login: **yok**
- Kira/geçmiş: **cihazda**; Tyreest sunucusuna gönderilmez
- AdMob (ücretsiz): cihaz/reklam kimliği ve uygulama etkinliği — üçüncü taraf (Google)
- Play Billing: satın alma Google tarafından işlenir
- Auto Backup / cihaz transferi: yerel uygulama verisi aktarılabilir; Pro bayrağı kanıt değildir

## Alternatif: Netlify Drop

1. https://app.netlify.com/drop  
2. `docs` klasörünü sürükle  
3. Verilen `https://….netlify.app/privacy-policy.html` adresini Play’e yapıştır  
4. `AppConstants.privacyUrl` değerini yeni URL ile güncelle

## İletişim alanı notu

Politika, gizlilik talepleri için **Play Console geliştirici e-posta adresini** kullanır.
Ayrı bir `privacy@…` kutusu açarsanız `docs/privacy-policy.html` içindeki
“Geliştirici / gizlilik iletişim” bölümünü güncelleyin.
