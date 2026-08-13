import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../domain/models/rental.dart';
import '../services/review_access.dart';
import 'rental_repository.dart';

/// Yalnızca debug + SCREENSHOT_SEED / SCREENSHOT_MODE ile çalışır.
/// Release’de no-op.
Future<void> applyScreenshotSeedIfNeeded(SharedPreferences prefs) async {
  if (kReleaseMode) return;

  final mode = AppConstants.screenshotMode.trim().toLowerCase();
  final wantSeed = AppConstants.screenshotSeed || mode == 'seed';
  final wantEmpty = mode == 'empty';
  if (!wantSeed && !wantEmpty) return;

  await prefs.setBool('onboarding_done', true);

  if (wantEmpty) {
    await prefs.remove(RentalRepository.storageKey);
    await ReviewAccessRepository(prefs).clear();
    return;
  }

  // Seeded portfolio + Review Access (PDF/hatırlatma screenshot için Pro gate açılır).
  // Plaintext review code yazılmaz; yalnızca enabled flag.
  await ReviewAccessRepository(prefs).setEnabled(true);

  final repo = RentalRepository(prefs);
  if (repo.loadAll().isNotEmpty) return;

  final now = DateTime.now();
  final renewal = now.add(const Duration(days: 12));
  await repo.add(
    Rental(
      id: 'seed-besiktas',
      role: RentalRole.tenant,
      displayName: 'Beşiktaş · Daire 4',
      currentRent: 38000,
      contractStartDate: DateTime(now.year - 2, renewal.month, renewal.day),
      increaseDate: DateTime(renewal.year, renewal.month, renewal.day),
      address: 'Beşiktaş, İstanbul',
      tenantName: 'Ayşe Yılmaz',
      createdAt: now.subtract(const Duration(days: 40)),
      updatedAt: now.subtract(const Duration(days: 2)),
      history: [
        RentalCalculationSnapshot(
          id: 'seed-h1',
          calculatedAt: now.subtract(const Duration(days: 370)),
          oldRent: 28810,
          calculatedRent: 38000,
          tufeRatePercent: 31.9,
          applicableRatePercent: 31.9,
          tufeReferenceMonth:
              '${now.year - 1}-${renewal.month.toString().padLeft(2, '0')}',
          increaseDate: DateTime(now.year - 1, renewal.month, renewal.day),
        ),
      ],
    ),
    isPro: true,
  );
}
