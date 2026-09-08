import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
      return Consumer(
        builder: (ctx, ref, _) {
          final catalog = ref.watch(iapServiceProvider).state;
          return SafeArea(
            maintainBottomViewPadding: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'KiraRota Pro',
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
                      body:
                          '30 gün önce, 7 gün önce ve yenileme günü bildirim al.',
                    ),
                    const _PayFeature(
                      icon: Icons.block,
                      title: 'Reklamsız Deneyim',
                      body:
                          'Uygulamayı dikkatiniz dağılmadan, temiz bir arayüzle kullanın.',
                    ),
                    const _PayFeature(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'PDF Özet Raporu',
                      body:
                          'Hesaplamalarınızı ve TÜFE oranlarını PDF olarak kaydedip paylaşın.',
                    ),
                    const _PayFeature(
                      icon: Icons.home_work_outlined,
                      title: 'Sınırsız Kira Takibi',
                      body:
                          'Birden fazla kira kaydı tutun; artış dönemlerini tek yerden yönetin.',
                    ),
                    const _PayFeature(
                      icon: Icons.history,
                      title: 'Sınırsız Hesap Geçmişi',
                      body:
                          'Her kira için tüm önceki hesaplamalarınızı arşivleyin.',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            catalog.priceForUi,
                            style: GoogleFonts.montserrat(
                              fontSize: catalog.hasStorePrice ? 34 : 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                        if (catalog.hasStorePrice) ...[
                          const SizedBox(width: 6),
                          Text(
                            '/ tek seferlik',
                            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sageSoft,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Text(
                        'Tek seferlik ödeme · Abonelik değil',
                        style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryDeep,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ),
                    if (catalog.purchasePending) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ödeme onay bekliyor…',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (catalog.priceUnavailable) ...[
                      Text(
                        catalog.lastMessage ?? 'Fiyat şu anda alınamadı',
                        textAlign: TextAlign.center,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: catalog.busy
                            ? null
                            : () =>
                                  ref.read(iapServiceProvider).refreshCatalog(),
                        child: const Text('Tekrar dene'),
                      ),
                      const SizedBox(height: 4),
                    ],
                    FilledButton(
                      onPressed: catalog.busy
                          ? null
                          : () async {
                              final iap = ref.read(iapServiceProvider);
                              final outcome = await iap.buy();
                              ref.read(isProProvider.notifier).syncFromRepo();
                              if (!ref.read(isProProvider) && outcome.ok) {
                                for (var i = 0; i < 12; i++) {
                                  await Future<void>.delayed(
                                    const Duration(milliseconds: 250),
                                  );
                                  ref
                                      .read(isProProvider.notifier)
                                      .syncFromRepo();
                                  if (ref.read(isProProvider)) break;
                                  if (iap.state.purchasePending) break;
                                  final msg = iap.state.lastMessage ?? '';
                                  if (msg.contains('iptal')) break;
                                }
                              }
                              final isPro = ref.read(isProProvider);
                              final msg =
                                  iap.state.lastMessage ??
                                  outcome.message ??
                                  (isPro
                                      ? 'Pro aktif.'
                                      : outcome.ok
                                      ? 'Satın alma başlatıldı…'
                                      : 'Satın alma tamamlanamadı');
                              if (isPro && ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                              }
                            },
                      child: Text(catalog.busy ? 'Bekleyin…' : 'Şimdi Al'),
                    ),
                    TextButton(
                      onPressed: catalog.busy
                          ? null
                          : () async {
                              final iap = ref.read(iapServiceProvider);
                              await iap.restore(
                                onProChanged: (_) => ref
                                    .read(isProProvider.notifier)
                                    .syncFromRepo(),
                              );
                              // Stream gecikmesi
                              for (var i = 0; i < 8; i++) {
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 200),
                                );
                                ref.read(isProProvider.notifier).syncFromRepo();
                                if (ref.read(isProProvider)) break;
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      iap.state.lastMessage ??
                                          (ref.read(isProProvider)
                                              ? 'Satın alımlar geri yüklendi.'
                                              : 'Geri yüklenecek satın alma bulunamadı.'),
                                    ),
                                  ),
                                );
                              }
                              if (ref.read(isProProvider) && ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                      child: const Text('Pro satın alımını geri yükle'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Sonra'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
  if (!ref.read(hasProFeaturesProvider)) {
    showProPaywall(context, ref);
    return;
  }
  final rentals = ref.read(rentalsProvider);
  if (rentals.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Önce Kiralarım’dan bir kira kaydı ekleyin.'),
      ),
    );
    return;
  }
  if (rentals.length == 1) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReminderScreen(rentalId: rentals.first.id),
      ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'Hatırlatma için kira seçin',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final r in rentals)
              ListTile(
                title: Text(r.displayName),
                subtitle: Text(r.role.labelTr),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReminderScreen(rentalId: r.id),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}
