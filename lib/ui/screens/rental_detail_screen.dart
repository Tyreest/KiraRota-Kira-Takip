import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/dashboard_logic.dart';
import '../../domain/models/rental.dart';
import '../../providers/app_providers.dart';
import '../../services/pdf_report_service.dart';
import '../widgets/design_system.dart';
import '../widgets/pdf_export_sheet.dart';
import '../widgets/pro_paywall.dart';
import 'calculate_screen.dart';
import 'rental_edit_screen.dart';
import 'reminder_screen.dart';

class RentalDetailScreen extends ConsumerWidget {
  const RentalDetailScreen({super.key, required this.rentalId});

  final String rentalId;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kira kaydını sil'),
        content: const Text(
          'Bu kayıt ve bağlı hesaplama geçmişi silinecek. Emin misiniz?',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Vazgeç'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                      foregroundColor: Theme.of(ctx).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sil'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(rentalsProvider.notifier).delete(rentalId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _openPdfFromLatestSnapshot(
    BuildContext context,
    WidgetRef ref,
    Rental rental,
  ) async {
    if (!ref.read(hasProFeaturesProvider)) {
      await showProPaywall(context, ref);
      return;
    }
    final snapshot = rental.latestCalculation;
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF için önce bir dönem hesaplaması kaydedin'),
        ),
      );
      return;
    }

    final result = snapshot.toPdfCalculationResult(
      contractStartDate: rental.contractStartDate,
    );
    final pdf = ref.read(pdfReportServiceProvider);
    final rentalName = rental.propertyName;
    if (!context.mounted) return;

