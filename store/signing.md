# Release imza (upload keystore)

Release AAB **debug imza ile üretilmez**. `android/key.properties` yoksa Gradle hata verir.

## 1) Keystore oluştur (bir kez)

Şifreleri password manager’da sakla. Keystore kaybolursa aynı uygulama kimliğiyle güncelleme imzalayamazsın.

```powershell
cd C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla
powershell -ExecutionPolicy Bypass -File tool\create_upload_keystore.ps1
```

Çıktılar (git’e **girmez**):

| Dosya | Açıklama |
|-------|----------|
| `android/keystore/upload-keystore.jks` | Upload keystore |
| `android/key.properties` | Şifre + alias + yol |

Örnek şablon: `android/key.properties.example`

## 2) Yapılandırma kontrolü

`android/app/build.gradle.kts`:

- Release yalnızca `signingConfigs.release` kullanır
- `minifyEnabled` + `shrinkResources` açık
- ProGuard: `android/app/proguard-rules.pro`

## 3) Signed AAB

```powershell
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

İmza doğrula (opsiyonel):

```powershell
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
```

## 4) Play Console

1. İlk yüklemede bu upload key’in sertifikasını Play’e ver (App integrity / App signing)
2. Play App Signing açıksa Google app signing key’i yönetir; sen upload key ile yüklersin
3. Keystore + `key.properties` yedeğini güvenli sakla

## Güvenlik

- `key.properties`, `*.jks`, `*.keystore` → `.gitignore` / `android/.gitignore`
- CI’da secret olarak enjekte et; repoya koyma
