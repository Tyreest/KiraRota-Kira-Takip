import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/dashboard_logic.dart';
import '../../domain/models/rental.dart';
import '../../providers/app_providers.dart';
import '../widgets/design_system.dart';
import '../widgets/past_renewal_sheet.dart';
import '../widgets/pro_paywall.dart';
import 'rental_detail_screen.dart';
import 'rental_edit_screen.dart';

enum _RentalFilter { all, upcoming, thisMonth, past }

class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen> {
  final _searchCtrl = TextEditingController();
  _RentalFilter _filter = _RentalFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAdd() async {
    final isPro = ref.read(hasProFeaturesProvider);
    final count = ref.read(rentalsProvider).length;
    if (!isPro && count >= AppConstants.freeRentalLimit) {
      await showProPaywall(context, ref);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const RentalEditScreen()),
    );
  }

  Future<void> _openRental(Rental rental) async {
    var current = rental;
    if (current.renewalResolved == false) {
      final resolved = await _resolveAmbiguousRenewal(current);
      if (resolved == null) return;
      current = resolved;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RentalDetailScreen(rentalId: current.id),
      ),
    );
  }

  Future<Rental?> _resolveAmbiguousRenewal(Rental rental) async {
    final past = dateOnly(rental.nextRenewalDate);
    final suggested = nextIncreaseAnniversary(past);
    final choice = await showPastRenewalConfirmationSheet(
      context,
      pastDate: past,
      suggestedNext: suggested,
    );
    if (!mounted) return null;
    if (choice == null) return null;
    if (choice == PastRenewalChoice.changeDate) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RentalEditScreen(rentalId: rental.id),
        ),
      );
      return null;
    }
    final updated = choice == PastRenewalChoice.completed
        ? rental.copyWith(
            lastRenewalDate: past,
            increaseDate: suggested,
            renewalResolved: true,
            updatedAt: DateTime.now(),
          )
        : rental.copyWith(
            increaseDate: past,
            renewalResolved: true,
            updatedAt: DateTime.now(),
          );
    await ref.read(rentalsProvider.notifier).update(updated);
    return updated;
  }

  List<Rental> _filtered(List<Rental> rentals) {
    final now = DateTime.now();
    final q = _searchCtrl.text.trim().toLowerCase();

    bool matchesSearch(Rental r) {
      if (q.isEmpty) return true;
      final hay = [
        r.propertyName,
        r.address,
        r.tenantName,
        r.ownerName,
      ].whereType<String>().join(' ').toLowerCase();
      return hay.contains(q);
    }

    bool matchesFilter(Rental r) {
      final status = renewalStatusOf(r, now: now);
      final days = daysUntilRenewal(r.nextRenewalDate, now: now);
      return switch (_filter) {
        _RentalFilter.all => true,
        _RentalFilter.upcoming =>
          !status.needsConfirmation &&
              days >= 0 &&
              days <= DashboardLogic.upcomingHorizonDays,
        _RentalFilter.thisMonth =>
          !status.needsConfirmation &&
              days >= 0 &&
              r.nextRenewalDate.year == now.year &&
              r.nextRenewalDate.month == now.month,
        _RentalFilter.past => !status.needsConfirmation && days < 0,
      };
    }

    final list =
        rentals.where((r) => matchesSearch(r) && matchesFilter(r)).toList()
          ..sort((a, b) => a.nextRenewalDate.compareTo(b.nextRenewalDate));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rentals = ref.watch(rentalsProvider);
    final isPro = ref.watch(hasProFeaturesProvider);
    final activeCount = rentals.length;
    final visible = _filtered(rentals);
    final limitReached =
        !isPro && rentals.length >= AppConstants.freeRentalLimit;

    if (rentals.isEmpty) {
      return _EmptyRentals(onAdd: _onAdd);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.margin,
        AppSpace.sm,
        AppSpace.margin,
        AppSpace.lg,
      ),
      children: [
        Text('Kiralarım', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpace.xs),
        Text(
          '$activeCount aktif kira',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (!isPro) ...[
          const SizedBox(height: 2),
          Text(
            'Ücretsiz plan · ${AppConstants.freeRentalLimit} kira sınırı',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpace.md),
        if (activeCount > 1 || _searchCtrl.text.isNotEmpty) ...[
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Taşınmaz, kiracı veya adres ara…',
              prefixIcon: const Icon(Icons.search, color: AppColors.outline),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _searchCtrl.clear()),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.md),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in [
                (_RentalFilter.all, 'Tümü'),
                (_RentalFilter.upcoming, 'Yaklaşan'),
                (_RentalFilter.thisMonth, 'Bu Ay'),
                (_RentalFilter.past, 'Geçenler'),
              ]) ...[
                Padding(
                  padding: const EdgeInsets.only(right: AppSpace.sm),
                  child: _FilterChip(
                    label: entry.$2,
                    selected: _filter == entry.$1,
                    onTap: () => setState(() => _filter = entry.$1),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _AddRentalCta(limitReached: limitReached, onPressed: _onAdd),
        const SizedBox(height: AppSpace.md),
        if (visible.isEmpty)
          SoftCard(
            child: Column(
              children: [
                const Icon(Icons.filter_alt_off_outlined, size: 32, color: AppColors.outline),
                const SizedBox(height: 8),
                Text(
                  'Bu filtreye uyan kira kaydı bulunamadı.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filter = _RentalFilter.all;
                      _searchCtrl.clear();
                    });
                  },
                  child: const Text('Filtreleri Temizle'),
                ),
              ],
            ),
          )
        else
          for (final rental in visible) ...[
            _RentalCard(rental: rental, onTap: () => _openRental(rental)),
            const SizedBox(height: 12),
          ],
        if (!isPro) ...[
          const SizedBox(height: AppSpace.sm),
          SoftCard(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ProBadge(compact: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sınırsız kira takibi',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Birden fazla kira kaydı, hatırlatma ve sınırsız geçmiş için Pro’ya geçin.',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.peachCta,
                      foregroundColor: AppColors.primaryDeep,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => showProPaywall(context, ref),
                    child: const Text('Pro’ya geç'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRentalCta extends StatelessWidget {
  const _AddRentalCta({required this.limitReached, required this.onPressed});

  final bool limitReached;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!limitReached) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text('Kira ekle'),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_home_work_outlined),
            label: const Text('Kira ekle'),
          ),
        ),
        const Positioned(right: 10, top: -8, child: ProBadge(compact: true)),
      ],
    );
  }
}

