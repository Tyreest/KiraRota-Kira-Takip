import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';

/// Play Billing lifetime Pro.
/// Play Console'da aynı product ID ile managed product oluşturun.
class IapService {
  IapService(this._proRepo);

  final ProRepository _proRepo;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool available = false;
  ProductDetails? product;
  String? lastError;

  Future<void> init({required void Function(bool isPro) onProChanged}) async {
    available = await _iap.isAvailable();
    if (!available) {
      lastError = 'Mağaza kullanılamıyor (emülatör / Play Services).';
      return;
    }

    _sub = _iap.purchaseStream.listen(
      (purchases) => _onPurchases(purchases, onProChanged),
      onError: (Object e) => lastError = e.toString(),
    );

    final response = await _iap.queryProductDetails({
      AppConstants.iapProductId,
    });
    if (response.error != null) {
      lastError = response.error!.message;
    }
    if (response.productDetails.isNotEmpty) {
      product = response.productDetails.first;
    }

    await _iap.restorePurchases();
  }

  Future<bool> buy() async {
    lastError = null;
    if (!available) {
      lastError = 'Mağaza kullanılamıyor.';
      return false;
    }
    if (product == null) {
      // Geliştirme: ürün henüz Console'da yoksa debug unlock.
      if (kDebugMode) {
        await _proRepo.setPro(true);
        return true;
      }
      lastError =
          'Ürün bulunamadı. Play Console’da "${AppConstants.iapProductId}" ekleyin.';
      return false;
    }

    final param = PurchaseParam(productDetails: product!);
    return _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore(void Function(bool isPro) onProChanged) async {
    if (!available) return;
    await _iap.restorePurchases();
  }

  Future<void> _onPurchases(
    List<PurchaseDetails> purchases,
    void Function(bool isPro) onProChanged,
  ) async {
    for (final p in purchases) {
      if (p.productID != AppConstants.iapProductId) continue;

      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _proRepo.setPro(true);
        onProChanged(true);
        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      } else if (p.status == PurchaseStatus.error) {
        lastError = p.error?.message ?? 'Satın alma hatası';
      }
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
