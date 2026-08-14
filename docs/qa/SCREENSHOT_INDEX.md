# KiraRota Final Screenshot Index

Emulator: `Kira_Test_Pixel8` (Android 16 / API 36) · device ID her boot’ta doğrulanır  
Package: `com.tyreest.kiraartisi` · version `1.1.0+11`  
Folder: `docs/qa/final_screenshots/`

| Filename | Route / state | Test data | Edge-to-edge | Status |
|---|---|---|---|---|
| `01_home.png` | Özet · populated (Stitch final) | Ev · 39.000 TL · next 1 Temmuz 2027 · **KR + KiraRota** · dark hero **SIRADAKİ YENİLEME** · 321 gün (neutral) · metrics 1/0/0 · Son İşlemler kart · quick actions · nav **Özet** | Status + gesture bar; content above banner/nav | PASS |
| `02_home_empty.png` | Özet · empty | empty prefs · **KR + KiraRota** · empty CTA’lar · alt **Özet** | Empty CTA above bottom nav | PASS |
| `03_rentals.png` | Kiralarım | 1 aktif kira, filtreler | Nav + system inset OK | PASS |
| `04_rental_detail.png` | Kira Detayı | Seed rental + history | AppBar/status OK; CTA clear | PASS |
| `05_rental_add.png` | Kira Ekle | Empty form | Keyboard not open; bottom CTA area clear | PASS |
| `06_rental_edit.png` | Kira Düzenle | Seed fields | Form scrollable | PASS |
| `07_calculate.png` | Hesapla tab | Empty manual form | Nav highlight Hesapla | PASS |
| `08_result.png` | Yeni dönem sonucu | 38.000 → 50.122 (%31,9) | Source link + CTA above gesture | PASS |
| `09_result_requested_compare.png` | Sonuç · karşılaştırma UI | Comparison section visible; filled 55.000 diff not captured in automation | Same as result | PASS WITH NOTES |
| `10_rates.png` | Oranlar | Live TÜFE bundle Aug 2026 | Source link visible | PASS |
| `11_settings.png` | Ayarlar | Free Pro card | Backup + version row | PASS |
| `12_pro_paywall.png` | KiraRota Pro sheet | Dynamic store price area / Şimdi Al | Sheet + system inset | PASS |
| `13_reminder.png` | Yenileme Hatırlatması | Beşiktaş · 30/7/gün | Save CTA above gesture | PASS |
| `14_pdf_sheet.png` | PDF Raporu sheet | Cihaza Kaydet / Paylaş | Sheet over detail | PASS |
| `15_review_access.png` | Ayarlar (intended Review sheet) | 7-tap automation did not open sheet on device; feature covered by widget tests | Version row visible | FAIL (automation) |

## Notes

- `01_home.png` / `02_home_empty.png` yenilendi (2026-08-14): `stitch/` final Özet entegrasyonu — dark forest hero, metric strip altta, compact Son İşlemler, transparent green KR header (kutulu KR placeholder yok).
- Screenshots gerçek emulator debug build’den; `stitch/screen.png` final app screenshot olarak kullanılmaz.
- Gesture navigation. Inset davranışı widget testleriyle de kapsanır.
- Version bump bu UI task’ta yapılmadı (`1.1.0+11` korundu).
