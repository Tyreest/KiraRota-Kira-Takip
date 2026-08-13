import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Rental _rental(String id, {String name = 'Evim'}) {
  final now = DateTime(2026, 1, 1);
  return Rental(
    id: id,
    role: RentalRole.tenant,
    displayName: name,
    currentRent: 25000,
    contractStartDate: DateTime(2024, 1, 1),
    increaseDate: DateTime(2026, 8, 8),
    createdAt: now,
    updatedAt: now,
  );
}

CalculationResult _result({double oldRent = 25000, double newRent = 33060}) {
  return CalculationResult(
    input: CalculationInput(
      currentRent: oldRent,
      renewalYear: 2026,
      renewalMonth: 8,
      renewalDay: 8,
      contractStart: DateTime(2024, 1, 1),
      contractIncreasePercent: 25,
    ),
    tufeMaxRatePercent: 32.24,
    applicableRatePercent: 25,
    calculatedRent: newRent,
    increaseAmount: newRent - oldRent,
    contractCompare: ContractCompareKind.contractLower,
    isFiveYearsOrMore: false,
    tuikReleaseDate: DateTime(2026, 8, 3),
    datasetUpdatedAt: DateTime(2026, 8, 3),
    rateSourceLabel: 'test',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kira oluştur / düzenle / sil + persistence', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = RentalRepository(prefs);

    final created = _rental('1');
    expect(await repo.add(created, isPro: true), isTrue);
    expect(repo.loadAll().length, 1);

    await repo.update(created.copyWith(displayName: 'Kadıköy Daire'));
    expect(repo.findById('1')!.displayName, 'Kadıköy Daire');
    expect(repo.findById('1')!.role, RentalRole.tenant);

    await repo.update(
      created.copyWith(role: RentalRole.landlord, displayName: 'Dükkan'),
    );
    expect(repo.findById('1')!.role, RentalRole.landlord);

    await repo.delete('1');
    expect(repo.loadAll(), isEmpty);

    // Yeniden yaz → restart benzeri
    await repo.add(_rental('2', name: '2. Daire'), isPro: true);
    final again = RentalRepository(prefs).loadAll();
    expect(again.length, 1);
    expect(again.first.displayName, '2. Daire');
  });

  test('free 1 kira limiti; Pro sınırsız', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = RentalRepository(prefs);

    expect(await repo.add(_rental('a'), isPro: false), isTrue);
    expect(await repo.add(_rental('b'), isPro: false), isFalse);
    expect(repo.loadAll().length, AppConstants.freeRentalLimit);

    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    final pro = RentalRepository(prefs2);
    for (var i = 0; i < 5; i++) {
      expect(await pro.add(_rental('$i'), isPro: true), isTrue);
    }
    expect(pro.loadAll().length, 5);
  });

  test(
    'hesaplama kaydı olmadan currentRent değişmez; kayıttan sonra snapshot',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RentalRepository(prefs);
      await repo.add(_rental('r1'), isPro: true);
      final before = repo.findById('r1')!;
      expect(before.currentRent, 25000);
      expect(before.history, isEmpty);

      // Hesap yapıldı ama apply edilmedi → repo aynı
      expect(repo.findById('r1')!.currentRent, 25000);

      final updated = await repo.applyCalculation(
        rentalId: 'r1',
        result: _result(),
        isPro: true,
      );
      expect(updated, isNotNull);
      expect(updated!.currentRent, 33060);
      expect(updated.history.length, 1);
      expect(updated.history.first.oldRent, 25000);
      expect(updated.history.first.calculatedRent, 33060);
      expect(updated.increaseDate, DateTime(2027, 8, 8));

      // Snapshot immutable — currentRent tekrar değişse bile history aynı kalır
      await repo.update(updated.copyWith(currentRent: 40000));
      final hist = repo.findById('r1')!.history.first;
      expect(hist.oldRent, 25000);
      expect(hist.calculatedRent, 33060);
    },
  );

  test('free history 5; Pro unlimited history', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = RentalRepository(prefs);
    await repo.add(_rental('h'), isPro: false);

    for (var i = 0; i < 6; i++) {
      await repo.applyCalculation(
        rentalId: 'h',
        result: _result(
          oldRent: 10000 + i.toDouble(),
          newRent: 11000 + i.toDouble(),
        ),
        isPro: false,
      );
    }
    expect(repo.findById('h')!.history.length, AppConstants.freeHistoryLimit);

    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    final pro = RentalRepository(prefs2);
    await pro.add(_rental('p'), isPro: true);
    for (var i = 0; i < 8; i++) {
      await pro.applyCalculation(
        rentalId: 'p',
        result: _result(oldRent: 1000.0 * i, newRent: 1100.0 * i),
        isPro: true,
      );
    }
    expect(pro.findById('p')!.history.length, 8);
  });

  test('bildirim ID’leri kiralar arasında çakışmaz', () {
    final a = RentalNotificationIds.forRental('rental-aaa');
    final b = RentalNotificationIds.forRental('rental-bbb');
    expect(a.day0, isNot(b.day0));
    expect(a.day7, isNot(b.day7));
    expect(a.day30, isNot(b.day30));
    expect({a.day0, a.day7, a.day30}.length, 3);
    expect({...a.all, ...b.all}.length, 6);
  });

  test('createFromCalculation free limit', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = RentalRepository(prefs);
    final first = await repo.createFromCalculation(
      displayName: 'Evim',
      role: RentalRole.tenant,
      result: _result(),
      isPro: false,
    );
    expect(first, isNotNull);
    expect(first!.currentRent, 25000);
    expect(first.history.length, 1);

    final second = await repo.createFromCalculation(
      displayName: 'Dükkan',
      role: RentalRole.landlord,
      result: _result(),
      isPro: false,
    );
    expect(second, isNull);
  });

  test('onboarding bayrağı', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = ProRepository(prefs);
    expect(repo.onboardingDone, isFalse);
    await repo.setOnboardingDone();
    expect(repo.onboardingDone, isTrue);
  });

  test('nextIncreaseAnniversary leap-safe', () {
    expect(
      nextIncreaseAnniversary(DateTime(2024, 2, 29)),
      DateTime(2025, 2, 28),
    );
    expect(nextIncreaseAnniversary(DateTime(2026, 8, 8)), DateTime(2027, 8, 8));
  });
}
