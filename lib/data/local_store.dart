import 'package:shared_preferences/shared_preferences.dart';

class ProRepository {
  ProRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'is_pro_lifetime';
  static const _purchaseIdKey = 'pro_purchase_id';
  static const _onboardingKey = 'onboarding_done';

  /// Lifetime entitlement önbelleği.
  ///
  /// Android Auto Backup bu değeri geri yükleyebilir; bu **satın alma kanıtı
  /// değildir**. Kaynak doğruluk Google Play Billing ownership sync'tir
  /// ([IapService.syncOwnershipFromStore]).
  bool get isPro => _prefs.getBool(_key) ?? false;

  String? get purchaseId => _prefs.getString(_purchaseIdKey);

  /// Lifetime entitlement — yerel önbellek. Backup restore kanıt sayılmaz;
  /// Play Billing ownership doğrular. Offline'da son bilinen değer korunabilir.
  Future<void> setPro(bool value, {String? purchaseId}) async {
    await _prefs.setBool(_key, value);
    if (value) {
      if (purchaseId != null && purchaseId.isNotEmpty) {
        await _prefs.setString(_purchaseIdKey, purchaseId);
      }
    } else {
      await _prefs.remove(_purchaseIdKey);
    }
  }

  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_onboardingKey, true);
}
