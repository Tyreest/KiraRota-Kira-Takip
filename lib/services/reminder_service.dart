import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/rental.dart';

/// Eski global hatırlatma (tek kayıt) — geriye dönük temizlik için.
class ReminderConfig {
  const ReminderConfig({
    required this.renewalDate,
    required this.notify30,
    required this.notify7,
    required this.notify0,
  });

  final DateTime renewalDate;
  final bool notify30;
  final bool notify7;
  final bool notify0;

  static ReminderConfig? load(SharedPreferences prefs) {
    final millis = prefs.getInt(_keyDate);
    if (millis == null) return null;
    return ReminderConfig(
      renewalDate: DateTime.fromMillisecondsSinceEpoch(millis),
      notify30: prefs.getBool(_key30) ?? true,
      notify7: prefs.getBool(_key7) ?? true,
      notify0: prefs.getBool(_key0) ?? true,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setInt(_keyDate, renewalDate.millisecondsSinceEpoch);
    await prefs.setBool(_key30, notify30);
    await prefs.setBool(_key7, notify7);
    await prefs.setBool(_key0, notify0);
  }

  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(_keyDate);
    await prefs.remove(_key30);
    await prefs.remove(_key7);
    await prefs.remove(_key0);
  }

  static const _keyDate = 'reminder_renewal_ms';
  static const _key30 = 'reminder_d30';
  static const _key7 = 'reminder_d7';
  static const _key0 = 'reminder_d0';
}

enum NotificationPermissionPhase {
  granted,
  denied,
  permanentlyDenied,
  restricted,
}

/// Kira kaydı başına çakışmayan bildirim ID’leri.
class RentalNotificationIds {
  const RentalNotificationIds({
    required this.day0,
    required this.day7,
    required this.day30,
  });

  final int day0;
  final int day7;
  final int day30;

  List<int> get all => [day0, day7, day30];

  /// [200000, 899990] aralığında, rental başına 10’luk blok.
  factory RentalNotificationIds.forRental(String rentalId) {
    final base = 200000 + (_stableHash(rentalId) % 70000) * 10;
    return RentalNotificationIds(day0: base, day7: base + 1, day30: base + 2);
  }

  static int _stableHash(String input) {
    var hash = 2166136261;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}

class ReminderService {
  ReminderService(this._prefs, {this.enableNotifications = true});

  final SharedPreferences _prefs;
  final bool enableNotifications;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'kira_renewal';
  static const _channelName = 'Kira yenileme hatırlatmaları';

  Future<void> init() async {
    if (_ready) return;
    if (!enableNotifications) {
      _ready = true;
      return;
    }
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _plugin.initialize(settings: init);
    _ready = true;
  }

  Future<NotificationPermissionPhase> permissionPhase() async {
    if (!enableNotifications) return NotificationPermissionPhase.granted;
    final status = await Permission.notification.status;
    if (status.isGranted || status.isLimited) {
      return NotificationPermissionPhase.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return status.isRestricted
          ? NotificationPermissionPhase.restricted
          : NotificationPermissionPhase.permanentlyDenied;
    }
    return NotificationPermissionPhase.denied;
  }

  Future<NotificationPermissionPhase> requestPermission() async {
    if (!enableNotifications) return NotificationPermissionPhase.granted;
    final current = await permissionPhase();
    if (current == NotificationPermissionPhase.granted) return current;
    if (current == NotificationPermissionPhase.permanentlyDenied ||
        current == NotificationPermissionPhase.restricted) {
      return current;
    }
    final result = await Permission.notification.request();
    if (result.isGranted || result.isLimited) {
      return NotificationPermissionPhase.granted;
    }
    if (result.isPermanentlyDenied) {
      return NotificationPermissionPhase.permanentlyDenied;
    }
    return NotificationPermissionPhase.denied;
  }

  Future<bool> openSystemNotificationSettings() => openAppSettings();

  /// Belirli kira için hatırlatmaları planla (önce o kiranın eski alarmlarını iptal eder).
  Future<bool> scheduleForRental(Rental rental) async {
    await init();
    await cancelForRental(rental.id);
    if (!rental.reminder.enabled) return true;
    // Belirsiz legacy / doğrulanmamış geçmiş tarih için alarm kurma.
    if (rental.renewalResolved == false) return false;
    if (!enableNotifications) return true;

    final phase = await permissionPhase();
    if (phase != NotificationPermissionPhase.granted) {
      return false;
    }
    return _scheduleAlarms(rental);
  }

  Future<void> cancelForRental(String rentalId) async {
    await init();
    if (!enableNotifications) return;
    final ids = RentalNotificationIds.forRental(rentalId);
    for (final id in ids.all) {
      await _plugin.cancel(id: id);
    }
  }

  /// Tüm kiraların etkin hatırlatmalarını yeniden planla.
  Future<void> rescheduleAllRentals(List<Rental> rentals) async {
    await init();
    if (!enableNotifications) return;
    final phase = await permissionPhase();
    if (phase != NotificationPermissionPhase.granted) return;

    // Eski global ID’leri temizle.
    await _cancelLegacyGlobalIds();

    for (final rental in rentals) {
      await cancelForRental(rental.id);
      if (!rental.reminder.enabled) continue;
      try {
        await _scheduleAlarms(rental);
      } catch (e) {
        debugPrint('Reminder reschedule skipped for ${rental.id}: $e');
      }
    }
  }

