import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/services/rental_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CalculationResult _result({
  double oldRent = 25000,
  double newRent = 33007.5,
  int year = 2026,
  int month = 9,
  int day = 1,
}) {
  return CalculationResult(
    input: CalculationInput(
      currentRent: oldRent,
      renewalYear: year,
      renewalMonth: month,
      renewalDay: day,
      contractStart: DateTime(2024, 9, 1),
    ),
    tufeMaxRatePercent: 31.79,
    applicableRatePercent: 31.79,
    calculatedRent: newRent,
    increaseAmount: newRent - oldRent,
    contractCompare: ContractCompareKind.none,
    isFiveYearsOrMore: false,
    tuikReleaseDate: DateTime(2026, 9, 3),
    datasetUpdatedAt: DateTime(2026, 9, 3),
    rateSourceLabel: 'test',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('createFromCalculation bağlar ama uygulamaz (snapshot yok)', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RentalRepository(await SharedPreferences.getInstance());
    final created = await repo.createFromCalculation(
      displayName: 'Ev',
      role: RentalRole.tenant,
      result: _result(),
      isPro: true,
    );
    expect(created!.currentRent, 25000);
    expect(created.history, isEmpty);
    expect(created.increaseDate, DateTime(2026, 9, 1));
  });

  test('apply uses result renewal date; duplicate blocked', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RentalRepository(await SharedPreferences.getInstance());
    await repo.add(
      Rental(
        id: 'r1',
        role: RentalRole.tenant,
        displayName: 'Ev',
        currentRent: 25000,
        contractStartDate: DateTime(2024, 1, 1),
        // Kayıttaki tarih hesaplanandan farklı olabilir
        increaseDate: DateTime(2026, 8, 1),
        renewalResolved: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      isPro: true,
    );

    final result = _result(day: 15);
    final updated = await repo.applyCalculation(
      rentalId: 'r1',
      result: result,
    );
    expect(updated!.currentRent, 33007.5);
    expect(dateOnly(updated.lastRenewalDate!), DateTime(2026, 9, 15));
    expect(dateOnly(updated.increaseDate), DateTime(2027, 9, 15));

    final again = await repo.applyCalculation(rentalId: 'r1', result: result);
    expect(again!.history.length, 1); // duplicate apply no-op
  });

  test('Pro→Free entitlement history not truncated on apply', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = RentalRepository(await SharedPreferences.getInstance());
    await repo.add(
      Rental(
        id: 'h',
        role: RentalRole.tenant,
        displayName: 'Ev',
        currentRent: 10000,
        contractStartDate: DateTime(2020, 1, 1),
        increaseDate: DateTime(2026, 1, 1),
        renewalResolved: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      isPro: true,
    );

    for (var i = 0; i < 7; i++) {
      await repo.applyCalculation(
        rentalId: 'h',
        result: _result(
          oldRent: 10000 + i * 100,
          newRent: 11000 + i * 100,
          year: 2026,
          month: (i % 12) + 1,
        ),
      );
    }
    expect(repo.findById('h')!.history.length, 7);
    // Free apply sonrası da silinmez
    await repo.applyCalculation(
      rentalId: 'h',
      result: _result(oldRent: 20000, newRent: 25000, year: 2027, month: 2),
    );
    expect(repo.findById('h')!.history.length, 8);
  });

  test('corrupt rental skipped; others load', () async {
    final good = Rental(
      id: 'ok',
      role: RentalRole.tenant,
      displayName: 'Ev',
      currentRent: 10000,
      contractStartDate: DateTime(2024, 1, 1),
      increaseDate: DateTime(2026, 9, 1),
      renewalResolved: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    SharedPreferences.setMockInitialValues({
      RentalRepository.storageKey: jsonEncode([
        good.toJson(),
        {'id': 'bad', 'broken': true},
      ]),
    });
    final repo = RentalRepository(await SharedPreferences.getInstance());
    final loaded = repo.loadAllResilient();
    expect(loaded.rentals.length, 1);
    expect(loaded.rentals.first.id, 'ok');
    expect(loaded.skippedCorruptCount, 1);
  });

  test('backup free limit bypass blocked', () {
    final service = RentalBackupService();
    final payload = {
      'app': AppConstants.appName,
      'exportedAt': DateTime.now().toIso8601String(),
      'rentals': [
        for (var i = 0; i < 3; i++)
          Rental(
            id: 'r$i',
            role: RentalRole.tenant,
            displayName: 'Ev $i',
            currentRent: 10000,
            contractStartDate: DateTime(2024, 1, 1),
            increaseDate: DateTime(2026, 9, 1),
            renewalResolved: true,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ).toJson(),
      ],
    };
    final decoded = service.decodeBackup(
      jsonEncode(payload),
      isPro: false,
    );
    expect(decoded.isValid, isFalse);
    expect(decoded.errorMessage, contains('Ücretsiz'));
  });

  test('backup rejects negative rent', () {
    final service = RentalBackupService();
    expect(
      service
          .decodeBackup(
            jsonEncode({
              'rentals': [
                {
                  'id': 'a',
                  'role': 'tenant',
                  'displayName': 'x',
                  'currentRent': -5,
                  'contractStartDate': '2024-01-01T00:00:00.000',
                  'increaseDate': '2026-09-01T00:00:00.000',
                  'createdAt': '2026-01-01T00:00:00.000',
                  'updatedAt': '2026-01-01T00:00:00.000',
                },
              ],
            }),
            isPro: true,
          )
          .isValid,
      isFalse,
    );
  });

  test('backup rejects duplicate ids', () {
    final service = RentalBackupService();
    Map<String, dynamic> rentalJson(String id) => {
      'id': id,
      'role': 'tenant',
      'displayName': 'x',
      'currentRent': 1000,
      'contractStartDate': '2024-01-01T00:00:00.000',
      'increaseDate': '2026-09-01T00:00:00.000',
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    };
    expect(
      service
          .decodeBackup(
            jsonEncode({
              'rentals': [rentalJson('a'), rentalJson('a')],
            }),
            isPro: true,
          )
          .isValid,
      isFalse,
    );
  });
}
