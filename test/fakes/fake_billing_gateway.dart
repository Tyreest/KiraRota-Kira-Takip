import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kira_artisi_hesapla/services/billing_gateway.dart';

/// Deterministik [BillingGateway] — gerçek Play'e bağlanmaz.
class FakeBillingGateway implements BillingGateway {
  FakeBillingGateway({
    this.available = true,
    List<ProductDetails>? products,
    this.queryThrows = false,
    this.restoreThrows = false,
    this.buyThrows,
    this.buyLaunched = true,
    this.emitOnRestore,
    this.silenceRestore = false,
  }) : products = products ?? <ProductDetails>[];

  bool available;
  List<ProductDetails> products;
  bool queryThrows;
  bool restoreThrows;
  Object? buyThrows;
  bool buyLaunched;

  /// [restorePurchases] çağrıldığında stream'e basılacak paket.
  /// `null` ve [silenceRestore] false ise boş liste (notOwned) basılır.
  List<PurchaseDetails>? emitOnRestore;

  /// true ise restore hiç emit etmez → ownership probe timeout.
  bool silenceRestore;

  int restoreCallCount = 0;
  int buyCallCount = 0;
  int queryCallCount = 0;
  int completeCallCount = 0;
  int purchaseStreamListenCount = 0;

  final List<PurchaseDetails> completedPurchases = <PurchaseDetails>[];

  final StreamController<List<PurchaseDetails>> _purchases =
      StreamController<List<PurchaseDetails>>.broadcast();

  void emitPurchases(List<PurchaseDetails> purchases) {
    if (!_purchases.isClosed) {
      _purchases.add(purchases);
    }
  }

  void emitError(Object error) {
    if (!_purchases.isClosed) {
      _purchases.addError(error);
    }
  }

  void dispose() {
    _purchases.close();
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    purchaseStreamListenCount++;
    return _purchases.stream;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    queryCallCount++;
    if (queryThrows) {
      throw StateError('queryProductDetails failed');
    }
    final matched = products.where((p) => identifiers.contains(p.id)).toList();
    final notFound = identifiers
        .where((id) => !matched.any((p) => p.id == id))
        .toList();
    return ProductDetailsResponse(
      productDetails: matched,
      notFoundIDs: notFound,
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCallCount++;
    if (buyThrows != null) {
      throw buyThrows!;
    }
    return buyLaunched;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCallCount++;
    if (restoreThrows) {
      throw StateError('restorePurchases failed');
    }
    if (silenceRestore) {
      return;
    }
    emitPurchases(emitOnRestore ?? const <PurchaseDetails>[]);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completeCallCount++;
    completedPurchases.add(purchase);
  }
}

ProductDetails fakeProduct({
  String id = 'kira_pro_lifetime',
  String price = '₺199,99',
  String currencyCode = 'TRY',
  String title = 'KiraRota Pro',
}) {
  return ProductDetails(
    id: id,
    title: title,
    description: 'Test lifetime Pro',
    price: price,
    rawPrice: 199.99,
    currencyCode: currencyCode,
  );
}

PurchaseDetails fakePurchase({
  required PurchaseStatus status,
  String productId = 'kira_pro_lifetime',
  String? purchaseId = 'purchase-1',
  bool pendingComplete = false,
  IAPError? error,
}) {
  final details = PurchaseDetails(
    purchaseID: purchaseId,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'google_play',
    ),
    transactionDate: '1700000000000',
    status: status,
  );
  details.pendingCompletePurchase = pendingComplete;
  details.error = error;
  return details;
}
