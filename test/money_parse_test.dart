import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/money.dart';

void main() {
  group('parseMoneyInput', () {
    test('10000', () {
      final r = parseMoneyInput('10000');
      expect(r.isOk, isTrue);
      expect(r.value, 10000);
    });

    test('10000,50', () {
      expect(parseMoneyInput('10000,50').value, 10000.50);
    });

    test('10.000', () {
      expect(parseMoneyInput('10.000').value, 10000);
    });

    test('10.000,50', () {
      expect(parseMoneyInput('10.000,50').value, 10000.50);
    });

    test('10000.50 legacy decimal', () {
      expect(parseMoneyInput('10000.50').value, 10000.50);
    });

    test('10,000.50 US rejected', () {
      final r = parseMoneyInput('10,000.50');
      expect(r.isOk, isFalse);
      expect(r.status, MoneyParseStatus.invalid);
    });

    test('empty', () {
      expect(parseMoneyInput('').status, MoneyParseStatus.empty);
      expect(parseMoneyInput('   ').status, MoneyParseStatus.empty);
    });

    test('only separator', () {
      expect(parseMoneyInput(',').isOk, isFalse);
      expect(parseMoneyInput('.').isOk, isFalse);
    });

    test('negative rejected by default', () {
      expect(parseMoneyInput('-100').isOk, isFalse);
    });

    test('negative allowed', () {
      expect(parseMoneyInput('-100', allowNegative: true).value, -100);
    });
  });

  group('formatMoneyForEdit round-trip', () {
    test('10000.50 → edit → parse preserves', () {
      const model = 10000.50;
      final text = formatMoneyForEdit(model);
      expect(text, '10000,50');
      expect(text.contains('.'), isFalse);
      final parsed = parseMoneyInput(text);
      expect(parsed.value, 10000.50);
    });

    test('integer hydrate', () {
      expect(formatMoneyForEdit(25000), '25000');
      expect(parseMoneyInput(formatMoneyForEdit(25000)).value, 25000);
    });

    test('critical: model 10000.50 without user edit', () {
      // Eski bug: toStringAsFixed → 10000.50 → replaceAll('.') → 1000050
      final text = formatMoneyForEdit(10000.50);
      final again = parseMoneyInput(text).value!;
      expect(again, 10000.50);
      expect(again, isNot(1000050));
    });
  });

  group('roundMoney', () {
    test('2 decimal', () {
      expect(roundMoney(10.005), 10.01);
      expect(roundMoney(10.004), 10.00);
      expect(roundMoney(50122.0), 50122);
    });
  });
}
