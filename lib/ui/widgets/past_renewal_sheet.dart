import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'review_access_sheet.dart';

enum PastRenewalChoice { completed, pending, changeDate }

/// Geçmiş yenileme tarihi kaydında kullanıcıya sor.
Future<PastRenewalChoice?> showPastRenewalConfirmationSheet(
  BuildContext context, {
  required DateTime pastDate,
  required DateTime suggestedNext,
}) {
  return showModalBottomSheet<PastRenewalChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return ReviewAccessSheetScaffold(
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
            Text(
              'Bu tarihte kira yenilendi mi?',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDateTr(pastDate)} geçmiş bir tarih. Bu tarih son '
              'tamamlanan yenilemeyse, sonraki yenileme '
              '${formatDateTr(suggestedNext)} olarak ayarlanacak.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, PastRenewalChoice.completed),
              child: const Text('Evet, yenilendi'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, PastRenewalChoice.pending),
              child: const Text('Hayır, yenileme bekliyor'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, PastRenewalChoice.changeDate),
              child: const Text('Tarihi değiştir'),
            ),
          ],
        ),
      );
    },
  );
}
