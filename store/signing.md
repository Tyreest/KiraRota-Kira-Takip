# Upload keystore oluştur (bir kez)

Şifreleri güvenli yerde sakla (password manager). Keystore kaybolursa güncelleme imzalayamazsın.

```powershell
cd C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla
powershell -ExecutionPolicy Bypass -File tool\create_upload_keystore.ps1
```

Script:
1. `android/keystore/upload-keystore.jks` üretir
2. `android/key.properties` yazar (git’e girmez)
3. `flutter build appbundle --release` komutunu hatırlatır

Çıktı AAB: `build/app/outputs/bundle/release/app-release.aab`
