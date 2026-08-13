import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kira_artisi_hesapla/services/billing_gateway.dart';

/// Android'deki [GooglePlayProductDetails] gibi [ProductDetails] alt tipi.
///
/// Play, `productDetails` listesini runtime'da `List<AltTip>` olarak döndürebilir;
/// `firstWhere(..., orElse: () => ProductDetails)` tip hatası üretir.
class FakeAndroidProductDetails extends ProductDetails {
  FakeAndroidProductDetails({
    required super.id,
    required super.title,
    required super.description,
    required super.price,
    required super.rawPrice,
    required super.currencyCode,
  });
}

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
    this.useAndroidSubtypeList = false,
    this.queryThrows,
  });

  bool available;
  ProductDetails? product;
  bool buyReturns;
  Object? buyThrows;
  IAPError? queryError;
  Object? restoreThrows;
  Object? queryThrows;

  /// true → response.productDetails runtime tipi `List<FakeAndroidProductDetails>`.
  bool useAndroidSubtypeList;

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
      title: 'KiraRota Pro',
      description: 'Lifetime',
      price: price,
      rawPrice: rawPrice,
      currencyCode: currencyCode,
    );
  }

  static FakeAndroidProductDetails sampleAndroidProduct({
    String id = 'kira_pro_lifetime',
    String price = '₺212,99',
    String currencyCode = 'TRY',
    double rawPrice = 212.99,
  }) {
    return FakeAndroidProductDetails(
      id: id,
      title: 'KiraRota Pro',
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
    if (queryThrows != null) throw queryThrows!;

    final ProductDetails? match =
        product != null && identifiers.contains(product!.id) ? product : null;

    late final List<ProductDetails> details;
    if (match == null) {
      details = const <ProductDetails>[];
    } else if (useAndroidSubtypeList) {
      final android = match is FakeAndroidProductDetails
          ? match
          : FakeAndroidProductDetails(
              id: match.id,
              title: match.title,
              description: match.description,
              price: match.price,
              rawPrice: match.rawPrice,
              currencyCode: match.currencyCode,
            );
      // Cast: tip sistemine List<ProductDetails> de, runtime List<Subtype> kalsın
      // (Play Android GooglePlayProductDetails listesi ile aynı senaryo).
      details = <FakeAndroidProductDetails>[android] as List<ProductDetails>;
    } else {
      details = <ProductDetails>[match];
    }

    return ProductDetailsResponse(
      productDetails: details,
      notFoundIDs: match == null
          ? identifiers.toList()
          : identifiers.where((id) => id != match.id).toList(),
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
