import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';
import 'package:kira_artisi_hesapla/services/iap_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_billing_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBillingGateway gateway;
  late ProRepository proRepo;
  late IapService iap;
  var proCallbacks = <bool>[];
  var ready = false;

  Future<void> setup({
    bool available = true,
    ProductDetails? product,
    bool catalogHasProduct = true,
    Map<String, Object> prefs = const {},
    List<PurchaseDetails>? restoreEmits,
    bool autoEmitOnRestore = true,
    Object? restoreThrows,
    Duration ownershipSyncTimeout = const Duration(seconds: 8),
  }) async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(prefs));
    final sp = await SharedPreferences.getInstance();
    proRepo = ProRepository(sp);
    gateway = FakeBillingGateway(
      available: available,
      product: catalogHasProduct
          ? (product ?? FakeBillingGateway.sampleProduct())
          : null,
      restoreEmits: restoreEmits,
      autoEmitOnRestore: autoEmitOnRestore,
      restoreThrows: restoreThrows,
    );
    iap = IapService(
      proRepo,
      gateway: gateway,
      ownershipSyncTimeout: ownershipSyncTimeout,
    );
    proCallbacks = [];
    await iap.init(onProChanged: proCallbacks.add);
    ready = true;
  }

  tearDown(() async {
    if (!ready) return;
    ready = false;
    iap.dispose();
    await gateway.dispose();
  });

  test('katalog: mağazadan localized fiyat (hardcode yok)', () async {
    await setup(product: FakeBillingGateway.sampleProduct(price: '₺212,99'));
    expect(AppConstants.iapProductId, 'kira_pro_lifetime');
    expect(iap.state.hasStorePrice, isTrue);
    expect(iap.priceForUi, '₺212,99');
    expect(iap.priceForUi.contains('199'), isFalse);
    expect(gateway.queryCalls, greaterThanOrEqualTo(1));
    expect(gateway.restoreCalls, 1);
  });

  test('mağaza yok → fiyat fallback, Pro yerel kalır', () async {
    await setup(
      available: false,
      prefs: {'is_pro_lifetime': true},
      catalogHasProduct: false,
    );

    expect(proRepo.isPro, isTrue);
    expect(iap.state.storeAvailable, isFalse);
    expect(iap.priceForUi, 'Tek seferlik satın alma');
    expect(gateway.restoreCalls, 0);
  });

  test(
    'ürün yok → Fiyat alınamadı, productMissing, sessiz Pro unlock yok',
    () async {
      await setup(catalogHasProduct: false);
      expect(iap.state.loading, isFalse);
      expect(iap.state.priceUnavailable, isTrue);
      expect(iap.priceForUi, 'Tek seferlik satın alma');
      final outcome = await iap.buy();
      expect(outcome.result, BuyLaunchResult.productMissing);
      expect(proRepo.isPro, isFalse);
    },
  );

  test(
    'Android GooglePlayProductDetails benzeri liste → fiyat yüklenir, tip exception yok',
    () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      proRepo = ProRepository(sp);
      gateway = FakeBillingGateway(
        product: FakeBillingGateway.sampleAndroidProduct(price: '₺249,99'),
        useAndroidSubtypeList: true,
      );
      iap = IapService(proRepo, gateway: gateway);
      proCallbacks = [];
      await iap.init(onProChanged: proCallbacks.add);
      ready = true;

      expect(iap.state.loading, isFalse);
      expect(iap.state.hasStorePrice, isTrue);
      expect(iap.priceForUi, '₺249,99');
      expect(iap.product, isA<FakeAndroidProductDetails>());
      expect(iap.state.lastMessage, isNull);
    },
  );

  test('query exception → loading false, Fiyat alınamadı, crash yok', () async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    proRepo = ProRepository(sp);
    gateway = FakeBillingGateway(
      product: FakeBillingGateway.sampleProduct(),
      queryThrows: StateError(
        "type '() => ProductDetails' is not a subtype of type "
        "'(() => GooglePlayProductDetails)?' of 'orElse'",
      ),
    );
    iap = IapService(proRepo, gateway: gateway);
    await iap.init(onProChanged: (_) {});
    ready = true;

    expect(iap.state.loading, isFalse);
    expect(iap.priceForUi, 'Tek seferlik satın alma');
    expect(iap.state.priceUnavailable, isTrue);

    await iap.refreshCatalog();
    expect(iap.state.loading, isFalse);
  });

  test('purchased → Pro kalıcı + completePurchase', () async {
    await setup();
    expect(proRepo.isPro, isFalse);

    final outcome = await iap.buy();
    expect(outcome.result, BuyLaunchResult.launched);
    expect(gateway.buyCalls, 1);

    gateway.emit([
      FakeBillingGateway.purchase(status: PurchaseStatus.purchased),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(proRepo.isPro, isTrue);
    expect(proCallbacks, contains(true));
    expect(gateway.completed, isNotEmpty);
    expect(iap.state.lastMessage, 'Pro aktif.');
    expect(ProRepository(await SharedPreferences.getInstance()).isPro, isTrue);
  });

  test('pending → Pro unlock yok, mesaj bekliyor', () async {
    await setup();
    gateway.emit([FakeBillingGateway.purchase(status: PurchaseStatus.pending)]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(proRepo.isPro, isFalse);
    expect(iap.state.purchasePending, isTrue);
    expect(iap.state.lastMessage, contains('onay bekliyor'));
  });

  test('canceled → Pro unlock yok', () async {
    await setup();
    gateway.emit([
      FakeBillingGateway.purchase(status: PurchaseStatus.canceled),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(proRepo.isPro, isFalse);
    expect(iap.state.lastMessage, contains('iptal'));
  });

  test('already-owned error → completePurchase; grant yalnız restore/purchased ile', () async {
    await setup();

    gateway.emit([
      FakeBillingGateway.purchase(
        status: PurchaseStatus.error,
        productId: AppConstants.iapProductId,
        error: IAPError(
          source: 'google_play',
          code: 'purchase_error',
          message: 'BillingResponse.itemAlreadyOwned',
        ),
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    // Hata metninden sessiz Pro yok; acknowledgment yine yapılır.
    expect(proRepo.isPro, isFalse);
    expect(gateway.completed, isNotEmpty);
    expect(iap.state.lastMessage, contains('Geri yükle'));

    gateway.restoreEmits = [
      FakeBillingGateway.purchase(status: PurchaseStatus.restored),
    ];
    final sync = await iap.restore();
    expect(sync, OwnershipSyncResult.owned);
    expect(proRepo.isPro, isTrue);
  });

  test('restore/reinstall: restored → Pro', () async {
    await setup(prefs: {}, restoreEmits: const []);
    expect(proRepo.isPro, isFalse);

    gateway.restoreEmits = [
      FakeBillingGateway.purchase(status: PurchaseStatus.restored),
    ];
    final result = await iap.restore();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(result, OwnershipSyncResult.owned);
    expect(proRepo.isPro, isTrue);
  });

  test('mağaza başarılı + owned değil → yerel Pro revoke (refund)', () async {
    await setup(
      prefs: {'is_pro_lifetime': true},
      restoreEmits: const [], // başarılı boş restore
    );
    expect(proRepo.isPro, isFalse);
    expect(proCallbacks, contains(false));
  });

  test('restore throws → yerel Pro korunur', () async {
    await setup(
      prefs: {'is_pro_lifetime': true},
      restoreThrows: Exception('network'),
    );
    expect(proRepo.isPro, isTrue);
    expect(gateway.restoreCalls, 1);
  });

  test('restore timeout → yerel Pro korunur', () async {
    await setup(
      prefs: {'is_pro_lifetime': true},
      autoEmitOnRestore: false,
      ownershipSyncTimeout: const Duration(milliseconds: 80),
    );
    expect(proRepo.isPro, isTrue);
  });

  test('priceForUi loading / fallback metinleri hardcode ₺199 değil', () {
    const loading = IapCatalogState();
    expect(loading.priceForUi, 'Fiyat yükleniyor…');
    const noStore = IapCatalogState(loading: false, storeAvailable: false);
    expect(noStore.priceForUi, 'Tek seferlik satın alma');
    const storeNoPrice = IapCatalogState(loading: false, storeAvailable: true);
    expect(storeNoPrice.priceForUi, 'Tek seferlik satın alma');
    expect(storeNoPrice.priceUnavailable, isTrue);
    const priced = IapCatalogState(
      loading: false,
      storeAvailable: true,
      localizedPrice: 'R\$ 29,90',
      currencyCode: 'BRL',
    );
    expect(priced.priceForUi, 'R\$ 29,90');
  });
}
