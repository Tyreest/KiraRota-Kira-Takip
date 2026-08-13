import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/dashboard_logic.dart';
import '../../domain/models/rental.dart';
import '../../providers/app_providers.dart';
import '../widgets/design_system.dart';
import 'calculate_screen.dart';
import 'rental_detail_screen.dart';
import 'rental_edit_screen.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key, this.onOpenCalculate});

  final VoidCallback? onOpenCalculate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentals = ref.watch(rentalsProvider);
    final ratesAsync = ref.watch(ratesProvider);

    if (rentals.isEmpty) {
      return _EmptyHome(
        onAdd: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const RentalEditScreen()),
        ),
        onManual: () {
          if (onOpenCalculate != null) {
            onOpenCalculate!();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: CalculateScreen()),
              ),
            );
          }
        },
      );
    }

    final summary = DashboardLogic.summarize(rentals);
    final upcoming = DashboardLogic.upcomingRentals(rentals);
    final activities = DashboardLogic.recentActivities(rentals);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            const Icon(Icons.home_work_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('KiraRota', style: Theme.of(context).textTheme.headlineLarge),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Aktif Kiralar',
                value: '${summary.activeCount}',
                accent: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Yaklaşan',
                value: '${summary.upcomingCount}',
                accent: AppColors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Bu Ay',
                value: '${summary.thisMonthCount}',
                accent: AppColors.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Yaklaşan Yenilemeler',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        if (upcoming.isEmpty)
          SoftCard(
            child: Text(
              'Yakın dönemde yenileme yok.',
              style: Theme.of(context).textTheme.bodyMedium,
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
              padding: const EdgeInsets.only(bottom: 12),
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
        const SizedBox(height: 12),
        Text('Son İşlemler', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < activities.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                ListTile(
                  dense: true,
                  title: Text(activities[i].title),
                  subtitle: Text(activities[i].subtitle),
                  trailing: Text(
                    formatDateTr(activities[i].at),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: activities[i].rentalId == null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RentalDetailScreen(
                              rentalId: activities[i].rentalId!,
                            ),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Hızlı İşlemler',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  if (onOpenCalculate != null) {
                    onOpenCalculate!();
                  }
                },
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Manuel Hesaplama'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RentalEditScreen(),
                  ),
                ),
                icon: const Icon(Icons.add_home_work_outlined),
                label: const Text('Kira Ekle'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: BoxDecoration(
        color: AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadii.xl),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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

    return SoftCard(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rental.propertyName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: days < 0
                        ? AppColors.errorContainer
                        : AppColors.amberSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    daysLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: days < 0 ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Mevcut kira: ${formatMoney(rental.currentRent)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Yenileme: ${formatDateTr(rental.increaseDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (estimate != null) ...[
              const SizedBox(height: 8),
              Text(
                estimate!.isOfficialForPeriod
                    ? 'Hesaplanan yeni kira: ${formatMoney(estimate!.amount)}'
                    : 'Tahmini yeni kira (son bilinen TÜFE %${estimate!.ratePercent.toStringAsFixed(2).replaceAll('.', ',')}): ${formatMoney(estimate!.amount)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              if (!estimate!.isOfficialForPeriod)
                Text(
                  'Bu tutar tahminidir; resmî dönem oranı yayınlanınca değişebilir.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onCalculate,
                child: const Text('Yeni dönemi hesapla'),
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Text('KiraRota', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 48),
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
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          'Yenileme tarihini, artış geçmişini ve hesaplamalarını tek yerde tut.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
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
