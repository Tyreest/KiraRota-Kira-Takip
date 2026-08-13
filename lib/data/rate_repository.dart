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
      if (remote.version < asset.version ||
          remote.updatedAt.isBefore(asset.updatedAt)) {
        // Downgrade yok.
        return LoadedRates(bundle: asset, source: RateSource.asset);
      }
      return LoadedRates(bundle: remote, source: RateSource.remote);
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

  /// Remote seçimi kuralları (unit test için saf fonksiyon).
  static TufeRateBundle chooseBundle({
    required TufeRateBundle asset,
    required TufeRateBundle? remote,
  }) {
    if (remote == null) return asset;
    if (remote.version < asset.version) return asset;
    if (remote.updatedAt.isBefore(asset.updatedAt)) return asset;
    return remote;
  }
}
