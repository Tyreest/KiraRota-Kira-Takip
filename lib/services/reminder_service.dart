import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _ready = true;
  }

  Future<void> schedule(ReminderConfig config) async {
    await init();
    await cancelAll();
    await config.save(_prefs);

    if (!enableNotifications) return;

    final renewal = DateTime(
      config.renewalDate.year,
      config.renewalDate.month,
      config.renewalDate.day,
      9,
    );

    if (config.notify30) {
      await _scheduleOne(
        id: 301,
        when: renewal.subtract(const Duration(days: 30)),
        title: 'Kira yenilemesine 30 gün',
        body: 'Yenileme tarihi yaklaşıyor. TÜFE esaslı azami oranı kontrol edin.',
      );
    }
    if (config.notify7) {
      await _scheduleOne(
        id: 307,
        when: renewal.subtract(const Duration(days: 7)),
        title: 'Kira yenilemesine 7 gün',
        body: 'Bir hafta kaldı. Kira Artışı Hesapla ile oranınızı gözden geçirin.',
      );
    }
    if (config.notify0) {
      await _scheduleOne(
        id: 300,
        when: renewal,
        title: 'Kira yenileme günü',
        body: 'Bugün yenileme döneminiz. Azami artış oranını hesaplayabilirsiniz.',
      );
    }
  }

  Future<void> cancelAll() async {
    await init();
    if (!enableNotifications) return;
    await _plugin.cancel(id: 301);
    await _plugin.cancel(id: 307);
    await _plugin.cancel(id: 300);
  }

  Future<void> clearSaved() async {
    await cancelAll();
    await ReminderConfig.clear(_prefs);
  }

  ReminderConfig? get saved => ReminderConfig.load(_prefs);

  Future<void> _scheduleOne({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!when.isAfter(DateTime.now())) return;

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
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
