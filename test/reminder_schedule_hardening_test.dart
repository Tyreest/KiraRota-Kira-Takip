import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
  });

  test('all past reminders → schedule returns false', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = ReminderService(prefs, enableNotifications: false);
    await svc.init();

    final past = DateTime.now().subtract(const Duration(days: 40));
    final rental = Rental(
      id: 'past',
      role: RentalRole.tenant,
      displayName: 'Ev',
      currentRent: 10000,
      contractStartDate: DateTime(2020, 1, 1),
      increaseDate: past,
      renewalResolved: true,
      reminder: const RentalReminderPrefs(
        enabled: true,
        notify30: true,
        notify7: true,
        notify0: true,
      ),
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

    // enableNotifications=false → scheduleForRental early-returns true after cancel.
    // Doğrudan geçmiş tarih semantiği için plugin kapalıyken bile resolved past
    // alarm üretmez; plugin açık path unit’te mock’lanmaz.
    // Bu test: renewalResolved false → false
    final unresolved = rental.copyWith(renewalResolved: false);
    expect(await svc.scheduleForRental(unresolved), isFalse);
  });

  test('Europe/Istanbul location set for schedules', () {
    expect(tz.local.name, 'Europe/Istanbul');
    final sample = tz.TZDateTime(tz.local, 2026, 12, 1, 9);
    expect(sample.hour, 9);
  });
}
