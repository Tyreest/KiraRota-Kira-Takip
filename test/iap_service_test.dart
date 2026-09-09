import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';
import 'package:kira_artisi_hesapla/services/iap_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_billing_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const productId = AppConstants.iapProductId;
  const shortTimeout = Duration(milliseconds: 40);

  Future<({IapService iap, ProRepository pro, FakeBillingGateway gw})>
  buildService({
    Map<String, Object> prefs = const {},
    FakeBillingGateway? gateway,
    Duration timeout = shortTimeout,
  }) async {
    SharedPreferences.setMockInitialValues(Map<String, Object>.from(prefs));
    final shared = await SharedPreferences.getInstance();
    final pro = ProRepository(shared);
    final gw =
        gateway ??
        FakeBillingGateway(
          products: [fakeProduct(id: productId)],
          emitOnRestore: const [],
        );
    final iap = IapService(
      pro,
      gateway: gw,
      productId: productId,
      ownershipSyncTimeout: timeout,
    );
    return (iap: iap, pro: pro, gw: gw);
  }

  tearDown(() {
    // SharedPreferences mock her testte yeniden set edilir.
  });

  group('IapService ownership — Owned', () {
    test('gateway owned → Pro aktif + persist + revoke yok', () async {
      final owned = fakePurchase(
        status: PurchaseStatus.restored,
        purchaseId: 'owned-1',
      );
      final built = await buildService(
        gateway: FakeBillingGateway(
          products: [fakeProduct()],
          emitOnRestore: [owned],
        ),
      );
      final proChanges = <bool>[];
      await built.iap.init(onProChanged: proChanges.add);

      expect(built.pro.isPro, isTrue);
      expect(built.pro.purchaseId, 'owned-1');
      expect(proChanges, contains(true));
      expect(proChanges, isNot(contains(false)));
      expect(built.iap.state.storeAvailable, isTrue);
      expect(built.gw.restoreCallCount, greaterThanOrEqualTo(1));

      built.iap.dispose();
      built.gw.dispose();
    });

    test('local Free iken owned restore → Pro grant', () async {
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: FakeBillingGateway(
          products: [fakeProduct()],
          emitOnRestore: [
            fakePurchase(status: PurchaseStatus.restored, purchaseId: 'r-1'),
          ],
        ),
      );
      await built.iap.init(onProChanged: (_) {});
      expect(built.pro.isPro, isTrue);
      expect(built.pro.purchaseId, 'r-1');
      built.iap.dispose();
      built.gw.dispose();
    });
  });

  group('IapService ownership — Not owned', () {
    test('başarılı notOwned + local Pro → revoke / Free', () async {
      final built = await buildService(
        prefs: {'is_pro_lifetime': true, 'pro_purchase_id': 'old'},
        gateway: FakeBillingGateway(
          products: [fakeProduct()],
          emitOnRestore: const [], // başarılı boş restore = notOwned
        ),
      );
      final proChanges = <bool>[];
      await built.iap.init(onProChanged: proChanges.add);

      expect(built.pro.isPro, isFalse);
      expect(built.pro.purchaseId, isNull);
      expect(proChanges, contains(false));
      expect(
        built.iap.state.lastMessage,
        contains('mağazada bulunamadı'),
      );
      built.iap.dispose();
      built.gw.dispose();
    });

    test('notOwned + zaten Free → revoke callback yok, Free kalır', () async {
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: FakeBillingGateway(
          products: [fakeProduct()],
          emitOnRestore: const [],
        ),
      );
      final proChanges = <bool>[];
      await built.iap.init(onProChanged: proChanges.add);
      expect(built.pro.isPro, isFalse);
      expect(proChanges, isEmpty);
      built.iap.dispose();
      built.gw.dispose();
    });
  });

  group('IapService ownership — Timeout', () {
    test('timeout → local Pro korunur, revoke yok', () async {
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: FakeBillingGateway(
          products: [fakeProduct()],
          silenceRestore: true,
        ),
        timeout: shortTimeout,
      );
      final proChanges = <bool>[];
      await built.iap.init(onProChanged: proChanges.add);

      expect(built.pro.isPro, isTrue);
      expect(proChanges, isNot(contains(false)));

      final again = await built.iap.syncOwnershipFromStore();
      expect(again, OwnershipSyncResult.storeFailed);
      expect(built.pro.isPro, isTrue);

      built.iap.dispose();
      built.gw.dispose();
    });
  });

  group('IapService ownership — Exception / failure', () {
    test('restore exception → local Pro korunur', () async {
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: FakeBillingGateway(
          products: [fakeProduct()],
          restoreThrows: true,
        ),
      );
      final proChanges = <bool>[];
      await built.iap.init(onProChanged: proChanges.add);

      expect(built.pro.isPro, isTrue);
      expect(proChanges, isNot(contains(false)));
      expect(built.iap.state.lastMessage, contains('Geri yükleme'));

      built.iap.dispose();
      built.gw.dispose();
    });

    test('purchaseStream error → probe fail → Pro korunur', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      expect(built.pro.isPro, isTrue);

      // Aktif probe sırasında stream hatası → complete edilmez → timeout
      final future = built.iap.syncOwnershipFromStore();
      await Future<void>.delayed(Duration.zero);
      gw.emitError(StateError('stream boom'));
      final result = await future;
      expect(result, OwnershipSyncResult.storeFailed);
      expect(built.pro.isPro, isTrue);

      built.iap.dispose();
      gw.dispose();
    });
  });

  group('IapService restore()', () {
    test('restore → owned → Pro aktif', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true, // init sync timeout / storeFailed
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      expect(built.pro.isPro, isFalse);

      gw.silenceRestore = false;
      gw.emitOnRestore = [
        fakePurchase(status: PurchaseStatus.restored, purchaseId: 'restored-9'),
      ];
      final result = await built.iap.restore();
      expect(result, OwnershipSyncResult.owned);
      expect(built.pro.isPro, isTrue);
      expect(built.iap.state.lastMessage, contains('geri yüklendi'));

      built.iap.dispose();
      gw.dispose();
    });

    test('restore → timeout → local Pro korunur', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      final result = await built.iap.restore();
      expect(result, OwnershipSyncResult.storeFailed);
      expect(built.pro.isPro, isTrue);
      expect(built.iap.state.lastMessage, contains('korundu'));

      built.iap.dispose();
      gw.dispose();
    });

    test('restore → notOwned → Free + mesaj', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        emitOnRestore: [
          fakePurchase(status: PurchaseStatus.restored),
        ],
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
      );
      await built.iap.init(onProChanged: (_) {});
      expect(built.pro.isPro, isTrue);

      gw.emitOnRestore = const [];
      final result = await built.iap.restore();
      expect(result, OwnershipSyncResult.notOwned);
      expect(built.pro.isPro, isFalse);
      expect(built.iap.state.lastMessage, contains('bulunamadı'));

      built.iap.dispose();
      gw.dispose();
    });

    test('restore exception → crash yok, Pro korunur', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        emitOnRestore: [
          fakePurchase(status: PurchaseStatus.restored),
        ],
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
      );
      await built.iap.init(onProChanged: (_) {});
      gw.restoreThrows = true;
      final result = await built.iap.restore();
      expect(result, OwnershipSyncResult.storeFailed);
      expect(built.pro.isPro, isTrue);

      built.iap.dispose();
      gw.dispose();
    });
  });

  group('IapService catalog / availability', () {
    test('product unavailable → crash yok, entitlement değişmez', () async {
      // Ownership sessiz (timeout/storeFailed) — yalnız katalog eksikliğini ölç.
      final gw = FakeBillingGateway(
        products: const [],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});

      expect(built.iap.product, isNull);
      expect(built.iap.state.priceUnavailable, isTrue);
      expect(built.iap.state.lastMessage, contains('Ürün bulunamadı'));
      expect(built.pro.isPro, isTrue);

      built.iap.dispose();
      gw.dispose();
    });

    test('queryProductDetails exception → Pro korunur, fiyat yok', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        queryThrows: true,
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      expect(built.pro.isPro, isTrue);
      expect(built.iap.product, isNull);
      expect(built.iap.state.lastMessage, contains('Fiyat şu anda alınamadı'));
      expect(built.iap.state.storeAvailable, isTrue);

      built.iap.dispose();
      gw.dispose();
    });

    test('billing unavailable → Pro korunur, sync storeFailed', () async {
      final gw = FakeBillingGateway(available: false, products: [fakeProduct()]);
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
      );
      await built.iap.init(onProChanged: (_) {});
      expect(built.pro.isPro, isTrue);
      expect(built.iap.state.storeAvailable, isFalse);
      expect(gw.restoreCallCount, 0);
      expect(gw.purchaseStreamListenCount, 0);

      final sync = await built.iap.syncOwnershipFromStore();
      expect(sync, OwnershipSyncResult.storeFailed);
      expect(built.pro.isPro, isTrue);

      final buy = await built.iap.buy();
      expect(buy.result, BuyLaunchResult.storeUnavailable);

      built.iap.dispose();
      gw.dispose();
    });

    test('buy productMissing → entitlement değişmez', () async {
      final gw = FakeBillingGateway(
        products: const [],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      final outcome = await built.iap.buy();
      expect(outcome.result, BuyLaunchResult.productMissing);
      expect(built.pro.isPro, isFalse);

      built.iap.dispose();
      gw.dispose();
    });
  });

  group('IapService purchase results', () {
    test('successful purchase → Pro grant', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: gw,
        timeout: shortTimeout,
      );
      final proChanges = <bool>[];
      await built.iap.init(onProChanged: proChanges.add);
      expect(built.pro.isPro, isFalse);

      final launch = await built.iap.buy();
      expect(launch.result, BuyLaunchResult.launched);

      gw.emitPurchases([
        fakePurchase(
          status: PurchaseStatus.purchased,
          purchaseId: 'buy-ok',
          pendingComplete: true,
        ),
      ]);
      await pumpEventQueue();

      expect(built.pro.isPro, isTrue);
      expect(built.pro.purchaseId, 'buy-ok');
      expect(proChanges, contains(true));
      expect(gw.completeCallCount, 1);

      built.iap.dispose();
      gw.dispose();
    });

    test('cancelled purchase → Pro verilmez', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      gw.emitPurchases([fakePurchase(status: PurchaseStatus.canceled)]);
      await pumpEventQueue();

      expect(built.pro.isPro, isFalse);
      expect(built.iap.state.lastMessage, contains('iptal'));

      built.iap.dispose();
      gw.dispose();
    });

    test('pending purchase → Pro verilmez, pending flag', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      gw.emitPurchases([fakePurchase(status: PurchaseStatus.pending)]);
      await pumpEventQueue();

      expect(built.pro.isPro, isFalse);
      expect(built.iap.state.purchasePending, isTrue);
      expect(built.iap.state.lastMessage, contains('onay bekliyor'));

      built.iap.dispose();
      gw.dispose();
    });

    test('purchase error → Pro verilmez', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      gw.emitPurchases([
        fakePurchase(
          status: PurchaseStatus.error,
          error: IAPError(
            source: 'test',
            code: 'purchase_error',
            message: 'Kart reddedildi',
          ),
        ),
      ]);
      await pumpEventQueue();

      expect(built.pro.isPro, isFalse);
      expect(built.iap.state.lastMessage, contains('Kart reddedildi'));

      built.iap.dispose();
      gw.dispose();
    });

    test('buy alreadyOwned exception → sync owned → alreadyOwned', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
        buyThrows: Exception('BillingResponse.itemAlreadyOwned'),
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': false},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});

      gw.silenceRestore = false;
      gw.emitOnRestore = [
        fakePurchase(status: PurchaseStatus.restored, purchaseId: 'ao-1'),
      ];
      final outcome = await built.iap.buy();
      expect(outcome.result, BuyLaunchResult.alreadyOwned);
      expect(built.pro.isPro, isTrue);

      built.iap.dispose();
      gw.dispose();
    });
  });

  group('IapService idempotency', () {
    test('init iki kez → tek purchaseStream listen, crash yok', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        emitOnRestore: [
          fakePurchase(status: PurchaseStatus.restored),
        ],
      );
      final built = await buildService(gateway: gw);
      await built.iap.init(onProChanged: (_) {});
      expect(gw.purchaseStreamListenCount, 1);
      expect(built.pro.isPro, isTrue);

      await built.iap.init(onProChanged: (_) {});
      // `_sub ??=` — ikinci init yeni listen açmaz
      expect(gw.purchaseStreamListenCount, 1);
      expect(built.pro.isPro, isTrue);

      built.iap.dispose();
      gw.dispose();
    });

    test('eşzamanlı syncOwnership → tek in-flight future', () async {
      final gw = FakeBillingGateway(
        products: [fakeProduct()],
        silenceRestore: true,
      );
      final built = await buildService(
        prefs: {'is_pro_lifetime': true},
        gateway: gw,
        timeout: shortTimeout,
      );
      await built.iap.init(onProChanged: (_) {});
      final before = gw.restoreCallCount;

      final a = built.iap.syncOwnershipFromStore();
      final b = built.iap.syncOwnershipFromStore();
      expect(identical(a, b), isTrue);
      final ra = await a;
      final rb = await b;
      expect(ra, OwnershipSyncResult.storeFailed);
      expect(rb, OwnershipSyncResult.storeFailed);
      // Tek restore (in-flight dedupe)
      expect(gw.restoreCallCount, before + 1);
      expect(built.pro.isPro, isTrue);

      built.iap.dispose();
      gw.dispose();
    });
  });
}
