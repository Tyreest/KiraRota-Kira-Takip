import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/models/calculation.dart';
import '../../services/external_link_service.dart';

/// Sonuç ekranlarındaki dağınık veri güncelleme, TÜİK kaynağı,
/// 12 aylık TÜFE açıklaması ve hukuki disclaimer bilgilerini
/// düzenli sırayla gösteren ortak bottom sheet.
Future<void> showCalculationInfoSheet(
  BuildContext context,
  CalculationResult result,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => CalculationInfoSheet(result: result),
  );
}

class CalculationInfoSheet extends StatelessWidget {
  const CalculationInfoSheet({super.key, required this.result});

  final CalculationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTuikReleaseDate = !result.isEstimated ||
        result.rateBasis == RateBasisKind.estimatedLatestOfficial;

    return SafeArea(
      maintainBottomViewPadding: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hesaplama Bilgileri ve Kaynak',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 1. Kullanılan oran
            _InfoRow(
              label: 'Kullanılan oran',
              value: formatPercent(result.applicableRatePercent),
              subtitle: result.input.contractIncreasePercent != null
                  ? (result.contractCompare == ContractCompareKind.contractHigher
                      ? 'Yasal azami oran uygulandı (Sözleşme: ${formatPercent(result.input.contractIncreasePercent!)})'
                      : 'Sözleşme oranı uygulandı')
                  : (result.isEstimated
                      ? (result.rateBasis == RateBasisKind.estimatedLatestOfficial
                          ? 'Son açıklanan resmî oran'
                          : 'Kullanıcı senaryo oranı')
                      : 'TÜFE 12 aylık ortalama'),
            ),
            const Divider(height: 16),
            // 2. Oranın dönemi
            _InfoRow(
              label: 'Oran dönemi',
              value: formatMonthKey(result.input.renewalMonthKey),
              subtitle: result.isEstimated && result.estimateSourceMonthKey != null
                  ? 'Kaynak resmî dönem: ${formatMonthKey(result.estimateSourceMonthKey!)}'
                  : (result.isEstimated
                      ? 'Bu dönem için henüz resmî oran açıklanmadı'
                      : null),
            ),
            // 3. TÜİK açıklama tarihi (varsa)
            if (hasTuikReleaseDate) ...[
              const Divider(height: 16),
              _InfoRow(
                label: result.isEstimated
                    ? 'Son resmî TÜİK açıklama tarihi'
                    : 'TÜİK açıklama tarihi',
                value: formatDateTr(result.tuikReleaseDate),
              ),
            ],
            // 4. Veri güncelleme tarihi (varsa)
            const Divider(height: 16),
            _InfoRow(
              label: 'Veri güncelleme tarihi',
              value: formatDateTr(result.datasetUpdatedAt),
            ),
            const Divider(height: 20),
            // 5. “12 aylık ortalamalara göre TÜFE değişimi” kısa açıklaması
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sageSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '12 Aylık Ortalamalara Göre TÜFE Nedir?',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TBK Madde 344 uyarınca konut ve çatılı işyeri kiralarında yenilenen kira dönemi artış tavanı, '
                    'bir önceki kira yılının TÜFE 12 aylık ortalamalara göre değişim oranı ile sınırlıdır.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 6. Resmî TÜİK kaynak bağlantısı
            if (!result.isEstimated ||
                result.rateBasis == RateBasisKind.estimatedLatestOfficial)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      openTuikSource(context, sourceUrl: result.tuikSourceUrl),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    result.isEstimated
                        ? 'Kaynak: TÜİK — son resmi dönem'
                        : 'Kaynak: TÜİK — Resmî kaynağı görüntüle',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // 7. Hukuki disclaimer
            Text(
              AppConstants.disclaimerShort,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppColors.outline,
            ),
          ),
        ],
      ],
    );
  }
}
