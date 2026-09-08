import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/models/tufe_rate.dart';
import '../../providers/app_providers.dart';
import '../../services/external_link_service.dart';
import '../widgets/design_system.dart';

class RatesScreen extends ConsumerStatefulWidget {
  const RatesScreen({super.key});

  @override
  ConsumerState<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends ConsumerState<RatesScreen> {
  bool _showAll = false;
  bool _isRefreshing = false;

  Future<void> _refreshRates() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      ref.invalidate(ratesProvider);
      await ref.read(ratesProvider.future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TÜFE oranları güncellendi'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Güncelleme kontrol edildi (mevcut oranlar korunuyor)'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(ratesProvider);

    final loaded = ratesAsync.valueOrNull;
    if (loaded == null) {
      if (ratesAsync.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.outline),
              const SizedBox(height: 12),
              Text(
                'TÜFE oranları yüklenemedi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${ratesAsync.error ?? 'Bilinmeyen hata'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.refresh(ratesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    final all = loaded.bundle.rates.reversed.toList();
    final visible = _showAll ? all : all.take(7).toList();
    final latestKey = loaded.bundle.latest?.renewalMonth;

    return RefreshIndicator(
      onRefresh: _refreshRates,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'TÜFE Oranları',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: 'Kira artış oranı nasıl belirleniyor?',
                onPressed: () => showTufeExplanationSheet(context),
              ),
              IconButton(
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Oranları Yenile',
                onPressed: _isRefreshing ? null : _refreshRates,
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => showTufeExplanationSheet(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Kira artış oranı nasıl belirleniyor?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.info_outline, size: 15, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Güncellendi: ${formatDateTr(loaded.bundle.updatedAt)} · TÜİK',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              TextButton(
                onPressed: () => openTuikSource(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(
                  'Resmî TÜİK kaynağını görüntüle',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const Divider(),
                  _RateRow(
                    rate: visible[i],
                    isNew: visible[i].renewalMonth == latestKey,
                  ),
                ],
                if (!_showAll && all.length > visible.length) ...[
                  const Divider(),
                  TextButton(
                    onPressed: () => setState(() => _showAll = true),
                    child: const Text('Daha Eski Verileri Gör'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.rate, required this.isNew});

  final TufeRate rate;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        formatMonthKey(rate.renewalMonth),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.primaryDeep),
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YENİ',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'TÜİK: ${formatDateTr(rate.tuikReleaseDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            formatPercent(rate.ratePercent),
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          IconButton(
            tooltip: 'Kaynak',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: () => openTuikSource(context, sourceUrl: rate.sourceUrl),
          ),
        ],
      ),
    );
  }
}
