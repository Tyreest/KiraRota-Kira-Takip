import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'review_access_sheet.dart';

/// Yedek hazır → Cihaza Kaydet / Paylaş.
Future<void> showBackupReadySheet(
  BuildContext context, {
  required Future<void> Function() onSaveToDevice,
  required Future<void> Function() onShare,
}) {
  return showModalBottomSheet<void>(
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
            Text('Yedek hazır', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Yedeğini cihazına kaydedebilir veya başka bir yere paylaşabilirsin.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.save_alt_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Cihaza Kaydet'),
              subtitle: Text(
                'Dosya adı ve konumu seçin',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await onSaveToDevice();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.share_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Paylaş'),
              subtitle: Text(
                'Diğer uygulamalarla paylaşın',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await onShare();
              },
            ),
          ],
        ),
      );
    },
  );
}
