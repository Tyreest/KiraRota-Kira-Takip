import '../core/format.dart';
import 'models/rental.dart';
import 'models/tufe_rate.dart';

/// Dashboard özet metrikleri — gerçek rental listesinden.
class DashboardSummary {
  const DashboardSummary({
    required this.activeCount,
    required this.upcomingCount,
    required this.thisMonthCount,
  });

  final int activeCount;
  final int upcomingCount;
  final int thisMonthCount;
}

enum DashboardActivityKind { periodCalculated, rentalAdded, renewalUpdated }

class DashboardActivity {
  const DashboardActivity({
    required this.kind,
    required this.at,
    required this.title,
    required this.subtitle,
    this.rentalId,
  });

  final DashboardActivityKind kind;
  final DateTime at;
  final String title;
  final String subtitle;
  final String? rentalId;
}

class EstimatedRenewalRent {
  const EstimatedRenewalRent({
    required this.amount,
    required this.ratePercent,
    required this.isOfficialForPeriod,
    required this.rateMonthKey,
  });

  final double amount;
  final double ratePercent;

  /// true: yenileme ayı için resmi oran var.
  final bool isOfficialForPeriod;
  final String rateMonthKey;
}

abstract final class DashboardLogic {
  static const upcomingHorizonDays = 45;

  static DashboardSummary summarize(List<Rental> rentals, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var upcoming = 0;
    var thisMonth = 0;
    for (final r in rentals) {
      final effective = r.renewalResolved != null
          ? r
          : migrateRentalRenewal(r, now: n);
      final status = renewalStatusOf(effective, now: n);
      if (status.needsConfirmation) continue;
      final days = daysUntilRenewal(effective.nextRenewalDate, now: n);
      if (days >= 0 && days <= upcomingHorizonDays) upcoming++;
      final next = dateOnly(effective.nextRenewalDate);
      if (days >= 0 && next.year == n.year && next.month == n.month) {
        thisMonth++;
      }
    }
    return DashboardSummary(
      activeCount: rentals.length,
      upcomingCount: upcoming,
      thisMonthCount: thisMonth,
    );
  }

  static List<Rental> upcomingRentals(
    List<Rental> rentals, {
    DateTime? now,
    int limit = 5,
  }) {
    final n = now ?? DateTime.now();
    final effectiveList = rentals
        .map(
          (r) =>
              r.renewalResolved != null ? r : migrateRentalRenewal(r, now: n),
        )
        .toList();
    effectiveList.sort(
      (a, b) => a.nextRenewalDate.compareTo(b.nextRenewalDate),
    );
    return effectiveList
        .where((r) {
          final status = renewalStatusOf(r, now: n);
          // Belirsiz legacy tarih dashboard upcoming'e girmez.
          // Gerçek overdue (pending nextRenewalDate) listelenir; Yaklaşan sayacı
          // yalnızca gelecekteki nextRenewalDate için artar (summarize).
          if (status.needsConfirmation) return false;
          return true;
        })
        .take(limit)
        .toList();
  }

  /// Tahmini yeni kira — history’ye yazılmaz.
  static EstimatedRenewalRent? estimateNewRent({
    required Rental rental,
    required TufeRateBundle bundle,
  }) {
    final key =
        '${rental.nextRenewalDate.year}-${rental.nextRenewalDate.month.toString().padLeft(2, '0')}';
    final official = bundle.findByRenewalMonth(key);
    final rate = official ?? bundle.latest;
    if (rate == null) return null;
    final amount =
        (rental.currentRent * (1 + rate.ratePercent / 100) * 100)
            .roundToDouble() /
        100;
    return EstimatedRenewalRent(
      amount: amount,
      ratePercent: rate.ratePercent,
      isOfficialForPeriod: official != null,
      rateMonthKey: rate.renewalMonth,
    );
  }

  static List<DashboardActivity> recentActivities(
    List<Rental> rentals, {
    int limit = 8,
  }) {
    final items = <DashboardActivity>[];
    for (final r in rentals) {
      items.add(
        DashboardActivity(
          kind: DashboardActivityKind.rentalAdded,
          at: r.createdAt,
          title: 'Kira eklendi',
          subtitle: r.propertyName,
          rentalId: r.id,
        ),
      );
      for (final s in r.history) {
        items.add(
          DashboardActivity(
            kind: DashboardActivityKind.periodCalculated,
            at: s.calculatedAt,
            title: 'Yeni dönem hesaplandı',
            subtitle: r.propertyName,
            rentalId: r.id,
          ),
        );
      }
      if (r.updatedAt.difference(r.createdAt).inMinutes.abs() > 1 &&
          r.history.isEmpty) {
        items.add(
          DashboardActivity(
            kind: DashboardActivityKind.renewalUpdated,
            at: r.updatedAt,
            title: 'Yenileme tarihi güncellendi',
            subtitle: r.propertyName,
            rentalId: r.id,
          ),
        );
      }
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items.take(limit).toList();
  }
}

/// Karşılaştırma yardımcısı — ana hesabı mutate etmez / persist etmez.
class RequestedRentCompare {
  const RequestedRentCompare({
    required this.calculatedRent,
    required this.requestedRent,
    required this.currentRent,
    required this.calculatedIncreaseRatePercent,
  });

  final double calculatedRent;

  /// Karşılaştırılacak (konuşulan / teklif edilen) kira.
  final double requestedRent;
  final double currentRent;

  /// Bu hesapta gerçekten uygulanan artış oranı (%).
  final double calculatedIncreaseRatePercent;

  double get comparisonRent => requestedRent;

  double get difference => requestedRent - calculatedRent;

  /// Mevcut kiraya göre karşılaştırılan tutarın artış yüzdesi.
  /// [currentRent] <= 0 ise null (UI’ya NaN sızmaz).
  double? get comparisonIncreasePercent {
    if (currentRent <= 0 || !currentRent.isFinite) return null;
    if (!requestedRent.isFinite) return null;
    final p = ((requestedRent - currentRent) / currentRent) * 100;
    if (!p.isFinite) return null;
    return p;
  }

  /// Karşılaştırılan artış − hesaplanan artış (yüzde puan).
  double? get percentagePointDifference {
    final p = comparisonIncreasePercent;
    if (p == null || !calculatedIncreaseRatePercent.isFinite) return null;
    final d = p - calculatedIncreaseRatePercent;
    if (!d.isFinite) return null;
    return d;
  }

  /// Kullanıcıya gösterilecek oran farkı metni (TÜFE demez).
  String get rateInsightLabel {
    final d = percentagePointDifference;
    if (d == null) return '';
    const eps = 0.05; // yuvarlama gürültüsü
    if (d.abs() < eps) return 'Hesaplanan artış oranıyla aynı';
    final points = formatDecimal(d.abs());
    if (d > 0) {
      return 'Hesaplanan artış oranından $points puan yüksek';
    }
    return 'Hesaplanan artış oranından $points puan düşük';
  }
}
