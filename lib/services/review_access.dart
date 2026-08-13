import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Google Play inceleme erişimi — Play Billing sahipliğinden ayrıdır.
class ReviewAccessRepository {
  ReviewAccessRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _enabledKey = 'review_access_enabled';

  bool get isEnabled => _prefs.getBool(_enabledKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_enabledKey, value);
  }

  Future<void> clear() => setEnabled(false);
}

/// Review kodu yalnızca SHA-256 hash ile doğrulanır (plaintext dart-define yok).
class ReviewAccessVerifier {
  ReviewAccessVerifier._();

  /// `--dart-define=REVIEW_ACCESS_CODE_SHA256=<hex>`
  static const String expectedSha256Hex = String.fromEnvironment(
    'REVIEW_ACCESS_CODE_SHA256',
    defaultValue: '',
  );

  static bool get isConfigured => expectedSha256Hex.trim().isNotEmpty;

  static String sha256HexOf(String input) {
    final digest = sha256.convert(utf8.encode(input));
    return digest.toString();
  }

  /// Doğru kod + config var → true. Asla kodu loglamaz / fırlatmaz.
  static bool matches(String enteredCode) {
    final expected = expectedSha256Hex.trim().toLowerCase();
    if (expected.isEmpty) return false;
    final trimmed = enteredCode.trim();
    if (trimmed.isEmpty) return false;
    final actual = sha256HexOf(trimmed).toLowerCase();
    if (actual.length != expected.length) return false;
    // Constant-time-ish compare
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }
}
