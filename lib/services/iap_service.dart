import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';
import 'package:kira_artisi_hesapla/services/billing_gateway.dart';

/// Satın alma başlatma sonucu (asıl grant purchaseStream’den gelir).
enum BuyLaunchResult {
  /// Billing sheet açıldı / istek gönderildi.
  launched,

  /// Mağaza (Play Services) yok.
  storeUnavailable,

  /// Ürün sorgulanamadı / Console’da yok.
  productMissing,

  /// Zaten sahip → restore tetiklendi / Pro yazıldı.
  alreadyOwned,

  /// launch false veya bilinmeyen hata.
  failed,
}

class BuyOutcome {
  const BuyOutcome(this.result, {this.message});

  final BuyLaunchResult result;
  final String? message;

  bool get ok =>
      result == BuyLaunchResult.launched ||
      result == BuyLaunchResult.alreadyOwned;
}

/// Mağaza ownership sorgusu sonucu.
enum OwnershipSyncResult {
  /// Restore/query başarısız veya timeout — yerel entitlement korunur.
  storeFailed,

  /// Mağaza `kira_pro_lifetime` owned olduğunu doğruladı.
  owned,

  /// Mağaza sorgusu başarılı ve ürün owned değil (refund/revoke).
  notOwned,
}

/// Paywall / Ayarlar için katalog + akış durumu.
@immutable
class IapCatalogState {
  const IapCatalogState({
    this.loading = true,
    this.storeAvailable = false,
    this.localizedPrice,
    this.currencyCode,
    this.productTitle,
    this.purchasePending = false,
    this.busy = false,
    this.lastMessage,
  });

  final bool loading;
  final bool storeAvailable;

  /// Play’in verdiği yerelleştirilmiş fiyat (örn. "₺199,99") — hardcode yok.
  final String? localizedPrice;
  final String? currencyCode;
  final String? productTitle;
  final bool purchasePending;
  final bool busy;
  final String? lastMessage;

  bool get hasStorePrice =>
      localizedPrice != null && localizedPrice!.trim().isNotEmpty;

  /// UI’da gösterilecek fiyat metni (hardcoded ₺199 yok).
  String get priceForUi {
    if (hasStorePrice) return localizedPrice!.trim();
    if (loading) return 'Fiyat yükleniyor…';
    return 'Mağazadan alın';
  }

  IapCatalogState copyWith({
    bool? loading,
    bool? storeAvailable,
    String? localizedPrice,
    String? currencyCode,
    String? productTitle,
    bool? purchasePending,
    bool? busy,
    String? lastMessage,
    bool clearMessage = false,
    bool clearPrice = false,
  }) {
    return IapCatalogState(
      loading: loading ?? this.loading,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      localizedPrice:
          clearPrice ? null : (localizedPrice ?? this.localizedPrice),
      currencyCode: currencyCode ?? this.currencyCode,
      productTitle: productTitle ?? this.productTitle,
      purchasePending: purchasePending ?? this.purchasePending,
      busy: busy ?? this.busy,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
    );
  }
}

/// Non-consumable lifetime Pro — Play Billing.
///
/// Entitlement [ProRepository] ile önbelleklenir.
/// - Mağaza sorgusu **başarısız** → yerel Pro korunur (offline / hata).
/// - Mağaza sorgusu **başarılı** ve ürün owned değil → yerel Pro kapatılır
///   (refund / revoke).
/// - Owned → Pro açılır (restore / reinstall).
class IapService extends ChangeNotifier {
  IapService(
    this._proRepo, {
    BillingGateway? gateway,
    this.productId = AppConstants.iapProductId,
    this.ownershipSyncTimeout = const Duration(seconds: 8),
  }) : _gateway = gateway ?? PlayBillingGateway();

  final ProRepository _proRepo;
  final BillingGateway _gateway;
  final String productId;
  final Duration ownershipSyncTimeout;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  void Function(bool isPro)? _onProChanged;

  /// Restore ownership probe (null değilse bir sonraki purchaseStream batch’i cevaptır).
  Completer<bool>? _ownershipProbe;

  IapCatalogState _state = const IapCatalogState();
  IapCatalogState get state => _state;

  bool get available => _state.storeAvailable;
  ProductDetails? get product => _product;
  String? get lastError => _state.lastMessage;
  String get priceForUi => _state.priceForUi;

  void _setState(IapCatalogState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> init({required void Function(bool isPro) onProChanged}) async {
    _onProChanged = onProChanged;
    _setState(_state.copyWith(loading: true, clearMessage: true));

    final storeOk = await _gateway.isAvailable();
    if (!storeOk) {
      _setState(
        _state.copyWith(
          loading: false,
          storeAvailable: false,
          lastMessage: 'Mağaza kullanılamıyor (Play Services / emülatör).',
        ),
      );
      // Mağaza yok → yerel entitlement korunur.
      return;
    }

    _sub ??= _gateway.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        _failOwnershipProbe();
        _setState(_state.copyWith(lastMessage: e.toString(), busy: false));
      },
    );

