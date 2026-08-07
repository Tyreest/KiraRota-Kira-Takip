import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../widgets/design_system.dart';
import '../widgets/pro_paywall.dart';
import 'legal_document_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _openLegal(BuildContext context, String title, String asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, assetPath: asset),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(isProProvider);
    final catalog = ref.watch(iapServiceProvider).state;
    final price = catalog.priceForUi;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Ayarlar',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        if (!isPro)
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ProBadge(),
                    const SizedBox(width: 8),
                    Text(
                      'Kira Asistanı Pro',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  catalog.hasStorePrice ? '$price / Tek seferlik' : price,
                  style: GoogleFonts.montserrat(
                    fontSize: catalog.hasStorePrice ? 28 : 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yenileme tarihini unutma. 30 gün önce, 7 gün önce ve '
                  'yenileme günü hatırlatma al.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const _CheckLine('Reklamsız kullanım'),
                const _CheckLine('PDF özet'),
                const _CheckLine('Sınırsız geçmiş'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => showProPaywall(context, ref),
                  child: Text(
                    catalog.hasStorePrice
                        ? 'Pro’ya Geç — $price'
                        : 'Pro’ya Geç',
                  ),
                ),
              ],
            ),
          )
        else
          SoftCard(
            color: AppColors.sageSoft,
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pro aktif — Lifetime',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Yenileme Hatırlatması',
                subtitle: '30 gün · 7 gün · yenileme günü',
                trailing: isPro ? null : const ProBadge(compact: true),
                onTap: () => openReminderOrPaywall(context, ref),
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Gizlilik',
                onTap: () => _openLegal(
                  context,
                  'Gizlilik Politikası',
                  'assets/legal/gizlilik.md',
                ),
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.gavel_outlined,
                title: 'Yasal Uyarı',
                onTap: () => _openLegal(
                  context,
                  'Yasal Uyarı',
                  'assets/legal/yasal_uyari.md',
                ),
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Kullanım Şartları',
                onTap: () => _openLegal(
                  context,
                  'Kullanım Şartları',
                  'assets/legal/kullanim_sartlari.md',
                ),
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'Uygulama Hakkında',
                onTap: () async {
                  final info = await PackageInfo.fromPlatform();
                  if (!context.mounted) return;
                  _showTextSheet(
                    context,
                    'Uygulama Hakkında',
                    '${AppConstants.appName}\n'
                    '${AppConstants.brandName}\n'
                    'Tyreest Studio\n'
                    'v${info.version} (${info.buildNumber})\n'
                    'Paket: ${AppConstants.packageId}',
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final v = snap.data;
            final label = v == null
                ? 'Tyreest Studio'
                : 'Tyreest Studio · v${v.version}';
            return Center(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall),
            );
          },
        ),
      ],
    );
  }

  void _showTextSheet(BuildContext context, String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(ctx).textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}