class _EmptyRentals extends StatelessWidget {
  const _EmptyRentals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.margin,
        AppSpace.sm,
        AppSpace.margin,
        AppSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kiralarım', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpace.xs),
          Text(
            '0 aktif kira',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
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
                const SizedBox(height: 20),
                Text(
                  'Henüz kayıtlı kiranız yok',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Taşınmazınızı kaydedin; yenileme tarihlerini ve '
                  'TÜFE hesaplamalarınızı tek yerden takip edin.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Kira ekle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RentalCard extends StatelessWidget {
  const _RentalCard({required this.rental, required this.onTap});

  final Rental rental;
  final VoidCallback onTap;

  String? get _secondary {
    final address = rental.address?.trim();
    if (address != null && address.isNotEmpty) return address;
    final tenant = rental.tenantName?.trim();
    if (tenant != null && tenant.isNotEmpty) return tenant;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final status = renewalStatusOf(rental);
    final daysLabel = status.shortLabel;
    final accent = status.isWarning ? AppColors.error : AppColors.primary;
    final dateLabel = status.needsConfirmation
        ? formatDateTr(rental.nextRenewalDate)
        : formatDateTr(rental.nextRenewalDate);

    return SoftCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: status.isOverdue ? 1 : 0.85),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppRadii.xl),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: status.isWarning
                              ? AppColors.errorContainer
                              : AppColors.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.apartment_outlined,
                          size: 20,
                          color: status.isWarning
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryContainer.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(AppRadii.sm),
                                  ),
                                  child: Text(
                                    rental.role.labelTr,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    rental.propertyName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            if (_secondary != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _secondary!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  status.isWarning
                                      ? Icons.warning_amber_rounded
                                      : Icons.calendar_today_outlined,
                                  size: 14,
                                  color: accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dateLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: accent),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatMoney(rental.currentRent),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            daysLabel,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.outline),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