    await showPdfExportSheet(
      context,
      onSaveToDevice: () async {
        try {
          final save = await pdf.saveCalculationToDevice(
            result,
            rentalName: rentalName,
          );
          if (!context.mounted) return;
          switch (save.outcome) {
            case PdfSaveOutcome.saved:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF cihazınıza kaydedildi')),
              );
            case PdfSaveOutcome.cancelled:
              break;
            case PdfSaveOutcome.failed:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF kaydedilemedi: ${save.error ?? ''}'),
                ),
              );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('PDF oluşturulamadı: $e')));
          }
        }
      },
      onShare: () async {
        try {
          await pdf.shareCalculation(result, rentalName: rentalName);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('PDF oluşturulamadı: $e')));
          }
        }
      },
    );
  }

  String _shareText(Rental rental, EstimatedRenewalRent? estimate) {
    final days = daysUntilRenewal(rental.increaseDate);
    final daysLine = days < 0
        ? 'Yenileme geçti'
        : days == 0
        ? 'Yenileme: bugün'
        : 'Yenilemeye $days gün kaldı';

    final b = StringBuffer()
      ..writeln('${AppConstants.brandName} — kira özeti')
      ..writeln(rental.propertyName)
      ..writeln('Mevcut kira: ${formatMoney(rental.currentRent)}')
      ..writeln('Yenileme: ${formatDateTr(rental.increaseDate)}')
      ..writeln(daysLine);

    if (estimate != null) {
      if (estimate.isOfficialForPeriod) {
        b.writeln(
          'Hesaplanan yeni kira: ${formatMoney(estimate.amount)} '
          '(${formatPercent(estimate.ratePercent)})',
        );
      } else {
        b.writeln(
          'Tahmini yeni kira: ${formatMoney(estimate.amount)} '
          '(son bilinen TÜFE ${formatPercent(estimate.ratePercent)})',
        );
      }
    }

    if (rental.address != null && rental.address!.trim().isNotEmpty) {
      b.writeln('Adres: ${rental.address}');
    }
    b
      ..writeln()
      ..writeln(AppConstants.disclaimerShort);
    return b.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentals = ref.watch(rentalsProvider);
    Rental? rental;
    for (final r in rentals) {
      if (r.id == rentalId) {
        rental = r;
        break;
      }
    }
    final isPro = ref.watch(hasProFeaturesProvider);
    final ratesAsync = ref.watch(ratesProvider);

    if (rental == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kira')),
        body: const Center(child: Text('Kayıt bulunamadı')),
      );
    }
    final active = rental;

    // Tahmin yalnızca okuma — history’ye yazılmaz.
    final estimate = ratesAsync.maybeWhen(
      data: (loaded) =>
          DashboardLogic.estimateNewRent(rental: active, bundle: loaded.bundle),
      orElse: () => null,
    );

    final days = daysUntilRenewal(active.increaseDate);
    final daysLabel = days < 0
        ? 'Yenileme geçti'
        : days == 0
        ? 'Bugün'
        : '$days gün kaldı';

    final history = isPro
        ? active.history
        : active.history.take(AppConstants.freeHistoryLimit).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kira Detayı'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _confirmDelete(context, ref);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem<String>(value: 'delete', child: Text('Kayıt sil')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: scrollablePagePadding(
          context,
          horizontal: AppSpace.margin,
          top: AppSpace.sm,
          bottom: AppSpace.md,
        ),
        children: [
          SoftCard(
            padding: EdgeInsets.zero,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(AppRadii.xl),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active.propertyName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (active.address != null &&
                          active.address!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                active.address!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpace.md),
                      Text(
                        'Mevcut kira',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              formatMoney(active.currentRent),
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: days < 0
                                  ? AppColors.errorContainer
                                  : AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 14,
                                  color: days < 0
                                      ? AppColors.error
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  daysLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: days < 0
                                            ? AppColors.error
                                            : AppColors.primary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Yenileme: ${formatDateTr(active.increaseDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (estimate != null) ...[
                        const SizedBox(height: AppSpace.md),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpace.md),
                        Text(
                          estimate.isOfficialForPeriod
                              ? 'Hesaplanan yeni kira'
                              : 'Tahmini yeni kira',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatMoney(estimate.amount),
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          estimate.isOfficialForPeriod
                              ? '${formatMonthKey(estimate.rateMonthKey)} · '
                                    '${formatPercent(estimate.ratePercent)}'
                              : 'Son bilinen TÜFE ${formatPercent(estimate.ratePercent)} · '
                                    '${formatMonthKey(estimate.rateMonthKey)} (tahmini)',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                        if (!estimate.isOfficialForPeriod) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Bu tutar tahminidir; resmî dönem oranı yayınlanınca değişebilir.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CalculateScreen(rentalId: active.id),
                ),
              );
            },
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Yeni dönemi hesapla'),
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Düzenle',
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => RentalEditScreen(rentalId: active.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _ActionTile(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'PDF',
                  showPro: !isPro,
                  onTap: () => _openPdfFromLatestSnapshot(context, ref, active),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _ActionTile(
                  icon: Icons.share_outlined,
                  label: 'Paylaş',
                  onTap: () {
                    SharePlus.instance.share(
                      ShareParams(text: _shareText(active, estimate)),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _ActionTile(
                  icon: Icons.notifications_active_outlined,
                  label: 'Hatırlatma',
                  showPro: !isPro,
                  onTap: () {
                    if (!isPro) {
                      showProPaywall(context, ref);
                      return;
                    }
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ReminderScreen(rentalId: active.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Hesaplama geçmişi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            isPro
                ? 'Bu kiraya ait kayıtlı hesaplamalar'
                : 'Ücretsiz: son ${AppConstants.freeHistoryLimit} hesaplama',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            SoftCard(
              child: Text(
                'Henüz bu kiraya ait hesaplama yok. '
                '“Yeni dönemi hesapla” ile ilk kaydı oluşturun.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            if (history.length >= 3) ...[
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kira geçmişi',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _HistoryMiniChartPainter(
                          values: history.reversed
                              .map((s) => s.calculatedRent)
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < history.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _HistoryTile(snapshot: history[i]),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sözleşme bilgileri',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.md),
                _InfoRow(
                  label: 'Sözleşme başlangıcı',
                  value: formatDateTr(active.contractStartDate),
                ),
                _InfoRow(
                  label: 'Yenileme tarihi',
                  value: formatDateTr(active.increaseDate),
                ),
                if (active.tenantName != null &&
                    active.tenantName!.trim().isNotEmpty)
                  _InfoRow(label: 'Kiracı', value: active.tenantName!),
                if (active.ownerName != null &&
                    active.ownerName!.trim().isNotEmpty)
                  _InfoRow(label: 'Ev sahibi', value: active.ownerName!),
                if (active.address != null && active.address!.trim().isNotEmpty)
                  _InfoRow(label: 'Adres', value: active.address!),
                if (active.contractIncreaseRate != null)
                  _InfoRow(
                    label: 'Sözleşme artış oranı',
                    value: formatPercent(active.contractIncreaseRate!),
                  ),
                _InfoRow(
                  label: 'Hatırlatma',
                  value: active.reminder.enabled ? 'Açık' : 'Kapalı',
                ),
                if (active.notes != null &&
                    active.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notlar', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    active.notes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showPro = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showPro;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLow,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: SizedBox(
          height: 72,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.onSurfaceVariant, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (showPro)
                const Positioned(
                  right: 4,
                  top: 4,
                  child: ProBadge(compact: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.snapshot});

  final RentalCalculationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDateTr(snapshot.calculatedAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatMoney(snapshot.oldRent)} → ${formatMoney(snapshot.calculatedRent)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatMonthKey(snapshot.tufeReferenceMonth)} · '
            '${formatPercent(snapshot.applicableRatePercent)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Basit mini çizgi grafik — yalnızca görsel özet; veri mutasyonu yok.
class _HistoryMiniChartPainter extends CustomPainter {
  _HistoryMiniChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV).abs() < 0.01 ? 1.0 : (maxV - minV);
    final padY = 12.0;
    final padX = 8.0;
    final usableW = size.width - padX * 2;
    final usableH = size.height - padY * 2;

    final baseline = Paint()
      ..color = AppColors.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(padX, size.height / 2),
      Offset(size.width - padX, size.height / 2),
      baseline,
    );

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = padX + usableW * i / (values.length - 1);
      final t = (values[i] - minV) / span;
      final y = padY + usableH * (1 - t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final line = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);

    final fill = Paint()..color = AppColors.secondaryContainer;
    for (var i = 0; i < values.length; i++) {
      final x = padX + usableW * i / (values.length - 1);
      final t = (values[i] - minV) / span;
      final y = padY + usableH * (1 - t);
      final isLast = i == values.length - 1;
      canvas.drawCircle(Offset(x, y), isLast ? 5 : 3.5, fill);
      canvas.drawCircle(
        Offset(x, y),
        isLast ? 5 : 3.5,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryMiniChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
