/// TR-odaklı para parse / format / yuvarlama — tek merkez.
///
/// Edit alanlarında ondalık ayırıcı olarak **virgül** kullanılır; noktayı
/// ondalık olarak hydrate etmeyiz (eski `toStringAsFixed` → parse bug’ını önler).
library;

/// Kuruş hassasiyeti (2 ondalık).
const int moneyDecimalDigits = 2;

/// Makul üst sınır (₺) — backup / form DoS ve overflow için.
const double moneyMaxAbs = 1e12;

/// Para yuvarlama — CalculationEngine, dashboard, kayıt, PDF aynı politikayı kullanır.
double roundMoney(double value) {
  if (!value.isFinite) return value;
  final scaled = value * 100;
  // half-away-from-zero ile tutarlı olması için roundToDouble
  return scaled.roundToDouble() / 100.0;
}

enum MoneyParseStatus { ok, empty, invalid }

class MoneyParseResult {
  const MoneyParseResult._(this.status, {this.value, this.message});

  const MoneyParseResult.ok(double value)
    : this._(MoneyParseStatus.ok, value: value);

  const MoneyParseResult.empty([String message = 'Tutar gerekli'])
    : this._(MoneyParseStatus.empty, message: message);

  const MoneyParseResult.invalid([
    String message = 'Geçerli bir tutar girin',
  ]) : this._(MoneyParseStatus.invalid, message: message);

  final MoneyParseStatus status;
  final double? value;
  final String? message;

  bool get isOk => status == MoneyParseStatus.ok && value != null;
}

/// Kullanıcı / hydrate metnini güvenli şekilde sayıya çevirir.
///
/// Kabul:
/// - `10000`
/// - `10000,50` / `10.000,50` (TR)
/// - `10000.50` (tek nokta + 1–2 ondalık → ondalık kabul; hydrate legacy)
/// - `10.000` (binlik nokta grupları)
///
/// Red:
/// - `10,000.50` (ABD stili karışık)
/// - boş / yalnız ayırıcı / negatif (varsayılan) / NaN / aşırı büyük
MoneyParseResult parseMoneyInput(
  String raw, {
  bool allowNegative = false,
  double maxAbs = moneyMaxAbs,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const MoneyParseResult.empty();

  // Boşluk / NBSP temizle
  var s = trimmed.replaceAll(RegExp(r'[\s\u00A0]'), '');
  if (s.isEmpty) return const MoneyParseResult.empty();

  var negative = false;
  if (s.startsWith('-') || s.startsWith('+')) {
    negative = s.startsWith('-');
    s = s.substring(1);
    if (!allowNegative && negative) {
      return const MoneyParseResult.invalid('Tutar negatif olamaz');
    }
  }
  if (s.isEmpty || s == ',' || s == '.') {
    return const MoneyParseResult.invalid();
  }

  final dotCount = '.'.allMatches(s).length;
  final commaCount = ','.allMatches(s).length;

  // ABD stili: 10,000.50 → reddet (yanlış TR varsayımı riski)
  if (dotCount > 0 && commaCount > 0) {
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    if (lastDot > lastComma) {
      return const MoneyParseResult.invalid(
        'ABD biçimli tutar desteklenmiyor. Örn: 10.000,50',
      );
    }
    // TR: 10.000,50 — noktaları sil, virgülü noktaya çevir
    final normalized = s.replaceAll('.', '').replaceAll(',', '.');
    return _finishParse(normalized, negative: negative, maxAbs: maxAbs);
  }

  if (commaCount > 0 && dotCount == 0) {
    // 10000,50 veya 10,5
    if (commaCount > 1) {
      return const MoneyParseResult.invalid();
    }
    return _finishParse(
      s.replaceAll(',', '.'),
      negative: negative,
      maxAbs: maxAbs,
    );
  }

  if (dotCount > 0 && commaCount == 0) {
    // Binlik: 10.000 veya 1.234.567
    if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
      return _finishParse(
        s.replaceAll('.', ''),
        negative: negative,
        maxAbs: maxAbs,
      );
    }
    // Ondalık (legacy hydrate / az sayıda ondalık): 10000.50
    if (dotCount == 1 && RegExp(r'^\d+\.\d{1,2}$').hasMatch(s)) {
      return _finishParse(s, negative: negative, maxAbs: maxAbs);
    }
    return const MoneyParseResult.invalid(
      'Tutar anlaşılamadı. Örn: 10000 veya 10.000,50',
    );
  }

  // Salt rakam
  if (!RegExp(r'^\d+$').hasMatch(s)) {
    return const MoneyParseResult.invalid();
  }
  return _finishParse(s, negative: negative, maxAbs: maxAbs);
}

MoneyParseResult _finishParse(
  String normalized, {
  required bool negative,
  required double maxAbs,
}) {
  final v = double.tryParse(normalized);
  if (v == null || !v.isFinite) {
    return const MoneyParseResult.invalid();
  }
  final signed = negative ? -v : v;
  if (signed.abs() > maxAbs) {
    return const MoneyParseResult.invalid('Tutar çok büyük');
  }
  return MoneyParseResult.ok(roundMoney(signed));
}

/// Edit TextField için güvenli metin — ondalıkta virgül; binlik yok.
///
/// Böylece `10000.50` model → `10000,50` metin → parse → `10000.50` round-trip.
String formatMoneyForEdit(double value) {
  if (!value.isFinite) return '';
  final r = roundMoney(value);
  final asInt = r.round();
  if ((r - asInt).abs() < 0.0000001) {
    return asInt.toString();
  }
  return r.toStringAsFixed(moneyDecimalDigits).replaceAll('.', ',');
}
