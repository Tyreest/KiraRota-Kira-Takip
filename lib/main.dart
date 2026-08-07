import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'services/ads_service.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  final prefs = await SharedPreferences.getInstance();

  // Ads init best-effort (test IDs).
  try {
    await AdsService.init();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KiraApp(),
    ),
  );
}

class KiraApp extends ConsumerStatefulWidget {
  const KiraApp({super.key});

  @override
  ConsumerState<KiraApp> createState() => _KiraAppState();
}

class _KiraAppState extends ConsumerState<KiraApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final iap = ref.read(iapServiceProvider);
      await iap.init(
        onProChanged: (isPro) {
          ref.read(isProProvider.notifier).syncFromRepo();
        },
      );
      ref.read(isProProvider.notifier).syncFromRepo();
      await ref.read(reminderServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kira Artışı Hesapla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomeShell(),
    );
  }
}
