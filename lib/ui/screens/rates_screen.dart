import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
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

  String _statusLabel(LoadedRates loaded) {
    final age = DateTime.now().difference(loaded.bundle.updatedAt).inDays;
    if (loaded.source == RateSource.asset &&
        AppConstants.remoteRatesUrl.trim().isNotEmpty) {
      return age > 45
          ? 'Yerel yedek (güncelleme alınamadı olabilir)'
          : 'Yerel paket';
    }
    if (age > 45) return 'Eski olabilir — güncelleme bekleniyor';
    return 'Veriler güncel';
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(ratesProvider);

    return ratesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (loaded) {
        final all = loaded.bundle.rates.reversed.toList();
        final visible = _showAll ? all : all.take(7).toList();
        final latestKey = loaded.bundle.latest?.renewalMonth;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'TÜFE Oranları',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            InfoBanner(
              message:
                  'Son güncelleme: ${formatDateTr(loaded.bundle.updatedAt)}\n'
                  'Kaynak: TÜİK\n'
                  '${_statusLabel(loaded)}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openTuikSource(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Resmî TÜİK kaynağını görüntüle'),
              ),
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
            const SizedBox(height: 12),
            Text(
              loaded.bundle.sourceNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              AppConstants.notOfficialDisclaimer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
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
