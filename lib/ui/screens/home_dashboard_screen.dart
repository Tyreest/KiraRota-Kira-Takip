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
    final upcoming = DashboardLogic.upcomingRentals(rentals);
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
        _SummaryStrip(summary: summary),
        const SizedBox(height: AppSpace.lg),
        Text(
          'Yaklaşan Yenilemeler',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        if (upcoming.isEmpty)
          _SurfaceCard(
            child: Text(
              'Yakın dönemde yenileme yok.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else
          ...upcoming.map((r) {
            final estimate = ratesAsync.maybeWhen(
              data: (loaded) => DashboardLogic.estimateNewRent(
                rental: r,
                bundle: loaded.bundle,
              ),
              orElse: () => null,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: _UpcomingCard(
                rental: r,
                estimate: estimate,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RentalDetailScreen(rentalId: r.id),
                  ),
                ),
                onCalculate: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CalculateScreen(rentalId: r.id),
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Son İşlemler',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
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
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActivityRow(
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
        const SizedBox(height: AppSpace.lg),
        Text(
          'Hızlı İşlemler',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'KiraRota',
          key: const Key('dashboard_page_title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            height: 28 / 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              label: 'Aktif Kiralar',
              value: '${summary.activeCount}',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _SummaryMetric(
              label: 'Yaklaşan',
              value: '${summary.upcomingCount}',
            ),
          ),
          Container(
            width: 1,
            height: 40,
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
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 20,
            height: 28 / 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
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
    final days = daysUntilRenewal(rental.increaseDate);
    final daysLabel = days < 0
        ? 'Yenileme geçti'
        : days == 0
        ? 'Bugün'
        : '$days gün kaldı';

    return _SurfaceCard(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    rental.propertyName,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      height: 28 / 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: days < 0
                        ? AppColors.errorContainer
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Text(
                    daysLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: days < 0
                          ? AppColors.error
                          : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Yenileme: ${formatDateTr(rental.increaseDate)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 20 / 14,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MoneyColumn(
                    label: 'Mevcut kira',
                    value: formatMoney(rental.currentRent),
                  ),
                ),
                Expanded(
                  child: _MoneyColumn(
                    label: estimate == null
                        ? 'Tahmini yeni kira'
                        : (estimate!.isOfficialForPeriod
                              ? 'Hesaplanan yeni kira'
                              : 'Tahmini yeni kira'),
                    value: estimate == null
                        ? '—'
                        : formatMoney(estimate!.amount),
                  ),
                ),
              ],
            ),
            if (estimate != null && !estimate!.isOfficialForPeriod) ...[
              const SizedBox(height: 8),
              Text(
                'Son bilinen TÜFE ile tahmini; resmî dönem oranı yayınlanınca değişebilir.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCalculate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: Text(
                  'Yeni dönemi hesapla',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyColumn extends StatelessWidget {
  const _MoneyColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            height: 24 / 16,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, this.onTap});

  final DashboardActivity activity;
  final VoidCallback? onTap;

  IconData get _icon => switch (activity.kind) {
    DashboardActivityKind.periodCalculated => Icons.history,
    DashboardActivityKind.rentalAdded => Icons.add_home_outlined,
    DashboardActivityKind.renewalUpdated => Icons.event_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${activity.title} - ${activity.subtitle}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  formatDateTr(activity.at),
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
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(height: 8),
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
