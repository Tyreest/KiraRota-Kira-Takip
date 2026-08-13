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
      final days = daysUntilRenewal(r.increaseDate, now: n);
      if (days >= 0 && days <= upcomingHorizonDays) upcoming++;
      if (r.increaseDate.year == n.year && r.increaseDate.month == n.month) {
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
    final list = [...rentals]
      ..sort((a, b) => a.increaseDate.compareTo(b.increaseDate));
    return list
        .where((r) {
          final d = daysUntilRenewal(r.increaseDate, now: n);
          return d >= -7; // biraz geçmiş yenilemeler de gösterilebilir
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
        '${rental.increaseDate.year}-${rental.increaseDate.month.toString().padLeft(2, '0')}';
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

/// Talep edilen kira farkı (nötr matematik).
class RequestedRentCompare {
  const RequestedRentCompare({
    required this.calculatedRent,
    required this.requestedRent,
  });

  final double calculatedRent;
  final double requestedRent;

  double get difference => requestedRent - calculatedRent;
}
