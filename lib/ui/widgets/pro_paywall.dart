import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../screens/reminder_screen.dart';
import 'design_system.dart';

Future<void> showProPaywall(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.92;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppConstants.brandName,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ProBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Yenileme tarihini unutma, kira artış dönemini zamanında takip et. '
                'Tüm özelliklere sınırsız erişim sağla.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const _PayFeature(
                icon: Icons.notifications_active_outlined,
                title: 'Yenileme Hatırlatması',
                body: '30 gün önce, 7 gün önce ve yenileme günü bildirim al.',
              ),
              const _PayFeature(
                icon: Icons.block,
                title: 'Reklamsız Deneyim',
                body: 'Uygulamayı dikkatiniz dağılmadan, temiz bir arayüzle kullanın.',
              ),
              const _PayFeature(
                icon: Icons.picture_as_pdf_outlined,
                title: 'PDF Özet Raporu',
                body: 'Hesaplamalarınızı ve TÜFE oranlarını PDF olarak kaydedip paylaşın.',
              ),
              const _PayFeature(
                icon: Icons.history,
                title: 'Sınırsız Geçmiş',
                body: 'Tüm önceki hesaplamalarınızı arşivleyin.',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppConstants.proPriceLabel,
                    style: GoogleFonts.montserrat(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '/ tek seferlik',
                      style: Theme.of(ctx).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final iap = ref.read(iapServiceProvider);
                  final ok = await iap.buy();
                  // Debug unlock veya purchase stream sonrası Pro bayrağını oku.
                  ref.read(isProProvider.notifier).syncFromRepo();
                  if (!ref.read(isProProvider) && ok) {
                    for (var i = 0; i < 8; i++) {
                      await Future<void>.delayed(
                        const Duration(milliseconds: 250),
                      );
                      ref.read(isProProvider.notifier).syncFromRepo();
                      if (ref.read(isProProvider)) break;
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    final isPro = ref.read(isProProvider);
                    final msg = !ok
                        ? (iap.lastError ?? 'Satın alma tamamlanamadı')
                        : (isPro
                            ? 'Pro aktif.'
                            : 'Satın alma başlatıldı…');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                },
                child: const Text('Şimdi Al'),
              ),
              TextButton(
                onPressed: () async {
                  await ref.read(iapServiceProvider).restore(
                        (_) => ref.read(isProProvider.notifier).syncFromRepo(),
                      );
                  ref.read(isProProvider.notifier).syncFromRepo();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ref.read(isProProvider)
                              ? 'Satın alımlar geri yüklendi.'
                              : 'Geri yüklenecek satın alma bulunamadı.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Satın alımları geri yükle'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Sonra'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PayFeature extends StatelessWidget {
  const _PayFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        color: AppColors.surfaceLow,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void openReminderOrPaywall(BuildContext context, WidgetRef ref) {
  if (ref.read(isProProvider)) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReminderScreen()),
    );
  } else {
    showProPaywall(context, ref);
  }
}