  Future<void> rescheduleSavedIfPossible() async {
    // Rental listesi provider üzerinden main’den çağrılır; burada yalnızca
    // legacy global hatırlatmayı temizleriz.
    await init();
    await _cancelLegacyGlobalIds();
    final legacy = ReminderConfig.load(_prefs);
    if (legacy != null) {
      await ReminderConfig.clear(_prefs);
    }
  }

  /// @deprecated Tek global hatırlatma — test uyumu için korunur.
  Future<bool> schedule(ReminderConfig config) async {
    await init();
    await cancelAll();
    await config.save(_prefs);
    if (!enableNotifications) return true;
    final phase = await permissionPhase();
    if (phase != NotificationPermissionPhase.granted) return false;
    return _scheduleLegacy(config);
  }

  Future<void> cancelAll() async {
    await init();
    if (!enableNotifications) return;
    await _cancelLegacyGlobalIds();
  }

  Future<void> clearSaved() async {
    await cancelAll();
    await ReminderConfig.clear(_prefs);
  }

  ReminderConfig? get saved => ReminderConfig.load(_prefs);

  Future<void> _cancelLegacyGlobalIds() async {
    if (!enableNotifications) return;
    await _plugin.cancel(id: 301);
    await _plugin.cancel(id: 307);
    await _plugin.cancel(id: 300);
  }

  Future<bool> _scheduleAlarms(Rental rental) async {
    // Belirsiz legacy / doğrulanmamış geçmiş tarih için alarm kurma.
    if (rental.renewalResolved == false) return false;

    final ids = RentalNotificationIds.forRental(rental.id);
    final name = rental.displayName;
    final next = rental.nextRenewalDate;
    final prefs = rental.reminder;
    var scheduled = 0;

    try {
      if (prefs.notify30) {
        if (await _scheduleOne(
          id: ids.day30,
          whenLocalDate: DateTime(next.year, next.month, next.day),
          daysBefore: 30,
          title: 'Kira yenilemesine 30 gün',
          body: '"$name" için yenileme yaklaşıyor. TÜFE oranını kontrol edin.',
        )) {
          scheduled++;
        }
      }
      if (prefs.notify7) {
        if (await _scheduleOne(
          id: ids.day7,
          whenLocalDate: DateTime(next.year, next.month, next.day),
          daysBefore: 7,
          title: 'Kira yenilemesine 7 gün',
          body: '"$name" için bir hafta kaldı. Oranınızı gözden geçirin.',
        )) {
          scheduled++;
        }
      }
      if (prefs.notify0) {
        if (await _scheduleOne(
          id: ids.day0,
          whenLocalDate: DateTime(next.year, next.month, next.day),
          daysBefore: 0,
          title: 'Kira yenileme günü',
          body: '"$name" için bugün yenileme dönemi. Azami oranı hesaplayın.',
        )) {
          scheduled++;
        }
      }
      return scheduled > 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _scheduleLegacy(ReminderConfig config) async {
    final day = DateTime(
      config.renewalDate.year,
      config.renewalDate.month,
      config.renewalDate.day,
    );
    var scheduled = 0;
    try {
      if (config.notify30) {
        if (await _scheduleOne(
          id: 301,
          whenLocalDate: day,
          daysBefore: 30,
          title: 'Kira yenilemesine 30 gün',
          body:
              'Yenileme tarihi yaklaşıyor. TÜFE esaslı azami oranı kontrol edin.',
        )) {
          scheduled++;
        }
      }
      if (config.notify7) {
        if (await _scheduleOne(
          id: 307,
          whenLocalDate: day,
          daysBefore: 7,
          title: 'Kira yenilemesine 7 gün',
          body: 'Bir hafta kaldı. KiraRota ile oranınızı gözden geçirin.',
        )) {
          scheduled++;
        }
      }
      if (config.notify0) {
        if (await _scheduleOne(
          id: 300,
          whenLocalDate: day,
          daysBefore: 0,
          title: 'Kira yenileme günü',
          body:
              'Bugün yenileme döneminiz. Azami artış oranını hesaplayabilirsiniz.',
        )) {
          scheduled++;
        }
      }
      return scheduled > 0;
    } catch (_) {
      return false;
    }
  }

  /// Europe/Istanbul’da 09:00; geçmiş tarihleri planlamaz.
  Future<bool> _scheduleOne({
    required int id,
    required DateTime whenLocalDate,
    required int daysBefore,
    required String title,
    required String body,
  }) async {
    final targetDay = whenLocalDate.subtract(Duration(days: daysBefore));
    final scheduledDate = tz.TZDateTime(
      tz.local,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      9,
    );
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduledDate.isAfter(now)) return false;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Kira yenileme tarihleri için hatırlatmalar',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }
}
