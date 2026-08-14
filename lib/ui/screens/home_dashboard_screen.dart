import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/dashboard_logic.dart';
import '../../domain/models/rental.dart';
import '../../providers/app_providers.dart';
import 'calculate_screen.dart';
import 'rental_detail_screen.dart';
import 'rental_edit_screen.dart';

/// Özet hero badge renkleri — Stitch dark hero + mevcut design tokens.
@visibleForTesting
({Color background, Color foreground}) dashboardRenewalBadgeColors(
  RenewalStatusInfo status,
) {
  if (status.isOverdue || status.needsConfirmation) {
    return (background: AppColors.errorContainer, foreground: AppColors.error);
  }
  if (status.urgency == RenewalUrgency.today || status.daysUntil <= 7) {
    return (background: AppColors.amberSoft, foreground: AppColors.amber);
  }
  if (status.daysUntil <= 30) {
    return (
      background: AppColors.amberSoft,
      foreground: const Color(0xFF92400E),
    );
  }
  // >30 gün: koyu hero üzerinde beyaz/nötr pill (Stitch).
  return (background: AppColors.surfaceLowest, foreground: AppColors.primary);
}

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key, this.onOpenCalculate});

  final VoidCallback? onOpenCalculate;

  void _openManual(BuildContext context) {
    if (onOpenCalculate != null) {
      onOpenCalculate!();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: CalculateScreen()),
        ),
      );
    }
  }

  void _openAdd(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RentalEditScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentals = ref.watch(rentalsProvider);
    final ratesAsync = ref.watch(ratesProvider);

    if (rentals.isEmpty) {
      return _EmptyHome(
        onAdd: () => _openAdd(context),
        onManual: () => _openManual(context),
      );
    }

    final summary = DashboardLogic.summarize(rentals);
    final nextUp = DashboardLogic.upcomingRentals(rentals, limit: 1);
    final activities = DashboardLogic.recentActivities(rentals);

    // Shell NavigationBar sistem inset’ini yönetir; body’de double inset yok.
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.margin,
        AppSpace.sm,
        AppSpace.margin,
        AppSpace.lg,
      ),
      children: [
        const _DashboardHeader(),
        const SizedBox(height: AppSpace.md),
        if (nextUp.isEmpty)
          _LightCard(
            child: Text(
              'Sırada yenileme yok.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else
          _NextRenewalHero(
            rental: nextUp.first,
            estimate: ratesAsync.maybeWhen(
              data: (loaded) => DashboardLogic.estimateNewRent(
                rental: nextUp.first,
                bundle: loaded.bundle,
              ),
              orElse: () => null,
            ),
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RentalDetailScreen(rentalId: nextUp.first.id),
              ),
            ),
            onCalculate: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CalculateScreen(rentalId: nextUp.first.id),
              ),
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        _SummaryStrip(summary: summary),
        const SizedBox(height: AppSpace.lg),
        Text(
          'Son İşlemler',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 20 / 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        if (activities.isEmpty)
          Text(
            'Henüz işlem yok.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          )
        else
          ...activities.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: _ActivityCard(
                activity: a,
                onTap: a.rentalId == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RentalDetailScreen(rentalId: a.rentalId!),
                        ),
                      ),
              ),
            ),
          ),
        const SizedBox(height: AppSpace.md),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.calculate_outlined,
                label: 'Manuel Hesaplama',
                onTap: () => _openManual(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_home_outlined,
                label: 'Kira Ekle',
                onTap: () => _openAdd(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  static const _symbolAsset =
      'assets/branding/kirarota/symbol_green_transparent.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              _symbolAsset,
              width: 26,
              height: 26,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'KiraRota',
            ),
            const SizedBox(width: 8),
            Text(
              'KiraRota',
              key: const Key('dashboard_page_title'),
              style: GoogleFonts.inter(
                fontSize: 20,
                height: 28 / 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextRenewalHero extends StatelessWidget {
  const _NextRenewalHero({
    required this.rental,
    required this.estimate,
    required this.onOpen,
    required this.onCalculate,
  });

  final Rental rental;
  final EstimatedRenewalRent? estimate;
  final VoidCallback onOpen;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    final status = renewalStatusOf(rental);
    final badge = dashboardRenewalBadgeColors(status);
    final estimateLabel = estimate == null
        ? 'Tahmini yeni kira'
        : (estimate!.isOfficialForPeriod
              ? 'Hesaplanan yeni kira'
              : 'Tahmini yeni kira');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  top: -48,
                  right: -48,
                  child: IgnorePointer(
                    child: Container(
                      width: 192,
                      height: 192,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SIRADAKİ YENİLEME',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    height: 16 / 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.8,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rental.propertyName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    height: 32 / 24,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: badge.background,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    status.isOverdue
                                        ? Icons.warning_amber_rounded
                                        : Icons.timer_outlined,
                                    size: 14,
                                    color: badge.foreground,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      status.shortLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        height: 16 / 12,
                                        fontWeight: FontWeight.w600,
                                        color: badge.foreground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: AppColors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sonraki yenileme: ${formatDateTr(rental.nextRenewalDate)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 20 / 14,
                                color: AppColors.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroMoneyTile(
                              label: 'Mevcut kira',
                              value: formatMoney(rental.currentRent),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _HeroMoneyTile(
                              label: estimateLabel,
                              value: estimate == null
                                  ? '—'
                                  : formatMoney(estimate!.amount),
                            ),
                          ),
                        ],
                      ),
                      if (estimate != null &&
                          !estimate!.isOfficialForPeriod) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Son bilinen TÜFE ile tahmini; resmî dönem oranı yayınlanınca değişebilir.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 16 / 12,
                            color: AppColors.onPrimaryContainer.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: onCalculate,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(48),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Yeni dönemi hesapla',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 20 / 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroMoneyTile extends StatelessWidget {
  const _HeroMoneyTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: AppColors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Aktif Kiralar',
                value: '${summary.activeCount}',
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Yaklaşan',
                value: '${summary.upcomingCount}',
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Bu Ay',
                value: '${summary.thisMonthCount}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LightCard extends StatelessWidget {
  const _LightCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: child,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, this.onTap});

  final DashboardActivity activity;
  final VoidCallback? onTap;

  IconData get _icon => switch (activity.kind) {
    DashboardActivityKind.periodCalculated => Icons.calculate_outlined,
    DashboardActivityKind.rentalAdded => Icons.add_home_outlined,
    DashboardActivityKind.renewalUpdated => Icons.event_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final detail = '${activity.subtitle} (${formatDateTr(activity.at)})';

    return Material(
      color: AppColors.surfaceLowest,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 20, color: AppColors.primaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 20 / 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 20 / 14,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLowest,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.secondaryContainer),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onAdd, required this.onManual});

  final VoidCallback onAdd;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.margin,
        AppSpace.sm,
        AppSpace.margin,
        AppSpace.lg,
      ),
      children: [
        const _DashboardHeader(),
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.sageSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home_work_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Kiranı takip etmeye başla',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Yenileme tarihini, artış geçmişini ve hesaplamalarını tek yerde tut.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Kira Ekle'),
        ),
        const SizedBox(height: 16),
        Text(
          'Sadece hesaplama mı yapmak istiyorsun?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        TextButton(
          onPressed: onManual,
          child: const Text('Manuel kira artışı hesapla'),
        ),
      ],
    );
  }
}
