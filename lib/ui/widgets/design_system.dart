import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../services/external_link_service.dart';

/// Tam ekran (tab dışı) scroll sayfalarında sistem navigation inset’ini ekler.
///
/// [base] içerik boşluğu; altına [MediaQuery.viewPadding] bottom eklenir.
/// Ana sekmelerde kullanma — [HomeShell] zaten SafeArea / NavigationBar yönetir.
EdgeInsets scrollablePagePadding(
  BuildContext context, {
  double horizontal = 20,
  double top = 20,
  double bottom = 20,
}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottom + MediaQuery.viewPaddingOf(context).bottom,
  );
}

class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'PRO',
        style: GoogleFonts.hankenGrotesk(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: AppColors.onSurface,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline,
    this.tone = InfoBannerTone.amber,
  });

  final String? title;
  final String message;
  final IconData icon;
  final InfoBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      InfoBannerTone.amber => AppColors.amberSoft,
      InfoBannerTone.sage => AppColors.sageSoft,
    };
    final border = switch (tone) {
      InfoBannerTone.amber => AppColors.amberBorder,
      InfoBannerTone.sage => AppColors.outlineVariant,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum InfoBannerTone { amber, sage }

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surfaceLowest,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: child,
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class DatePickerTile extends StatelessWidget {
  const DatePickerTile({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
    this.helperText,
    this.exampleText,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;
  final String? helperText;
  final String? exampleText;

  @override
  Widget build(BuildContext context) {
    final helperStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.onSurfaceVariant,
      height: 1.35,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        if (helperText != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(helperText!, style: helperStyle),
          ),
        ],
        Material(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      valueText,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (exampleText != null) ...[
          const SizedBox(height: 6),
          Text(exampleText!, style: helperStyle),
        ],
      ],
    );
  }
}

/// Kira artışında kullanılan TÜFE 12 aylık ortalamasının ne olduğunu
/// kullanıcıya hukuki hüküm dili olmadan, TBK 344 ve TÜİK bağlamında anlatan modal.
Future<void> showTufeExplanationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      maintainBottomViewPadding: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    'TÜFE 12 Aylık Ortalama Nedir?',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Kira artışında yasal tavan olarak kullanılan oran, haberlerde sıkça yer alan '
              'yıllık enflasyon oranı değildir.\n\n'
              'Türk Borçlar Kanunu (TBK Madde 344) gereğince yenilenen kira dönemlerinde '
              'uygulanabilecek azami artış, bir önceki kira yılının '
              '“TÜFE son 12 aylık ortalamalara göre değişim oranı” ile sınırlandırılmıştır.\n\n'
              'Bu oran, bir yıl içindeki dönemsel dalgalanmaları dengelemek amacıyla her ay TÜİK '
              'tarafından resmî bültende yayımlanır.',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => openTuikSource(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Resmî TÜİK Kaynağını Aç'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anladım'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
