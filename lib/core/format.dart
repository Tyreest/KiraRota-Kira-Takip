import 'package:intl/intl.dart';

final _tryCurrency = NumberFormat.currency(
  locale: 'tr_TR',
  symbol: '₺',
  decimalDigits: 2,
);

final _tryPercent = NumberFormat('#,##0.##', 'tr_TR');
final _tryDecimal = NumberFormat('#,##0.#', 'tr_TR');

String formatMoney(double value) => _tryCurrency.format(value);

String formatPercent(double value) => '%${_tryPercent.format(value)}';

/// Örn. `+%31,9` / `-%14,3` / `%0`
String formatSignedPercent(double value) {
  if (value > 0) return '+%${_tryDecimal.format(value)}';
  if (value < 0) return '-%${_tryDecimal.format(value.abs())}';
  return '%${_tryDecimal.format(0)}';
}

String formatDecimal(double value) => _tryDecimal.format(value);

String formatMonthKey(String yyyyMm) {
  final parts = yyyyMm.split('-');
  if (parts.length != 2) return yyyyMm;
  const months = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  final y = parts[0];
  final m = int.tryParse(parts[1]) ?? 0;
  if (m < 1 || m > 12) return yyyyMm;
  return '${months[m]} $y';
}

String formatDateTr(DateTime d) {
  return DateFormat('d MMMM y', 'tr_TR').format(d);
}
