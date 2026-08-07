import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/constants.dart';
import 'package:kira_artisi_hesapla/data/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

HistoryEntry _entry(String id) {
  return HistoryEntry(
    id: id,
    createdAt: DateTime(2026, 1, 1).add(Duration(hours: int.parse(id))),
    currentRent: 10000.0 + int.parse(id),
    renewalMonthKey: '2026-07',
    applicableRatePercent: 32.03,
    calculatedRent: 13000,
    isFiveYearsOrMore: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('free geçmiş limiti 5; 6. kayıt en eskisini düşürür', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = HistoryRepository(prefs);

    for (var i = 1; i <= 6; i++) {
      await repo.add(_entry('$i'), isPro: false);
    }

    final items = repo.loadAll();
    expect(items.length, AppConstants.freeHistoryLimit);
    expect(items.map((e) => e.id).toList(), ['6', '5', '4', '3', '2']);
    expect(items.any((e) => e.id == '1'), isFalse);
  });

  test('pro geçmiş sınırsız', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = HistoryRepository(prefs);

    for (var i = 1; i <= 8; i++) {
      await repo.add(_entry('$i'), isPro: true);
    }

    expect(repo.loadAll().length, 8);
  });

  test('onboarding bayrağı', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = ProRepository(prefs);
    expect(repo.onboardingDone, isFalse);
    await repo.setOnboardingDone();
    expect(repo.onboardingDone, isTrue);
  });
}
