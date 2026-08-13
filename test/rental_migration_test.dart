import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eski JSON (yeni alanlar yok) yüklenir', () async {
    // propertyName / renewalDate / tenantName / address / notes yok;
    // displayName + increaseDate + history without requestedRent / applicableRatePercent
    final legacy = [
      {
        'id': 'legacy-1',
        'role': 'tenant',
        'displayName': 'Eski Ev',
        'currentRent': 18000,
        'contractStartDate': '2023-06-01T00:00:00.000',
        'increaseDate': '2026-06-01T00:00:00.000',
        'createdAt': '2025-01-01T00:00:00.000',
        'updatedAt': '2025-06-01T00:00:00.000',
        'history': [
          {
            'id': 'h1',
            'calculatedAt': '2025-06-01T12:00:00.000',
            'oldRent': 15000,
            'calculatedRent': 18000,
            'tufeRatePercent': 20.0,
            // applicableRatePercent yok → tufe'ye düşmeli
            'tufeReferenceMonth': '2025-06',
            'increaseDate': '2025-06-01T00:00:00.000',
            // requestedRent / isFiveYearsOrMore yok
          },
        ],
      },
    ];

    SharedPreferences.setMockInitialValues({'rentals_v1': jsonEncode(legacy)});
    final prefs = await SharedPreferences.getInstance();
    final repo = RentalRepository(prefs);
    final all = repo.loadAll();

    expect(all.length, 1);
    final r = all.first;
    expect(r.id, 'legacy-1');
    expect(r.displayName, 'Eski Ev');
    expect(r.propertyName, 'Eski Ev');
    expect(r.currentRent, 18000);
    expect(r.increaseDate, DateTime.parse('2026-06-01T00:00:00.000'));
    expect(r.tenantName, isNull);
    expect(r.address, isNull);
    expect(r.notes, isNull);
    expect(r.reminder.enabled, isFalse);
    expect(r.history.length, 1);

    final snap = r.history.first;
    expect(snap.applicableRatePercent, 20.0);
    expect(snap.requestedRent, isNull);
    expect(snap.isFiveYearsOrMore, isFalse);
  });

  test('propertyName + renewalDate alias okunur', () {
    final r = Rental.fromJson({
      'id': 'alias',
      'role': 'landlord',
      'propertyName': 'Dükkan',
      'currentRent': 5000,
      'contractStartDate': '2024-01-01T00:00:00.000',
      'renewalDate': '2026-03-15T00:00:00.000',
      'createdAt': '2024-01-01T00:00:00.000',
      'updatedAt': '2024-01-01T00:00:00.000',
    });
    expect(r.displayName, 'Dükkan');
    expect(r.role, RentalRole.landlord);
    expect(r.increaseDate.year, 2026);
    expect(r.increaseDate.month, 3);
    expect(r.increaseDate.day, 15);
  });
}
