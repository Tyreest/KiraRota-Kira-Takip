import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../providers/app_providers.dart';
import '../widgets/design_system.dart';
import '../widgets/pro_paywall.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key, this.onNewCalculation});

  final VoidCallback? onNewCalculation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(historyProvider);
    final isPro = ref.watch(isProProvider);

    if (items.isEmpty) {
      return _EmptyHistory(onNewCalculation: onNewCalculation);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Center(
          child: Text(
            'Geçmiş',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hesaplama Geçmişi',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          isPro
              ? 'Pro: sınırsız kayıt'
              : 'Ücretsiz: son ${AppConstants.freeHistoryLimit} kayıt',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(),
                _HistoryRow(entry: items[i]),
              ],
            ],
          ),
        ),
        if (!isPro) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pro ile sınırsız geçmiş',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Tüm yıllara ait verilerinizi saklayın.',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.peachCta,
                      foregroundColor: AppColors.primaryDeep,
                    ),
                    onPressed: () => showProPaywall(context, ref),
                    child: const Text('Yükselt'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({this.onNewCalculation});

  final VoidCallback? onNewCalculation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.outlineVariant,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.history,
              size: 36,
              color: AppColors.outline,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Geçmiş',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Henüz hesaplama yok.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Kira artış hesaplamalarınız burada listelenecektir. '
            'Yeni bir hesaplama yaparak başlayabilirsiniz.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onNewCalculation,
            child: const Text('+ Yeni hesaplama'),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMonthKey(entry.renewalMonthKey),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primaryDeep,
                          ),
                    ),
                    Text(
                      formatDateTr(entry.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${formatPercent(entry.applicableRatePercent)} TÜFE',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('Eski kira'),
                    Text(
                      formatMoney(entry.currentRent),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.outline,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, size: 18, color: AppColors.outline),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SectionLabel('Yeni kira'),
                    Text(
                      formatMoney(entry.calculatedRent),
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDeep,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
