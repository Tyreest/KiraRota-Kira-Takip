import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';

void main() {
  setUp(() {
    AdsService.resetConsentAndInitStateForTest();
    AdsService.skipSdk = true;
  });

  test('Pro disable invalidates pending interstitial generation', () {
    final before = AdsService.requestGeneration;
    AdsService.setAdsEnabled(false);
    expect(AdsService.requestGeneration, greaterThan(before));
  });

  test('consent change bumps eligibility epoch for banner retry', () {
    final before = AdsService.eligibilityEpoch.value;
    AdsService.applyConsentCanRequestAds(true);
    expect(AdsService.eligibilityEpoch.value, greaterThan(before));
    expect(AdsService.consentAllowsAds, isTrue);
    expect(AdsService.mayRequestAds, isTrue);
  });

  test('InterstitialPresentationGate settles once on show', () {
    final gate = AdsService.createPresentationGate(
      loadShowTimeout: const Duration(milliseconds: 50),
    );
    expect(gate.markShowed(), isTrue);
    expect(gate.isCompleted, isTrue);
    expect(gate.didShow, isTrue);
    // İkinci çağrı settle sonrası _showed döner; gate tek complete.
    expect(gate.markShowed(), isTrue);
    gate.markFailedToShow();
    expect(gate.didShow, isTrue);
  });
}
