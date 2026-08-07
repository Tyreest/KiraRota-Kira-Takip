import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_store.dart';
import '../data/rate_repository.dart';
import '../domain/calculation_engine.dart';
import '../domain/models/tufe_rate.dart';
import '../services/iap_service.dart';
import '../services/pdf_report_service.dart';
import '../services/reminder_service.dart';

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

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(sharedPreferencesProvider));
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  return ReminderService(ref.watch(sharedPreferencesProvider));
});

final pdfReportServiceProvider = Provider<PdfReportService>((ref) {
  return PdfReportService();
});

final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService(ref.watch(proRepositoryProvider));
  ref.onDispose(service.dispose);
  return service;
});

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

  Future<void> unlockDebugOnly() {
    assert(kDebugMode, 'unlockDebugOnly yalnızca debug için');
    return setPro(true);
  }

  Future<void> lockDevOnly() {
    assert(kDebugMode, 'lockDevOnly yalnızca debug için');
    return setPro(false);
  }

  void syncFromRepo() {
    state = _repo.isPro;
  }
}

final ratesProvider = FutureProvider<LoadedRates>((ref) async {
  return ref.watch(rateRepositoryProvider).load();
});

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HistoryEntry>>((ref) {
  return HistoryNotifier(
    ref.watch(historyRepositoryProvider),
    () => ref.read(isProProvider),
  );
});

class HistoryNotifier extends StateNotifier<List<HistoryEntry>> {
  HistoryNotifier(this._repo, this._isPro) : super(_repo.loadAll());

  final HistoryRepository _repo;
  final bool Function() _isPro;

  Future<void> add(HistoryEntry entry) async {
    await _repo.add(entry, isPro: _isPro());
    state = _repo.loadAll();
  }

  Future<void> refresh() async {
    state = _repo.loadAll();
  }
}
