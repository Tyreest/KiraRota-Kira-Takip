import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// PDF Raporu Al → Cihaza Kaydet / Paylaş seçenekleri.
Future<void> showPdfExportSheet(
  BuildContext context, {
  required Future<void> Function() onSaveToDevice,
  required Future<void> Function() onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
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
              const SizedBox(height: 12),
              Text('PDF Raporu', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              ListTile(
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
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    },
  );
}
