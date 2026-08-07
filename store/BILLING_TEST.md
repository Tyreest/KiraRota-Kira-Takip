# Billing test checklist

## Otomatik (CI / lokal)

```powershell
cd C:\Users\yigit\Desktop\Projeler\kira-artisi-hesapla
flutter test test/iap_billing_test.dart
flutter test
```

`iap_billing_test.dart` FakeBillingGateway ile doğrular:

| Senaryo | Beklenen |
|---------|----------|
| Katalog fiyatı | `ProductDetails.price` (örn. ₺212,99); hardcoded ₺199 yok |
| Mağaza yok | Fallback “Mağazadan alın”; yerel Pro silinmez |
| Ürün yok | `productMissing`; Pro unlock yok |
| `purchased` | Pro prefs’e yazılır + `completePurchase` |
| `pending` | Pro yok; “onay bekliyor” |
| `canceled` | Pro yok; iptal mesajı |
| `itemAlreadyOwned` | Pro grant + restore |
| `restored` | Pro grant (reinstall) |
| restore boş → timeout/fail | Yerel Pro korunur |
| store OK + not owned | Yerel Pro revoke (refund) |

## Gerçek Play — Internal / Closed track zorunlu

Aşağıdakiler **unit test ile kanıtlanamaz**; Play’in imzalı AAB + test track + lisans hesabı ister:

| # | Senaryo | Nasıl | Beklenen |
|---|---------|-------|----------|
| 1 | Localized fiyat | Internal/Closed build, Ayarlar / paywall | Play ülke fiyatı (örn. ₺199,99); “₺199” sabit metin yok |
| 2 | İlk satın alma | Lisans test hesabı → Şimdi Al | Billing sheet → Pro aktif, reklam yok |
| 3 | İptal | Sheet’te vazgeç | Pro yok; snack “iptal” |
| 4 | Pending (opsiyonel) | Test kartı / slow auth varsa | “onay bekliyor”; grant sonra |
| 5 | Already owned | Aynı hesapta tekrar Al | Hata yerine Pro / restore mesajı |
| 6 | Restore | Pro’yu cihazdan silip (clear data) → Geri yükle | Play geçmişinden Pro döner |
| 7 | Reinstall | Uygulamayı kaldır → Internal’dan tekrar yükle → açılış restore | Pro kalıcı |
| 8 | Offline Pro | Pro iken uçak modu → yeniden aç | Yerel entitlement durur |
| 9 | Free cihaz | Satın almamış hesap | Fiyat görünür; özellikler kilitli |

### Track notları

- **Internal testing:** en hızlı; 100 tester; lisans test Gmail şart.
- **Closed testing:** aynı Billing kuralları; daha geniş tester listesi.
- **Open / Production:** IAP canlı ödeme; lisans test “test” fiyatı vermeyebilir.
- Emülatör / `flutter run` debug APK (Play’den yüklenmemiş): ürün sorgusu çoğu zaman boş kalır → UI “Mağazadan alın” / “Fiyat yükleniyor…”.

### Kanıt kaydı (manuel)

Tarih: ____  
Track: Internal / Closed  
Cihaz: ____  
Hesap: ____  

- [ ] Fiyat mağazadan  
- [ ] Purchase OK  
- [ ] Cancel OK  
- [ ] Already-owned OK  
- [ ] Restore / reinstall OK  
- [ ] Pro offline kalıcı  
