import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_store.dart';
import '../data/rate_repository.dart';
import '../data/rental_repository.dart';
import '../domain/calculation_engine.dart';
import '../domain/models/calculation.dart';
import '../domain/models/rental.dart';
import '../domain/models/tufe_rate.dart';
import '../services/iap_service.dart';
import '../services/pdf_report_service.dart';
import '../services/reminder_service.dart';
import '../services/review_access.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences override gerekli');
});

final rateRepositoryProvider = Provider<RateRepository>((ref) {
  return RateRepository();
});

final calculationEngineProvider = Provider<CalculationEngine>((ref) {
  return const CalculationEngine();
});

final proRepositoryProvider = Provider<ProRepository>((ref) {
  return ProRepository(ref.watch(sharedPreferencesProvider));
});

final reviewAccessRepositoryProvider = Provider<ReviewAccessRepository>((ref) {
  return ReviewAccessRepository(ref.watch(sharedPreferencesProvider));
});

final rentalRepositoryProvider = Provider<RentalRepository>((ref) {
  return RentalRepository(ref.watch(sharedPreferencesProvider));
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref.watch(sharedPreferencesProvider));
});

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  return PdfReportService();
});

final iapServiceProvider = ChangeNotifierProvider<IapService>((ref) {
  return IapService(ref.watch(proRepositoryProvider));
});

/// Gerçek Play Billing entitlement (review access DEĞİL).
final isProProvider = StateNotifierProvider<ProNotifier, bool>((ref) {
  return ProNotifier(ref.watch(proRepositoryProvider));
});

class ProNotifier extends StateNotifier<bool> {
  ProNotifier(this._repo) : super(_repo.isPro);
  final ProRepository _repo;

  Future<void> setPro(bool value) async {
    await _repo.setPro(value);
    state = value;
  }

  void syncFromRepo() {
    state = _repo.isPro;
  }
}

/// İnceleme erişimi — Play ownership'ten ayrı yerel bayrak.
final reviewAccessEnabledProvider =
    StateNotifierProvider<ReviewAccessNotifier, bool>((ref) {
      return ReviewAccessNotifier(ref.watch(reviewAccessRepositoryProvider));
    });

class ReviewAccessNotifier extends StateNotifier<bool> {
  ReviewAccessNotifier(this._repo) : super(_repo.isEnabled);
  final ReviewAccessRepository _repo;

  Future<bool> unlockWithCode(String code) async {
    if (!ReviewAccessVerifier.matches(code)) return false;
    await _repo.setEnabled(true);
    state = true;
    return true;
  }

  Future<void> disable() async {
    await _repo.clear();
    state = false;
  }

  void syncFromRepo() {
    state = _repo.isEnabled;
  }
}

/// Pro özellik kapıları: gerçek satın alma VEYA inceleme erişimi.
final hasProFeaturesProvider = Provider<bool>((ref) {
  return ref.watch(isProProvider) || ref.watch(reviewAccessEnabledProvider);
});

/// UMP privacy options entry point gerekli mi (Ayarlar aksiyonu).
final privacyOptionsRequiredProvider = StateProvider<bool>((ref) => false);

final ratesProvider = FutureProvider<LoadedRates>((ref) async {
  return ref.watch(rateRepositoryProvider).load();
});

final rentalsProvider = StateNotifierProvider<RentalsNotifier, List<Rental>>((
  ref,
) {
  return RentalsNotifier(
    ref.watch(rentalRepositoryProvider),
    ref.watch(reminderServiceProvider),
    () => ref.read(hasProFeaturesProvider),
  );
});

class RentalsNotifier extends StateNotifier<List<Rental>> {
  RentalsNotifier(this._repo, this._reminders, this._hasProFeatures)
    : super(_repo.loadAll());

  final RentalRepository _repo;
  final ReminderService _reminders;
  final bool Function() _hasProFeatures;

  void refresh() {
    state = _repo.loadAll();
  }

  Future<bool> add(Rental rental) async {
    final ok = await _repo.add(rental, isPro: _hasProFeatures());
    if (ok) {
      state = _repo.loadAll();
      if (rental.reminder.enabled) {
        await _reminders.scheduleForRental(rental);
      }
    }
    return ok;
  }

  Future<void> update(Rental rental) async {
    await _repo.update(rental);
    state = _repo.loadAll();
    if (rental.reminder.enabled) {
      await _reminders.scheduleForRental(rental);
    } else {
      await _reminders.cancelForRental(rental.id);
    }
  }

  Future<void> delete(String id) async {
    await _reminders.cancelForRental(id);
    await _repo.delete(id);
    state = _repo.loadAll();
  }

  Future<Rental?> applyCalculation({
    required String rentalId,
    required CalculationResult result,
  }) async {
    final updated = await _repo.applyCalculation(
      rentalId: rentalId,
      result: result,
      isPro: _hasProFeatures(),
    );
    if (updated != null) {
      state = _repo.loadAll();
      if (updated.reminder.enabled) {
        await _reminders.scheduleForRental(updated);
      }
    }
    return updated;
  }

  Future<Rental?> createFromCalculation({
    required String displayName,
    required RentalRole role,
    required CalculationResult result,
  }) async {
    final created = await _repo.createFromCalculation(
      displayName: displayName,
      role: role,
      result: result,
      isPro: _hasProFeatures(),
    );
    if (created != null) {
      state = _repo.loadAll();
    }
    return created;
  }

  Future<void> rescheduleAllReminders() async {
    await _reminders.rescheduleAllRentals(state);
  }
}
