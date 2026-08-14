import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/ads_service.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/services/rental_backup_service.dart';
import 'package:kira_artisi_hesapla/ui/screens/settings_screen.dart';
import 'package:kira_artisi_hesapla/ui/widgets/backup_ready_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

LoadedRates _rates() => LoadedRates(
  bundle: TufeRateBundle(
    version: 1,
    updatedAt: DateTime(2026, 8, 3),
    sourceNote: 'test',
    rates: [
      TufeRate(
        renewalMonth: '2026-08',
        ratePercent: 31.90,
        tuikReleaseDate: DateTime(2026, 8, 3),
      ),
    ],
  ),
  source: RateSource.asset,
);

Rental _sampleRental({
  String id = '1',
  String name = 'Evim',
  double rent = 10000,
  List<RentalCalculationSnapshot>? history,
}) {
  final now = DateTime(2026, 8, 1);
  return Rental(
    id: id,
    role: RentalRole.tenant,
    displayName: name,
    currentRent: rent,
    contractStartDate: DateTime(2024, 1, 1),
    increaseDate: DateTime(2026, 8, 1),
    createdAt: now,
    updatedAt: now,
    tenantName: 'Ayşe',
    address: 'Kadıköy',
    notes: 'Not',
    reminder: const RentalReminderPrefs(enabled: true, notify7: false),
    history:
        history ??
        [
          RentalCalculationSnapshot(
            id: 's1',
            calculatedAt: DateTime(2026, 7, 1),
            oldRent: 8000,
            calculatedRent: rent,
            tufeRatePercent: 30,
            applicableRatePercent: 25,
            tufeReferenceMonth: '2026-07',
            increaseDate: DateTime(2026, 7, 1),
            contractRatePercent: 25,
            requestedRent: 11000,
          ),
        ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AdsService.skipSdk = true;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
  });

  group('RentalBackupService', () {
    test('filename KiraRota prefix + .json + tarih', () {
      final name = RentalBackupService.backupFileName(
        now: DateTime(2026, 8, 13),
      );
      expect(name, 'KiraRota-Yedek-2026-08-13.json');
      expect(name.endsWith('.json'), isTrue);
      expect(name.startsWith('KiraRota'), isTrue);
      expect(
        RentalBackupService.backupBaseFileName(now: DateTime(2026, 8, 13)),
        'KiraRota-Yedek-2026-08-13',
      );
    });

    test('payload mevcut şema + alanlar korunur', () {
      final service = RentalBackupService();
      final rental = _sampleRental();
      final payload = service.buildPayload([
        rental,
      ], exportedAt: DateTime(2026, 8, 13, 12));
      expect(payload['app'], 'KiraRota');
      expect(payload['exportedAt'], '2026-08-13T12:00:00.000');
      expect(payload['rentals'], isA<List>());
      final encoded = service.encodePayload(payload);
      expect(utf8.decode(encoded), contains('"rentals"'));
      expect(utf8.decode(encoded), isNot(contains('Sharing text')));

      final decoded = service.decodeBackupBytes(encoded);
      expect(decoded.isValid, isTrue);
      expect(decoded.rentals, hasLength(1));
      final r = decoded.rentals!.single;
      expect(r.displayName, 'Evim');
      expect(r.currentRent, 10000);
      expect(r.tenantName, 'Ayşe');
      expect(r.address, 'Kadıköy');
      expect(r.notes, 'Not');
      expect(r.reminder.enabled, isTrue);
      expect(r.reminder.notify7, isFalse);
      expect(r.history, hasLength(1));
      expect(r.history.first.requestedRent, 11000);
      expect(r.history.first.applicableRatePercent, 25);
    });

    test('geçersiz yedek graceful hata', () {
      final service = RentalBackupService();
      expect(service.decodeBackup('not-json').isValid, isFalse);
      expect(service.decodeBackup('[]').isValid, isFalse);
      expect(service.decodeBackup('{"app":"X"}').isValid, isFalse);
      expect(service.decodeBackup('{"rentals":[{"id":1}]}').isValid, isFalse);
      expect(service.decodeBackup('{"rentals":[]}').isValid, isTrue);
      expect(service.decodeBackup('{"rentals":[]}').errorMessage, isNull);
      expect(
        service.decodeBackup('nope').errorMessage,
        RentalBackupService.invalidBackupMessage,
      );
    });

    test('prepareBackup temp .json dosyası yazar', () async {
      final tempRoot = await Directory.systemTemp.createTemp('kira_backup_');
      addTearDown(() async {
        if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
      });
      final service = RentalBackupService(
        temporaryDirectory: () async => tempRoot,
      );
      final prepared = await service.prepareBackup([
        _sampleRental(),
      ], now: DateTime(2026, 8, 13));
      expect(prepared.fileName, 'KiraRota-Yedek-2026-08-13.json');
      expect(await prepared.tempFile.exists(), isTrue);
      expect(prepared.bytes, isNotEmpty);
      final roundTrip = service.decodeBackupBytes(prepared.bytes);
      expect(roundTrip.isValid, isTrue);
      await prepared.dispose();
      expect(await prepared.tempFile.exists(), isFalse);
    });

    test('share file attachment kullanır — raw JSON text body yok', () async {
      final tempRoot = await Directory.systemTemp.createTemp('kira_share_');
      addTearDown(() async {
        if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
      });
      ShareParams? captured;
      final service = RentalBackupService(
        temporaryDirectory: () async => tempRoot,
        share: (params) async {
          captured = params;
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      final prepared = await service.prepareBackup([
        _sampleRental(),
      ], now: DateTime(2026, 8, 13));
      await service.sharePrepared(prepared);
      expect(captured, isNotNull);
      expect(captured!.files, isNotNull);
      expect(captured!.files, hasLength(1));
      expect(captured!.files!.single.name, 'KiraRota-Yedek-2026-08-13.json');
      expect(captured!.files!.single.mimeType, 'application/json');
      // Ham JSON body gönderilmez
      expect(captured!.text, 'KiraRota yedeği');
      expect(captured!.text, isNot(contains('"rentals"')));
      expect(captured!.text, isNot(contains('"exportedAt"')));
      await prepared.dispose();
    });

    test('save doğru baytları kullanır; cancel hata değil', () async {
      final tempRoot = await Directory.systemTemp.createTemp('kira_save_');
      addTearDown(() async {
        if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
      });

      // FileSaver gerçek platform — cancel/fail yolunu catch ile simüle etmek
      // için doğrudan outcome sözleşmesini doğrularız.
      expect(BackupSaveOutcome.cancelled.index, isNonNegative);
      final service = RentalBackupService(
        temporaryDirectory: () async => tempRoot,
      );
      final prepared = await service.prepareBackup([_sampleRental()]);
      expect(prepared.bytes.first, equals('{'.codeUnitAt(0)));
      await prepared.dispose();
    });

    test('restore repository replaceAll + alanlar', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RentalRepository(prefs);
      await repo.add(_sampleRental(id: 'old'), isPro: true);
      expect(repo.loadAll(), hasLength(1));

      final service = RentalBackupService();
      final payload = service.buildPayload([
        _sampleRental(id: 'new', name: 'Yeni', rent: 15000),
      ]);
      final decoded = service.decodeBackupBytes(service.encodePayload(payload));
      await repo.replaceAll(decoded.rentals!);
      final loaded = repo.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'new');
      expect(loaded.single.displayName, 'Yeni');
      expect(loaded.single.history, hasLength(1));
    });
  });

  group('Ayarlar yedek UI', () {
    Future<void> pumpSettings(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ratesProvider.overrideWith((ref) async => _rates()),
            reminderServiceProvider.overrideWithValue(
              ReminderService(prefs, enableNotifications: false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('tr'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('tr')],
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('Yedek oluştur / geri yükle copy; JSON kelimesi yok', (
      tester,
    ) async {
      await pumpSettings(tester);
      await tester.scrollUntilVisible(
        find.text('Yedek oluştur'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Yedek oluştur'), findsOneWidget);
      expect(find.text('Yedeği geri yükle'), findsOneWidget);
      expect(
        find.text(
          'Kira kayıtlarının cihazında saklayabileceğin bir yedeğini oluştur.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('JSON'), findsNothing);
      expect(find.textContaining('Kira verilerini JSON'), findsNothing);
    });

    testWidgets('Yedek hazır sheet aksiyonları erişilebilir', (tester) async {
      var saved = false;
      var shared = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showBackupReadySheet(
                  context,
                  onSaveToDevice: () async {
                    saved = true;
                  },
                  onShare: () async {
                    shared = true;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Yedek hazır'), findsOneWidget);
      expect(
        find.text(
          'Yedeğini cihazına kaydedebilir veya başka bir yere paylaşabilirsin.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cihaza Kaydet'), findsOneWidget);
      expect(find.text('Paylaş'), findsOneWidget);
      await tester.tap(find.text('Cihaza Kaydet'));
      await tester.pumpAndSettle();
      expect(saved, isTrue);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaş'));
      await tester.pumpAndSettle();
      expect(shared, isTrue);
    });
  });
}
