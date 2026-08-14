import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/screenshot_seed.dart';
import 'providers/app_providers.dart';
import 'services/ads_service.dart';
import 'services/ump_consent_service.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  final prefs = await SharedPreferences.getInstance();
  await applyScreenshotSeedIfNeeded(prefs);

  // Ads init UMP consent sonrasına ertelenir (KiraApp bootstrap).

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const KiraApp(),
    ),
  );
}

class KiraApp extends ConsumerStatefulWidget {
  const KiraApp({super.key});

  @override
  ConsumerState<KiraApp> createState() => _KiraAppState();
}

class _KiraAppState extends ConsumerState<KiraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Backup restore / ayarlardan dönüş sonrası hatırlatmaları yenile.
      ref.read(rentalsProvider.notifier).rescheduleAllReminders();
    }
  }

  Future<void> _bootstrap() async {
    final iap = ref.read(iapServiceProvider);
    await iap.init(
      onProChanged: (isPro) {
        // Yalnızca gerçek Play entitlement — review access silinmez / yazılmaz.
        ref.read(isProProvider.notifier).syncFromRepo();
        final features = ref.read(hasProFeaturesProvider);
        AdsService.setAdsEnabled(!features);
        if (features) AdsService.discardPreloadedInterstitial();
      },
    );
    ref.read(isProProvider.notifier).syncFromRepo();
    ref.read(reviewAccessEnabledProvider.notifier).syncFromRepo();
    final features = ref.read(hasProFeaturesProvider);
    AdsService.setAdsEnabled(!features);

    // UMP: her launch consent update → gerekirse form → canRequestAds ise ads init.
    try {
      final result = await UmpConsentService.gatherConsentThenInitAds();
      if (mounted) {
        ref.read(privacyOptionsRequiredProvider.notifier).state =
            result.privacyOptionsRequired;
      }
    } catch (_) {
      // Consent hatası uygulamayı bloke etmez.
    }

    final reminders = ref.read(reminderServiceProvider);
    // Açılışta permission İSTEMEZ — yalnızca plugin + kayıtlı alarmları yenile.
    await reminders.init();
    await ref.read(rentalRepositoryProvider).migrateRenewalsIfNeeded();
    ref.read(rentalsProvider.notifier).refresh();
    await reminders.rescheduleSavedIfPossible();
    await ref.read(rentalsProvider.notifier).rescheduleAllReminders();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(hasProFeaturesProvider, (prev, next) {
      AdsService.setAdsEnabled(!next);
      if (next) AdsService.discardPreloadedInterstitial();
    });

    return MaterialApp(
      title: 'KiraRota',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}
