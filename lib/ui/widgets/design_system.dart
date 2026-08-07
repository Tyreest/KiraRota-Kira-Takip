import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';

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
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
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
      ],
    );
  }
}
