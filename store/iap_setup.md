# Play Console — Pro IAP kurulumu

Ürün ID (uygulama ile aynı): **`kira_pro_lifetime`**  
Tür: **Managed product / One-time** (abonelik değil)  
Görünen fiyat hedefi: **₺199** (Play’de ülke fiyatı sen ayarlarsın)

## Adımlar

1. [Play Console](https://play.google.com/console) → uygulama `com.tyreest.kiraartisi`
2. **Monetize → Products → In-app products → Create product**
3. Product ID: `kira_pro_lifetime` (sonradan değiştirilemez)
4. Name / description (TR örneği):
   - Name: `Kira Asistanı Pro`
   - Description: `Reklamsız kullanım, PDF özet, yenileme hatırlatmaları, sınırsız geçmiş. Tek seferlik.`
5. Price: TRY 199 (veya eşdeğeri)
6. Status: **Active**
7. Uygulama **closed / internal testing** track’te yüklü olmalı; aksi halde satın alma test edilemez.

## Lisans testi
1. Play Console → **Settings → License testing**
2. Gmail hesaplarını ekle (test kullanıcıları)
3. Telefonda o Google hesabıyla giriş yap
4. Closed test’e katıl → uygulamayı yükle
5. Ayarlar → Pro’ya Geç → gerçek Billing sheet açılmalı

## Emülatör notu
Emülatörde Billing sık sık “API version 3 not supported” verir.
IAP doğrulaması için **gerçek cihaz + lisans test hesabı** kullan.

## Debug kolaylığı
Debug build’de ürün yoksa `IapService.buy()` Pro’yu açabilir; yayın doğrulaması için buna güvenme.
Ayarlar → **Geliştirme: Pro’yu aç** yalnızca debug’dadır.
