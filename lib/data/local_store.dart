import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../domain/models/calculation.dart';

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.createdAt,
    required this.currentRent,
    required this.renewalMonthKey,
    required this.applicableRatePercent,
    required this.calculatedRent,
    required this.isFiveYearsOrMore,
  });

  final String id;
  final DateTime createdAt;
  final double currentRent;
  final String renewalMonthKey;
  final double applicableRatePercent;
  final double calculatedRent;
  final bool isFiveYearsOrMore;

  factory HistoryEntry.fromResult(CalculationResult r) {
    return HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      currentRent: r.input.currentRent,
      renewalMonthKey: r.input.renewalMonthKey,
      applicableRatePercent: r.applicableRatePercent,
      calculatedRent: r.calculatedRent,
      isFiveYearsOrMore: r.isFiveYearsOrMore,
    );
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      currentRent: (json['currentRent'] as num).toDouble(),
      renewalMonthKey: json['renewalMonthKey'] as String,
      applicableRatePercent: (json['applicableRatePercent'] as num).toDouble(),
      calculatedRent: (json['calculatedRent'] as num).toDouble(),
      isFiveYearsOrMore: json['isFiveYearsOrMore'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'currentRent': currentRent,
        'renewalMonthKey': renewalMonthKey,
        'applicableRatePercent': applicableRatePercent,
        'calculatedRent': calculatedRent,
        'isFiveYearsOrMore': isFiveYearsOrMore,
      };
}

class HistoryRepository {
  HistoryRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'history_v1';

  List<HistoryEntry> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Free: max [AppConstants.freeHistoryLimit]. Pro: sınırsız.
  /// Limit aşımında en eski silinir (FIFO trim from end of sorted desc → drop last).
  Future<void> add(HistoryEntry entry, {required bool isPro}) async {
    final items = loadAll();
    items.insert(0, entry);
    if (!isPro && items.length > AppConstants.freeHistoryLimit) {
      items.removeRange(AppConstants.freeHistoryLimit, items.length);
    }
    await _prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() => _prefs.remove(_key);
}

class ProRepository {
  ProRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'is_pro_lifetime';
  static const _onboardingKey = 'onboarding_done';

  bool get isPro => _prefs.getBool(_key) ?? false;

  Future<void> setPro(bool value) => _prefs.setBool(_key, value);

  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_onboardingKey, true);
}
