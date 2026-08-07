import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/ads_service.dart';
import 'screens/calculate_screen.dart';
import 'screens/history_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/rates_screen.dart';
import 'screens/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final done = ref.read(proRepositoryProvider).onboardingDone;
      setState(() => _showOnboarding = !done);
    });
  }

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

    final isPro = ref.watch(isProProvider);
    final pages = [
      const CalculateScreen(),
      const RatesScreen(),
      HistoryScreen(onNewCalculation: () => setState(() => _index = 0)),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: pages[_index]),
            if (!isPro)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: AdBanner(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
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
            icon: Icon(Icons.history),
            label: 'Geçmiş',
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
