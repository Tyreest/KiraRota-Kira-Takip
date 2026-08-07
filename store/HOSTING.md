# Gizlilik politikası — HTTPS yayınlama

Play Console **Privacy policy** alanı HTTPS URL ister.
Hazır dosyalar: proje kökündeki `docs/` klasörü.

| Sayfa | Dosya |
|-------|--------|
| Gizlilik (Play’e bu URL) | `docs/index.html` |
| Kullanım şartları | `docs/terms.html` |
| Yasal uyarı | `docs/yasal.html` |

## Önerilen yol: GitHub Pages (ücretsiz)

### 1) Repo oluştur ve gönder
GitHub’da örn. `kira-artisi-hesapla` veya `tyreest-legal` adında **public** repo aç.

```powershell
cd C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla
git add docs store/legal
git status
# İlk commit’i sen onayladıktan sonra:
# git commit -m "Add hosted privacy policy pages"
# git branch -M main
# git remote add origin https://github.com/KULLANICI/REPO.git
# git push -u origin main
```

> Not: Tüm projeyi de push edebilirsin; Pages yalnızca `docs/` kullanır.

### 2) Pages’i aç
GitHub → repo → **Settings** → **Pages**:
- Source: **Deploy from a branch**
- Branch: `main` / folder: **/docs**
- Save

Birkaç dakika sonra URL:
`https://KULLANICI.github.io/REPO/`

Play’e yapıştırılacak adres (örnek):
`https://KULLANICI.github.io/REPO/`  
veya açıkça: `https://KULLANICI.github.io/REPO/index.html`

### 3) Kontrol
Tarayıcıda sayfa açılmalı; “Gizlilik Politikası” başlığı görünmeli.

## Alternatif: Netlify Drop
1. https://app.netlify.com/drop  
2. `docs` klasörünü sürükle  
3. Verilen `https://….netlify.app` URL’sini Play’e yapıştır

## Play Console
**App content → Privacy policy** → URL’yi kaydet.

Tamamlanınca `store/TEST.md` ve `store/play_checklist.md` içinde ilgili kutuyu işaretle.
