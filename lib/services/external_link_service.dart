import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/tuik_urls.dart';

/// Testlerde gerçek tarayıcı açmadan URL launch’ı simüle etmek için.
Future<bool> Function(Uri uri, {LaunchMode mode})? debugUrlLauncherOverride;

/// Resmî TÜİK kaynağını dış tarayıcıda açar; hata olursa crash etmez.
Future<bool> openTuikSource(BuildContext context, {String? sourceUrl}) async {
  final raw = TuikUrls.resolve(sourceUrl);
  try {
    final uri = Uri.parse(raw);
    if (!TuikUrls.isAllowedOfficialHost(uri)) {
      _showOpenFailed(context);
      return false;
    }
    final launcher = debugUrlLauncherOverride;
    final ok = launcher != null
        ? await launcher(uri, mode: LaunchMode.externalApplication)
        : await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showOpenFailed(context);
    }
    return ok;
  } catch (_) {
    if (context.mounted) {
      _showOpenFailed(context);
    }
    return false;
  }
}

void _showOpenFailed(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Resmî kaynak açılamadı.')));
}
