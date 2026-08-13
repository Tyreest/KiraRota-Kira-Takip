import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/data/rental_repository.dart';
import 'package:kira_artisi_hesapla/domain/models/calculation.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/domain/models/tufe_rate.dart';
import 'package:kira_artisi_hesapla/providers/app_providers.dart';
import 'package:kira_artisi_hesapla/services/pdf_report_service.dart';
import 'package:kira_artisi_hesapla/services/reminder_service.dart';
import 'package:kira_artisi_hesapla/ui/screens/rental_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

RentalCalculationSnapshot _snap({
  required String id,
  required double oldRent,
  required double calculatedRent,
  required String month,
  DateTime? calculatedAt,
  double tufe = 30,
  double applicable = 30,
  double? contract,
}) {
  return RentalCalculationSnapshot(
    id: id,
    calculatedAt: calculatedAt ?? DateTime(2026, 7, 10),
    oldRent: oldRent,
    calculatedRent: calculatedRent,
    tufeRatePercent: tufe,
    applicableRatePercent: applicable,
    tufeReferenceMonth: month,
    increaseDate: DateTime(2026, 7, 15),
    contractRatePercent: contract,
  );
}

class _FakePdf extends PdfReportService {
  int shareCalls = 0;
  CalculationResult? last;

  @override
  Future<void> shareCalculation(
    CalculationResult result, {
    String? rentalName,
  }) async {
    shareCalls++;
    last = result;
  }

  @override
  Future<PdfSaveResult> saveCalculationToDevice(
    CalculationResult result, {
    String? rentalName,
  }) async {
    last = result;
    return const PdfSaveResult(PdfSaveOutcome.saved, path: '/tmp/t.pdf');
  }
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required SharedPreferences prefs,
  required String rentalId,
  _FakePdf? pdf,
  bool ratesMustNotLoad = false,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reminderServiceProvider.overrideWithValue(
          ReminderService(prefs, enableNotifications: false),
        ),
        if (pdf != null) pdfReportServiceProvider.overrideWithValue(pdf),
        ratesProvider.overrideWith((ref) async {
          if (ratesMustNotLoad) {
            fail('PDF snapshot akışı ratesProvider çağırmamalı');
          }
          return LoadedRates(
            bundle: TufeRateBundle(
              version: 1,
              updatedAt: DateTime(2026, 8, 3),
              sourceNote: 'test',
              rates: const [],
            ),
            source: RateSource.asset,
          );
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: RentalDetailScreen(rentalId: rentalId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('tr_TR');
  });

  group('RentalCalculationSnapshot.toPdfCalculationResult', () {
    test('en son snapshot değerlerini kullanır — yeniden hesap yok', () {
      final snap = _snap(
        id: 's1',
        oldRent: 25000,
        calculatedRent: 33000,
        month: '2026-05',
        tufe: 31.9,
        applicable: 25,
        contract: 25,
        calculatedAt: DateTime(2026, 5, 8, 12),
      );
      final pdf = snap.toPdfCalculationResult(
        contractStartDate: DateTime(2020, 5, 1),
      );

      expect(pdf.input.currentRent, 25000);
      expect(pdf.calculatedRent, 33000);
      expect(pdf.increaseAmount, 8000);
      expect(pdf.tufeMaxRatePercent, 31.9);
      expect(pdf.applicableRatePercent, 25);
      expect(pdf.input.contractIncreasePercent, 25);
      expect(pdf.input.renewalMonthKey, '2026-05');
      expect(pdf.tuikReleaseDate, DateTime(2026, 5, 8, 12));
      expect(pdf.datasetUpdatedAt, DateTime(2026, 5, 8, 12));
      expect(pdf.rateSourceLabel, 'Kayıtlı hesaplama');
    });

    test('sözleşme < TÜFE → contractLower (applicable ile karıştırılmaz)', () {
      final snap = _snap(
        id: 's-low',
        oldRent: 10000,
        calculatedRent: 12000,
        month: '2026-08',
        tufe: 31.9,
        applicable: 20,
        contract: 20,
      );
      final pdf = snap.toPdfCalculationResult(
        contractStartDate: DateTime(2024, 8, 1),
      );
      expect(pdf.contractCompare, ContractCompareKind.contractLower);
      expect(pdf.applicableRatePercent, 20);
      expect(pdf.tufeMaxRatePercent, 31.9);
    });

    test('sözleşme > TÜFE → contractHigher', () {
      final snap = _snap(
        id: 's-high',
        oldRent: 10000,
        calculatedRent: 13190,
        month: '2026-08',
        tufe: 31.9,
        applicable: 31.9,
        contract: 40,
      );
      final pdf = snap.toPdfCalculationResult(
        contractStartDate: DateTime(2024, 8, 1),
      );
      expect(pdf.contractCompare, ContractCompareKind.contractHigher);
    });
  });

  group('RentalDetailScreen PDF aksiyonu', () {
    testWidgets('history yoksa PDF tap → snackbar', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'is_pro_lifetime': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 1, 1);
      await RentalRepository(prefs).add(
        Rental(
          id: 'empty',
          role: RentalRole.tenant,
          displayName: 'Evim',
          currentRent: 20000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2027, 1, 1),
          createdAt: now,
          updatedAt: now,
        ),
        isPro: true,
      );

      await _pumpDetail(tester, prefs: prefs, rentalId: 'empty');
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Yeni dönemi hesapla'), findsOneWidget);

      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();
      expect(
        find.text('PDF için önce bir dönem hesaplaması kaydedin'),
        findsOneWidget,
      );
      expect(find.text('Cihaza Kaydet'), findsNothing);
    });

