# Play Billing — kurulum ve gerçek cihaz testi

Ürün ID: **`kira_pro_lifetime`**  
Tür: **Managed product / One-time (non-consumable)** — abonelik değil  
Fiyat: Play Console’da ülke bazlı (UI **hardcode etmez**; `ProductDetails.price` gösterir)

## Console adımları

1. Play Console → uygulama `com.tyreest.kiraartisi`
2. **Monetize → Products → In-app products → Create product**
3. Product ID: `kira_pro_lifetime` (değiştirilemez)
4. Name / description (TR):
   - Name: `Kira Asistanı Pro`
   - Description: `Reklamsız kullanım, PDF özet, yenileme hatırlatmaları, sınırsız geçmiş. Tek seferlik.`
5. Price: hedef TRY 199 (veya güncel fiyat) — uygulama bunu otomatik çeker
6. Status: **Active**
7. Uygulama **Internal testing** veya **Closed testing** track’e yüklenmiş olmalı

## Lisans testi

1. Play Console → **Settings → License testing**
2. Gmail’leri ekle
3. Telefonda o Google hesabı + test track’e katılım
4. Ayarlar → Pro’ya Geç → gerçek Billing sheet

## Emülatör

Billing çoğu emülatörde çalışmaz (“API version 3 not supported”).  
**Gerçek cihaz + lisans hesabı** kullan.

## Debug

Ayarlar → **Geliştirme: Pro’yu aç** yalnızca `kDebugMode`.  
`buy()` ürün yokken artık sessizce Pro açmaz.
