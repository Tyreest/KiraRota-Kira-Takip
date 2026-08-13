import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/ads_service.dart';
import 'screens/calculate_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/rates_screen.dart';
import 'screens/rentals_screen.dart';
import 'screens/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool? _showOnboarding;

  /// Banner: Özet / Kiralarım / Hesapla. Oranlar opsiyonel; Ayarlar yok.
  static const _bannerTabs = {0, 1, 2};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final done = ref.read(proRepositoryProvider).onboardingDone;
      setState(() => _showOnboarding = !done);
    });
  }

  void _goCalculate() => setState(() => _index = 2);

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showOnboarding!) {
      return OnboardingScreen(
        onDone: () async {
          await completeOnboarding(ref.read(proRepositoryProvider));
          setState(() => _showOnboarding = false);
        },
      );
    }

    final hasProFeatures = ref.watch(hasProFeaturesProvider);
    AdsService.setAdsEnabled(!hasProFeatures);

    final pages = [
      HomeDashboardScreen(onOpenCalculate: _goCalculate),
      const RentalsScreen(),
      const CalculateScreen(),
      const RatesScreen(),
      const SettingsScreen(),
    ];

    final showBanner = !hasProFeatures && _bannerTabs.contains(_index);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: pages[_index]),
            if (showBanner) ...[
              const Divider(height: 1),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: AdBanner(),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Özet',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_work_outlined),
            selectedIcon: Icon(Icons.home_work),
            label: 'Kiralarım',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Hesapla',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Oranlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