    await _refreshCatalog();
    await syncOwnershipFromStore();
  }

  Future<void> _refreshCatalog() async {
    final response = await _gateway.queryProductDetails({productId});
    if (response.error != null) {
      _setState(
        _state.copyWith(
          loading: false,
          storeAvailable: true,
          lastMessage: response.error!.message,
          clearPrice: response.productDetails.isEmpty,
        ),
      );
    }

    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.firstWhere(
        (p) => p.id == productId,
        orElse: () => response.productDetails.first,
      );
      _setState(
        _state.copyWith(
          loading: false,
          storeAvailable: true,
          localizedPrice: _product!.price,
          currencyCode: _product!.currencyCode,
          productTitle: _product!.title,
          clearMessage: response.error == null,
        ),
      );
    } else {
      _product = null;
      _setState(
        _state.copyWith(
          loading: false,
          storeAvailable: true,
          clearPrice: true,
          lastMessage: response.error?.message ??
              'Ürün bulunamadı. Play Console’da "$productId" ekleyin.',
        ),
      );
    }
  }

  /// Play ownership ile yerel Pro’yu hizalar.
  ///
  /// [OwnershipSyncResult.storeFailed] → local korunur.
  /// [OwnershipSyncResult.notOwned] → local Pro kapatılır.
  Future<OwnershipSyncResult> syncOwnershipFromStore() async {
    if (!_state.storeAvailable) {
      return OwnershipSyncResult.storeFailed;
    }

    final probe = Completer<bool>();
    _ownershipProbe = probe;

    try {
      await _gateway.restorePurchases();
    } catch (e) {
      _ownershipProbe = null;
      _setState(
        _state.copyWith(
          lastMessage: 'Geri yükleme başlatılamadı: $e',
        ),
      );
      return OwnershipSyncResult.storeFailed;
    }

    try {
      final owned = await probe.future.timeout(ownershipSyncTimeout);
      _ownershipProbe = null;
      if (owned) {
        return OwnershipSyncResult.owned;
      }
      if (_proRepo.isPro) {
        await _revokePro();
        _setState(
          _state.copyWith(
            lastMessage:
                'Pro satın alma mağazada bulunamadı (iade/iptal olabilir).',
          ),
        );
      }
      return OwnershipSyncResult.notOwned;
    } on TimeoutException {
      _ownershipProbe = null;
      // Timeout = güvenli taraf: yerel korunur.
      return OwnershipSyncResult.storeFailed;
    }
  }

  /// Lifetime non-consumable satın alma başlatır.
  Future<BuyOutcome> buy() async {
    _setState(
      _state.copyWith(busy: true, purchasePending: false, clearMessage: true),
    );

    if (!_state.storeAvailable) {
      const msg = 'Mağaza kullanılamıyor.';
      _setState(_state.copyWith(busy: false, lastMessage: msg));
      return const BuyOutcome(BuyLaunchResult.storeUnavailable, message: msg);
    }

    if (_product == null) {
      await _refreshCatalog();
    }
    if (_product == null) {
      final msg = _state.lastMessage ??
          'Ürün bulunamadı. Play Console’da "$productId" ekleyin.';
      _setState(_state.copyWith(busy: false, lastMessage: msg));
      return BuyOutcome(BuyLaunchResult.productMissing, message: msg);
    }

    try {
      final launched = await _gateway.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!),
      );
      if (!launched) {
        const msg = 'Satın alma başlatılamadı.';
        _setState(_state.copyWith(busy: false, lastMessage: msg));
        return const BuyOutcome(BuyLaunchResult.failed, message: msg);
      }
      _setState(_state.copyWith(busy: false));
      return const BuyOutcome(BuyLaunchResult.launched);
    } catch (e) {
      if (_looksAlreadyOwned(e.toString())) {
        await _grantFromAlreadyOwned();
        return const BuyOutcome(
          BuyLaunchResult.alreadyOwned,
          message: 'Satın alma zaten bu hesapta. Pro geri yüklendi.',
        );
      }
      final msg = e.toString();
      _setState(_state.copyWith(busy: false, lastMessage: msg));
      return BuyOutcome(BuyLaunchResult.failed, message: msg);
    }
  }

  Future<OwnershipSyncResult> restore({
    void Function(bool isPro)? onProChanged,
  }) async {
    if (onProChanged != null) _onProChanged = onProChanged;
    if (!_state.storeAvailable) {
      _setState(
        _state.copyWith(
          lastMessage: 'Mağaza kullanılamıyor; geri yükleme yapılamadı.',
        ),
      );
      return OwnershipSyncResult.storeFailed;
    }
    _setState(_state.copyWith(busy: true, clearMessage: true));
    final result = await syncOwnershipFromStore();
    _setState(
      _state.copyWith(
        busy: false,
        lastMessage: switch (result) {
          OwnershipSyncResult.owned => 'Satın alımlar geri yüklendi.',
          OwnershipSyncResult.notOwned =>
            'Geri yüklenecek satın alma bulunamadı.',
          OwnershipSyncResult.storeFailed =>
            _state.lastMessage ??
                'Mağaza yanıt vermedi; mevcut Pro durumu korundu.',
        },
      ),
    );
    return result;
  }

  Future<void> _grantFromAlreadyOwned() async {
    await _grantPro();
    // Play tarafını tamamlamak için restore; ownership probe açmadan çağır
    // (boş liste yerel Pro’yu düşürmesin).
    try {
      await _gateway.restorePurchases();
    } catch (_) {}
    _setState(
      _state.copyWith(
        busy: false,
        purchasePending: false,
        lastMessage: 'Satın alma zaten bu hesapta. Pro aktif.',
      ),
    );
  }

  void _failOwnershipProbe() {
    final probe = _ownershipProbe;
    if (probe != null && !probe.isCompleted) {
      // false değil — timeout/fail yolu için completer’ı iptal etmiyoruz;
      // stream error’da storeFailed olsun diye complete etmeyip timeout’a bırakmak
      // yavaş. Doğrudan false vermek revoke tetikler — istemeyiz.
      // Bu yüzden probe’u düşürüp future’ı hata ile bitirmiyoruz; sync tarafı
      // timeout ile storeFailed alır. Burada probe’u null’a çekmek race yaratır.
      // En temizi: Completer’ı hiç complete etmeden bırak → timeout → storeFailed.
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    var sawOwned = false;

    for (final p in purchases) {
      final matchesProduct =
          p.productID.isEmpty || p.productID == productId;

      if (!matchesProduct) continue;

      switch (p.status) {
        case PurchaseStatus.pending:
          _setState(
            _state.copyWith(
              purchasePending: true,
              busy: false,
              lastMessage: 'Ödeme onay bekliyor…',
            ),
          );
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (p.productID == productId) {
            sawOwned = true;
            await _grantPro(purchaseId: p.purchaseID);
            _setState(
              _state.copyWith(
                purchasePending: false,
                busy: false,
                lastMessage: p.status == PurchaseStatus.restored
                    ? 'Satın alımlar geri yüklendi.'
                    : 'Pro aktif.',
              ),
            );
          }
          if (p.pendingCompletePurchase) {
            await _gateway.completePurchase(p);
          }
          break;

        case PurchaseStatus.canceled:
          _setState(
            _state.copyWith(
              purchasePending: false,
              busy: false,
              lastMessage: 'Satın alma iptal edildi.',
            ),
          );
          if (p.pendingCompletePurchase) {
            await _gateway.completePurchase(p);
          }
          break;

        case PurchaseStatus.error:
          await _handlePurchaseError(p);
          if (_looksAlreadyOwned(
            '${p.error?.code ?? ''} ${p.error?.message ?? ''} ${p.error?.details ?? ''}',
          )) {
            sawOwned = true;
          }
          break;
      }
    }

    final probe = _ownershipProbe;
    if (probe != null && !probe.isCompleted) {
      probe.complete(sawOwned);
    }
  }

  Future<void> _handlePurchaseError(PurchaseDetails p) async {
    final err = p.error;
    final blob =
        '${err?.code ?? ''} ${err?.message ?? ''} ${err?.details ?? ''}';

    if (_looksAlreadyOwned(blob)) {
      await _grantFromAlreadyOwned();
      if (p.pendingCompletePurchase) {
        await _gateway.completePurchase(p);
      }
      return;
    }

    _setState(
      _state.copyWith(
        purchasePending: false,
        busy: false,
        lastMessage: err?.message ?? 'Satın alma hatası',
      ),
    );
    if (p.pendingCompletePurchase) {
      await _gateway.completePurchase(p);
    }
  }

  Future<void> _grantPro({String? purchaseId}) async {
    await _proRepo.setPro(true, purchaseId: purchaseId);
    _onProChanged?.call(true);
  }

  Future<void> _revokePro() async {
    await _proRepo.setPro(false);
    _onProChanged?.call(false);
  }

  static bool _looksAlreadyOwned(String blob) {
    final s = blob.toLowerCase();
    return s.contains('alreadyowned') ||
        s.contains('already_owned') ||
        s.contains('item_already_owned') ||
        s.contains('already owned') ||
        s.contains('itemalreadyowned');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
