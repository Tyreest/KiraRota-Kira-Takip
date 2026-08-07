import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kira_artisi_hesapla/services/billing_gateway.dart';

/// Test double for [BillingGateway].
class FakeBillingGateway implements BillingGateway {
  FakeBillingGateway({
    this.available = true,
    this.product,
    this.buyReturns = true,
    this.buyThrows,
    this.queryError,
    this.restoreThrows,
    this.restoreEmits,
    this.autoEmitOnRestore = true,
  });

  bool available;
  ProductDetails? product;
  bool buyReturns;
  Object? buyThrows;
  IAPError? queryError;
  Object? restoreThrows;

  /// `restorePurchases` sonrası yayınlanacak liste (`autoEmitOnRestore` true ise).
  /// null → boş liste (başarılı “owned değil”).
  List<PurchaseDetails>? restoreEmits;

  /// false → hiç emit yok (timeout / storeFailed simülasyonu).
  bool autoEmitOnRestore;

  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseDetails> completed = [];
  int buyCalls = 0;
  int restoreCalls = 0;
  int queryCalls = 0;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  static ProductDetails sampleProduct({
    String id = 'kira_pro_lifetime',
    String price = '₺199,99',
    String currencyCode = 'TRY',
    double rawPrice = 199.99,
  }) {
    return ProductDetails(
      id: id,
      title: 'Kira Asistanı Pro',
      description: 'Lifetime',
      price: price,
      rawPrice: rawPrice,
      currencyCode: currencyCode,
    );
  }

  static PurchaseDetails purchase({
    required PurchaseStatus status,
    String productId = 'kira_pro_lifetime',
    String purchaseId = 'order-1',
    IAPError? error,
    bool pendingComplete = true,
  }) {
    final details = PurchaseDetails(
      productID: productId,
      purchaseID: purchaseId,
      status: status,
      transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server',
        source: 'google_play',
      ),
    )..pendingCompletePurchase = pendingComplete;
    if (error != null) {
      details.error = error;
    }
    return details;
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queryCalls++;
    return ProductDetailsResponse(
      productDetails: [
        if (product != null && identifiers.contains(product!.id)) product!,
      ],
      notFoundIDs: product == null
          ? identifiers.toList()
          : identifiers.where((id) => id != product!.id).toList(),
      error: queryError,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    if (buyThrows != null) throw buyThrows!;
    return buyReturns;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
    if (restoreThrows != null) throw restoreThrows!;
    if (autoEmitOnRestore) {
      final list = restoreEmits ?? <PurchaseDetails>[];
      scheduleMicrotask(() => emit(list));
    }
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  Future<void> dispose() => _controller.close();
}
