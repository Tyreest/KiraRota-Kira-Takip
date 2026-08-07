import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../widgets/design_system.dart';
import 'legal_document_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  void _openLegal(BuildContext context, String title, String asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, assetPath: asset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodySmall;
    final linkStyle = bodyStyle?.copyWith(
      color: AppColors.primaryDeep,
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        AppConstants.brandName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppConstants.appName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          color: AppColors.sageSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.show_chart_rounded,
                          size: 56,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _InfoCard(
                        icon: Icons.check_circle_outline,
                        title: 'Ne yapar?',
                        body:
                            'Yenileme döneminiz için TÜFE esaslı azami artış oranını ve bu orana göre hesaplanan kirayı gösterir.',
                      ),
                      const SizedBox(height: 10),
                      const _InfoCard(
                        icon: Icons.info_outline,
                        title: 'Ne değildir?',
                        body:
                            'Bir hukuki tavsiye veya kesin bağlayıcı belge niteliği taşımaz.',
                      ),
                      const SizedBox(height: 10),
                      const _InfoCard(
                        icon: Icons.lock_outline,
                        title: 'Gizlilik',
                        body:
                            'Kira ve hesaplama bilgileriniz cihazınızda saklanır.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onDone,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Başla'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Devam ederek ', style: bodyStyle),
                  GestureDetector(
                    onTap: () => _openLegal(
                      context,
                      'Kullanım Şartları',
                      'assets/legal/kullanim_sartlari.md',
                    ),
                    child: Text('Kullanım Şartları', style: linkStyle),
                  ),
                  Text(' ve ', style: bodyStyle),
                  GestureDetector(
                    onTap: () => _openLegal(
                      context,
                      'Gizlilik Politikası',
                      'assets/legal/gizlilik.md',
                    ),
                    child: Text('Gizlilik Politikası', style: linkStyle),
                  ),
                  Text('nı kabul etmiş olursunuz.', style: bodyStyle),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.surfaceLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> completeOnboarding(ProRepository repo) => repo.setOnboardingDone();
