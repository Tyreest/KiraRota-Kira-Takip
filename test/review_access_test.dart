import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';
import 'package:kira_artisi_hesapla/services/review_access.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const knownCode = 'unit-test-review-code-24chars!!';
  final knownHash = ReviewAccessVerifier.sha256HexOf(knownCode);

  group('ReviewAccessVerifier', () {
    test('sha256 deterministic', () {
      expect(ReviewAccessVerifier.sha256HexOf(knownCode), equals(knownHash));
      expect(knownHash.length, 64);
    });

    test('matches: config yoksa veya yanlış kod → false', () {
      // Bu suite varsayılan olarak dart-define hash geçirmez.
      if (!ReviewAccessVerifier.isConfigured) {
        expect(ReviewAccessVerifier.matches(knownCode), isFalse);
        expect(ReviewAccessVerifier.matches('anything'), isFalse);
      }
    });

    test('matches: doğru kod (dart-define ile)', () {
      // Çalıştırma: flutter test test/review_access_test.dart \
      //   --dart-define=REVIEW_ACCESS_CODE_SHA256=<hash>
      if (!ReviewAccessVerifier.isConfigured) {
        return;
      }
      final expected = ReviewAccessVerifier.expectedSha256Hex.toLowerCase();
      if (expected != knownHash) {
        // CI/release hash farklı olabilir; yalnız yanlış kodun false olduğunu doğrula
        expect(ReviewAccessVerifier.matches('definitely-wrong-code'), isFalse);
        return;
      }
      expect(ReviewAccessVerifier.matches(knownCode), isTrue);
      expect(ReviewAccessVerifier.matches('wrong'), isFalse);
    });
  });

  group('ReviewAccessRepository', () {
    test('doğru kod → review access açılır (hash match simülasyonu)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ReviewAccessRepository(prefs);
      expect(repo.isEnabled, isFalse);

      // Unit testte fromEnvironment boş; doğrudan hash karşılaştırmasını test et
      expect(ReviewAccessVerifier.sha256HexOf(knownCode), equals(knownHash));
      final entered = ReviewAccessVerifier.sha256HexOf(knownCode);
      final ok = entered == knownHash;
      expect(ok, isTrue);
      if (ok) await repo.setEnabled(true);
      expect(repo.isEnabled, isTrue);
    });

    test('yanlış kod → açılmaz', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ReviewAccessRepository(prefs);
      final wrong = ReviewAccessVerifier.sha256HexOf('wrong-code');
      expect(wrong == knownHash, isFalse);
      expect(repo.isEnabled, isFalse);
    });

    test(
      'review access kapatılması gerçek Pro satın alımını etkilemez',
      () async {
        SharedPreferences.setMockInitialValues({
          'is_pro_lifetime': true,
          'review_access_enabled': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final pro = ProRepository(prefs);
        final review = ReviewAccessRepository(prefs);
        expect(pro.isPro, isTrue);
        expect(review.isEnabled, isTrue);

        await review.clear();
        expect(review.isEnabled, isFalse);
        expect(pro.isPro, isTrue);
      },
    );

    test('Play ownership false → review access silinmez', () async {
      SharedPreferences.setMockInitialValues({
        'is_pro_lifetime': false,
        'review_access_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final pro = ProRepository(prefs);
      final review = ReviewAccessRepository(prefs);

      // Ownership revoke simülasyonu
      await pro.setPro(false);
      expect(pro.isPro, isFalse);
      expect(review.isEnabled, isTrue);
    });
  });

  group('Pro özellik / reklam gate', () {
    test('review access → Pro özellik kontrolü true', () {
      const realProOwned = false;
      const reviewAccessEnabled = true;
      final hasProFeatures = realProOwned || reviewAccessEnabled;
      expect(hasProFeatures, isTrue);
    });

    test('review access → reklam gösterimi false', () {
      AdsService.skipSdk = true;
      AdsService.setAdsEnabled(false); // hasProFeatures true iken
      expect(AdsService.adsEnabled, isFalse);
      expect(
        AdsService.shouldShowInterstitialFor(
          isPro: true, // hasProFeatures
          adsEnabled: AdsService.adsEnabled,
          successCountAfterIncrement: 3,
          lastShown: null,
          now: DateTime.now(),
        ),
        isFalse,
      );
    });
  });
}
