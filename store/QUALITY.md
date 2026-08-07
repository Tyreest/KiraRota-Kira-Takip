# Ürün kalite notları (Play öncesi — 7 Ağustos 2026)

## Bu turda kapatılanlar
- [x] 5+ yıl eşiği seçilen **günü** kullanıyor (`renewalDay`)
- [x] Varsayılan kira boş; tarihler bugüne göre
- [x] Oran tablosu 2024-01 … 2026-08 aylık dolduruldu (+ Ağustos %31,90)
- [x] `remoteRatesUrl` → GitHub raw `hosted/tufe_rates.json`
- [x] Onboarding’de Kullanım Şartları / Gizlilik tıklanabilir
- [x] Paywall Pro senkronu (kısa poll)
- [x] Sonuçta oran kaynağı etiketi; Oranlar’da dinamik durum metni

## Bilinçli açık (Play’e yakın)
- [ ] Gerçek AdMob App/Banner ID (şimdilik Google test ID)
- [ ] Upload keystore + imzalı AAB
- [ ] Play IAP `kira_pro_lifetime` + lisans testi
- [ ] %25 tarihi dönem motoru (v1.1+; tabloda not var)

## Test
`flutter test` → yeşil
