import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../domain/models/tufe_rate.dart';

class RateRepository {
  RateRepository({
    http.Client? client,
    this.remoteUrl = AppConstants.remoteRatesUrl,
    this.assetPath = 'assets/data/tufe_rates.json',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String? remoteUrl;
  final String assetPath;

  Future<LoadedRates> load() async {
    final asset = await _loadAsset();
    if (remoteUrl == null || remoteUrl!.trim().isEmpty) {
      return LoadedRates(bundle: asset, source: RateSource.asset);
    }

    try {
      final remote = await _loadRemote(remoteUrl!);
      if (isAcceptableRemote(asset: asset, remote: remote)) {
        return LoadedRates(bundle: remote, source: RateSource.remote);
      }
      return LoadedRates(bundle: asset, source: RateSource.asset);
    } catch (_) {
      return LoadedRates(bundle: asset, source: RateSource.asset);
    }
  }

  Future<TufeRateBundle> _loadAsset() async {
    final raw = await rootBundle.loadString(assetPath);
    return TufeRateBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<TufeRateBundle> _loadRemote(String url) async {
    final res = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Remote rates HTTP ${res.statusCode}');
    }
    return TufeRateBundle.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// Test / saf JSON parse.
  static TufeRateBundle parseJsonString(String raw) {
    return TufeRateBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Remote seçimi — bozuk/eksik remote sağlam asset’i ezmez.
  static TufeRateBundle chooseBundle({
    required TufeRateBundle asset,
    required TufeRateBundle? remote,
  }) {
    if (remote == null) return asset;
    if (!isAcceptableRemote(asset: asset, remote: remote)) return asset;
    return remote;
  }

  /// Last-known-good: remote en az asset kadar güncel ve yapısal olarak sağlam olmalı.
  static bool isAcceptableRemote({
    required TufeRateBundle asset,
    required TufeRateBundle remote,
  }) {
    final issues = validateBundle(remote);
    if (issues.isNotEmpty) return false;
    if (remote.version < asset.version) return false;
    if (remote.updatedAt.isBefore(asset.updatedAt)) return false;
    final assetLatest = asset.latest?.renewalMonth;
    final remoteLatest = remote.latest?.renewalMonth;
    if (remoteLatest == null) return false;
    if (assetLatest != null && remoteLatest.compareTo(assetLatest) < 0) {
      return false;
    }
    // Asset’teki her ay remote’ta da olmalı (sessiz kayıp yok).
    for (final a in asset.rates) {
      if (remote.findByRenewalMonth(a.renewalMonth) == null) return false;
    }
    return true;
  }

  /// Yapısal doğrulama — test ve remote gate için.
  static List<String> validateBundle(TufeRateBundle bundle) {
    final issues = <String>[];
    if (bundle.rates.isEmpty) {
      issues.add('empty rates');
      return issues;
    }
    final seen = <String>{};
    String? prev;
    for (final r in bundle.rates) {
      if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(r.renewalMonth)) {
        issues.add('bad month ${r.renewalMonth}');
      }
      if (!r.ratePercent.isFinite) {
        issues.add('non-finite rate ${r.renewalMonth}');
      } else if (r.ratePercent < 0) {
        issues.add('negative rate ${r.renewalMonth}');
      }
      if (!seen.add(r.renewalMonth)) {
        issues.add('duplicate ${r.renewalMonth}');
      }
      if (prev != null && r.renewalMonth.compareTo(prev) < 0) {
        issues.add('out of order ${r.renewalMonth}');
      }
      prev = r.renewalMonth;
    }
    return issues;
  }
}