    testWidgets('history varsa PDF görünür', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'is_pro_lifetime': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 1, 1);
      await RentalRepository(prefs).add(
        Rental(
          id: 'with-hist',
          role: RentalRole.tenant,
          displayName: 'Evim',
          currentRent: 33000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2027, 7, 15),
          createdAt: now,
          updatedAt: now,
          history: [
            _snap(
              id: 'h1',
              oldRent: 25000,
              calculatedRent: 33000,
              month: '2026-07',
            ),
          ],
        ),
        isPro: true,
      );

      await _pumpDetail(tester, prefs: prefs, rentalId: 'with-hist');
      expect(find.text('PDF'), findsOneWidget);
    });

    testWidgets('Pro → export sheet; en son snapshot; TÜFE yeniden yüklenmez', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_done': true,
        'is_pro_lifetime': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 1, 1);
      final older = _snap(
        id: 'old',
        oldRent: 20000,
        calculatedRent: 25000,
        month: '2025-07',
        calculatedAt: DateTime(2025, 7, 1),
      );
      final newer = _snap(
        id: 'new',
        oldRent: 25000,
        calculatedRent: 33800,
        month: '2026-07',
        tufe: 35.2,
        applicable: 35.2,
        calculatedAt: DateTime(2026, 7, 10),
      );
      // history.first = latest (repo sort by calculatedAt desc on load)
      await RentalRepository(prefs).add(
        Rental(
          id: 'latest',
          role: RentalRole.tenant,
          displayName: 'Kadıköy',
          currentRent: 33800,
          contractStartDate: DateTime(2021, 7, 15),
          increaseDate: DateTime(2027, 7, 15),
          createdAt: now,
          updatedAt: now,
          history: [newer, older],
        ),
        isPro: true,
      );

      final pdf = _FakePdf();
      await _pumpDetail(
        tester,
        prefs: prefs,
        rentalId: 'latest',
        pdf: pdf,
        ratesMustNotLoad: true,
      );

      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Cihaza Kaydet'), findsOneWidget);
      expect(find.text('Şimdi Al'), findsNothing);

      await tester.tap(find.widgetWithText(ListTile, 'Paylaş'));
      await tester.pumpAndSettle();

      expect(pdf.shareCalls, 1);
      expect(pdf.last, isNotNull);
      expect(pdf.last!.calculatedRent, 33800);
      expect(pdf.last!.input.currentRent, 25000);
      expect(pdf.last!.tufeMaxRatePercent, 35.2);
      expect(pdf.last!.input.renewalMonthKey, '2026-07');
      expect(pdf.last!.rateSourceLabel, 'Kayıtlı hesaplama');
    });

    testWidgets('Free → paywall', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime(2026, 1, 1);
      await RentalRepository(prefs).add(
        Rental(
          id: 'free1',
          role: RentalRole.tenant,
          displayName: 'Evim',
          currentRent: 30000,
          contractStartDate: DateTime(2024, 1, 1),
          increaseDate: DateTime(2027, 1, 1),
          createdAt: now,
          updatedAt: now,
          history: [
            _snap(
              id: 'h',
              oldRent: 25000,
              calculatedRent: 30000,
              month: '2026-06',
            ),
          ],
        ),
        isPro: false,
      );

      await _pumpDetail(tester, prefs: prefs, rentalId: 'free1');
      expect(find.text('PDF'), findsOneWidget);

      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();

      expect(find.text('Şimdi Al'), findsOneWidget);
      expect(find.text('Cihaza Kaydet'), findsNothing);
    });
  });
}
