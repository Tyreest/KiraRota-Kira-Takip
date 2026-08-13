# Google Play — Review Access (App access / login credentials)

## Ne işe yarar?

Play inceleme ekibi satın alma yapmadan Pro özelliklerini (PDF, hatırlatma, sınırsız geçmiş, reklamsız) test edebilir.

- Review erişimi **Play Billing sahipliği değildir**.
- Gerçek satın alma / restore / ownership akışı değişmez.
- Normal kullanıcı arayüzünde “review / test / developer” butonu yoktur.

## Console’a yapıştırılacak İngilizce talimat

```
Open the app → go to Settings → tap the app version text at the bottom 7 times → enter the review access code provided in this Play Console form. No account or purchase is required. To turn review access off, tap the version 7 times again and choose the option to disable review access.
```

Review access **code** alanına yalnızca geliştirme makinenizdeki yerel secret dosyasındaki kodu yazın. Bu kodu git’e commit etmeyin.

## Yerel kurulum (geliştirici)

1. `android/review_access.properties.example` → `android/review_access.properties`
2. SHA-256 hex’i `reviewAccessCodeSha256=` satırına koyun
3. Plaintext kodu `store/secrets/REVIEW_ACCESS_CODE.txt` içine koyun (gitignore)
4. Release AAB: `powershell -File tool/build_release_aab.ps1`  
   Script hash’i `--dart-define=REVIEW_ACCESS_CODE_SHA256=...` olarak geçirir; plaintext AAB’ye girmez.

Hash yoksa uygulama normal çalışır; yanlış/eksik kod doğrulaması başarısız olur.

## Davranış özeti

| Durum | Sonuç |
|-------|--------|
| Doğru kod | `reviewAccessEnabled` açılır |
| Yanlış kod | Açılmaz |
| Review açık | Pro özellikler kullanılabilir; reklam yok |
| Play ownership false | Review bayrağı silinmez |
| Review kapat | Yalnızca review bayrağı temizlenir; gerçek Pro dokunulmaz |

## Data / yedekleme

Review bayrağı cihazda yerel tutulur; uygulama verileri temizlenene kadar kalabilir. Android yedekleme açıksa diğer tercihler gibi aktarılabilir.
