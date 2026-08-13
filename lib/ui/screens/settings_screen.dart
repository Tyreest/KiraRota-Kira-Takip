import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/ads_service.dart';
import '../../services/external_link_service.dart';
import '../../services/ump_consent_service.dart';
import '../widgets/design_system.dart';
import '../widgets/pro_paywall.dart';
import '../widgets/review_access_sheet.dart';
import 'legal_document_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;
  DateTime? _lastVersionTap;

  void _openLegal(BuildContext context, String title, String asset) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, assetPath: asset),
      ),
    );
  }

  void _onVersionTap() {
    final now = DateTime.now();
    if (_lastVersionTap == null ||
        now.difference(_lastVersionTap!) > const Duration(seconds: 3)) {
      _versionTapCount = 0;
    }
    _lastVersionTap = now;
    _versionTapCount++;
    if (_versionTapCount >= 7) {
      _versionTapCount = 0;
      _showReviewAccessSheet();
    }
  }

  Future<void> _showReviewAccessSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _ReviewAccessSheetBody(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Billing UI: yalnız gerçek Play entitlement
    final realProOwned = ref.watch(isProProvider);
    final hasProFeatures = ref.watch(hasProFeaturesProvider);
    final catalog = ref.watch(iapServiceProvider).state;
    final price = catalog.priceForUi;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Ayarlar', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (realProOwned)
          SoftCard(
            color: AppColors.sageSoft,
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pro aktif — Ömür boyu',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          )
        else if (!hasProFeatures)
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ProBadge(),
                    const SizedBox(width: 8),
                    Text(
                      'KiraRota Pro',
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
                const _CheckLine('Sınırsız kira takibi'),
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
                trailing: hasProFeatures ? null : const ProBadge(compact: true),
                onTap: () => openReminderOrPaywall(context, ref),
              ),
              if (ref.watch(privacyOptionsRequiredProvider)) ...[
                const Divider(),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Gizlilik seçenekleri',
                  subtitle: 'Reklam tercihlerini yönet',
                  onTap: () async {
                    await UmpConsentService.showPrivacyOptionsForm();
                    try {
                      final status = await UmpConsentService.bridge
                          .getPrivacyOptionsRequirementStatus();
                      final required =
                          status == PrivacyOptionsRequirementStatus.required;
                      ref.read(privacyOptionsRequiredProvider.notifier).state =
                          required;
                      AdsService.setPrivacyOptionsRequired(required);
                    } catch (_) {}
                  },
                ),
              ],
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
                  _showAboutSheet(context, info);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Veri ve Yedekleme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Kira kayıtlarınız cihazda saklanır. Android Auto Backup '
                'açıksa uygulama verileri cihaz değişiminde geri yüklenebilir. '
                'Ayrı bir bulut yedekleme hesabı yoktur.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _exportRentalsJson(context),
                icon: const Icon(Icons.share_outlined),
                label: const Text('Kira verilerini JSON olarak paylaş'),
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
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onVersionTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAboutSheet(BuildContext context, PackageInfo info) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Uygulama Hakkında',
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '${AppConstants.appName}\n'
                'Tyreest Studio\n'
                'v${info.version} (${info.buildNumber})\n'
                'Paket: ${AppConstants.packageId}',
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.notOfficialDisclaimer,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Resmî veri kaynağı',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => openTuikSource(ctx),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('TÜİK Veri Portalı'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tamam'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportRentalsJson(BuildContext context) async {
    final rentals = ref.read(rentalRepositoryProvider).loadAll();
    final payload = {
      'app': AppConstants.appName,
      'exportedAt': DateTime.now().toIso8601String(),
      'rentals': rentals.map((e) => e.toJson()).toList(),
    };
    final text = const JsonEncoder.withIndent('  ').convert(payload);
    await SharePlus.instance.share(
      ShareParams(text: text, subject: '${AppConstants.appName} kira verileri'),
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
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Review Access sheet — controller sheet State’inde dispose edilir
/// (route kapanınca erken dispose → `_dependents.isEmpty` assertion’ını önler).
class _ReviewAccessSheetBody extends ConsumerStatefulWidget {
  const _ReviewAccessSheetBody();

  @override
  ConsumerState<_ReviewAccessSheetBody> createState() =>
      _ReviewAccessSheetBodyState();
}

class _ReviewAccessSheetBodyState
    extends ConsumerState<_ReviewAccessSheetBody> {
  late final TextEditingController _controller;
  String _errorText = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorText = '';
    });
    final ok = await ref
        .read(reviewAccessEnabledProvider.notifier)
        .unlockWithCode(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _errorText = 'Kod geçersiz';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewOn = ref.watch(reviewAccessEnabledProvider);
    return ReviewAccessSheetScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'İnceleme erişimi',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          if (reviewOn) ...[
            Text(
              'İnceleme erişimi bu cihazda açık.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await ref
                          .read(reviewAccessEnabledProvider.notifier)
                          .disable();
                      if (mounted) Navigator.pop(context);
                    },
              child: const Text('İnceleme erişimini kapat'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ] else ...[
            TextField(
              controller: _controller,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Kod',
                errorText: _errorText.isEmpty ? null : _errorText,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Doğrula'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
          ],
        ],
      ),
    );
  }
}
