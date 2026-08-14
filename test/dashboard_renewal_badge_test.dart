import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kira_artisi_hesapla/core/theme.dart';
import 'package:kira_artisi_hesapla/domain/models/rental.dart';
import 'package:kira_artisi_hesapla/ui/screens/home_dashboard_screen.dart';

Rental _rental(DateTime next) {
  return Rental(
    id: 'x',
    role: RentalRole.tenant,
    displayName: 'Ev',
    currentRent: 39000,
    contractStartDate: DateTime(2024, 7, 1),
    increaseDate: next,
    renewalResolved: true,
    createdAt: DateTime(2026, 8, 1),
    updatedAt: DateTime(2026, 8, 1),
  );
}

void main() {
  final now = DateTime(2026, 8, 14);

  test('>30 gün → surface / primary badge (hero)', () {
    final status = renewalStatusOf(_rental(DateTime(2027, 7, 1)), now: now);
    expect(status.daysUntil, 321);
    expect(status.shortLabel, isNot(contains('geçti')));
    final badge = dashboardRenewalBadgeColors(status);
    expect(badge.background, AppColors.surfaceLowest);
    expect(badge.foreground, AppColors.primary);
  });

  test('8–30 gün → amber badge', () {
    final status = renewalStatusOf(_rental(DateTime(2026, 9, 3)), now: now);
    expect(status.daysUntil, 20);
    final badge = dashboardRenewalBadgeColors(status);
    expect(badge.background, AppColors.amberSoft);
    expect(badge.foreground, const Color(0xFF92400E));
  });

  test('1–7 gün → güçlü amber', () {
    final status = renewalStatusOf(_rental(DateTime(2026, 8, 18)), now: now);
    expect(status.daysUntil, 4);
    final badge = dashboardRenewalBadgeColors(status);
    expect(badge.background, AppColors.amberSoft);
    expect(badge.foreground, AppColors.amber);
  });

  test('geçmiş pending → Yenileme geçti + red', () {
    final status = renewalStatusOf(_rental(DateTime(2026, 7, 1)), now: now);
    expect(status.isOverdue, isTrue);
    expect(status.shortLabel, 'Yenileme geçti');
    final badge = dashboardRenewalBadgeColors(status);
    expect(badge.background, AppColors.errorContainer);
    expect(badge.foreground, AppColors.error);
  });
}
