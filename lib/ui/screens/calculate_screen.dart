import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/local_store.dart';
import '../../domain/models/calculation.dart';
import '../../domain/models/tufe_rate.dart';
import '../../providers/app_providers.dart';
import '../widgets/design_system.dart';
import '../widgets/pro_paywall.dart';

class CalculateScreen extends ConsumerStatefulWidget {
  const CalculateScreen({
    super.key,
    this.initialRenewal,
    this.initialContractStart,
    this.initialRentText,
  });

  /// Test / önizleme için başlangıç yenileme tarihi.
  final DateTime? initialRenewal;

  /// Test / önizleme için sözleşme başlangıcı.
  final DateTime? initialContractStart;

  /// Test için önceden doldurulmuş kira metni.
  final String? initialRentText;

  @override
  ConsumerState<CalculateScreen> createState() => _CalculateScreenState();
}

class _CalculateScreenState extends ConsumerState<CalculateScreen> {
  late final TextEditingController _rentCtrl;
  final _contractRateCtrl = TextEditingController();
  PropertyType _propertyType = PropertyType.residential;
  late DateTime _renewal;
  late DateTime _contractStart;
  CalculationOutcome? _outcome;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _rentCtrl = TextEditingController(text: widget.initialRentText ?? '');
    final now = DateTime.now();
    _renewal = widget.initialRenewal ?? DateTime(now.year, now.month, now.day);
    _contractStart = widget.initialContractStart ??
        DateTime(now.year - 2, now.month, now.day);
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _contractRateCtrl.dispose();
    super.dispose();
  }

  String get _renewalKey =>
      '${_renewal.year}-${_renewal.month.toString().padLeft(2, '0')}';

  Future<void> _pickRenewal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewal,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      helpText: 'Yenileme tarihi',
    );
    if (picked != null) {
      setState(() {
        _renewal = picked;
        _outcome = null;
        _showResult = false;
      });
    }
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _contractStart,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Sözleşme başlangıcı',
    );
    if (picked != null) setState(() => _contractStart = picked);
  }

  void _run(LoadedRates loaded) {
    final rentRaw = _rentCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    final rent = double.tryParse(rentRaw);
    double? contractRate;
    final rawContract = _contractRateCtrl.text.trim();
    if (rawContract.isNotEmpty) {
      contractRate = double.tryParse(rawContract.replaceAll(',', '.'));
      if (contractRate == null) {
        setState(
          () => _outcome = CalculationInvalidInput(
            'Sözleşme artış oranı sayı olmalıdır.',
          ),
        );
        return;
      }
    }

    final input = CalculationInput(
      currentRent: rent ?? -1,
      renewalYear: _renewal.year,
      renewalMonth: _renewal.month,
      renewalDay: _renewal.day,
      contractStart: _contractStart,
      contractIncreasePercent: contractRate,
      propertyType: _propertyType,
    );

    final sourceLabel =
        loaded.source == RateSource.remote ? 'Uzaktan güncel' : 'Offline';

    final outcome = ref.read(calculationEngineProvider).calculate(
          input: input,
          bundle: loaded.bundle,
          rateSourceLabel: sourceLabel,
        );

    setState(() {
      _outcome = outcome;
      _showResult = outcome is CalculationSuccess;
    });

    if (outcome is CalculationSuccess) {
      ref.read(historyProvider.notifier).add(
            HistoryEntry.fromResult(outcome.result),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(ratesProvider);
    final isPro = ref.watch(isProProvider);

    return ratesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Oranlar yüklenemedi: $e')),
      data: (loaded) {
        if (_showResult && _outcome is CalculationSuccess) {
          return _ResultView(
            result: (_outcome as CalculationSuccess).result,
            isPro: isPro,
            onBack: () => setState(() => _showResult = false),
            onNeedPro: () => showProPaywall(context, ref),
          );
        }

        final missing = loaded.bundle.findByRenewalMonth(_renewalKey) == null;
        final latest = loaded.bundle.latest?.renewalMonth;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Son güncelleme: ${formatDateTr(loaded.bundle.updatedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<PropertyType>(
              segments: const [
                ButtonSegment(
                  value: PropertyType.residential,
                  label: Text('Konut'),
                ),
                ButtonSegment(
                  value: PropertyType.commercial,
                  label: Text('Çatılı işyeri'),
                ),
              ],
              selected: {_propertyType},
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return AppColors.surfaceLowest;
                  }
                  return AppColors.sageSoft;
                }),
              ),
              onSelectionChanged: (s) =>
                  setState(() => _propertyType = s.first),
            ),
            const SizedBox(height: 16),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel('Mevcut aylık kira'),
                  TextField(
                    controller: _rentCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '₺ ',
                      hintText: 'Örn: 25000',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DatePickerTile(
                    label: 'Yenileme tarihi',
                    valueText: formatDateTr(_renewal),
                    onTap: _pickRenewal,
                  ),
                  const SizedBox(height: 14),
                  DatePickerTile(
                    label: 'Sözleşme başlangıç tarihi',
                    valueText: formatDateTr(_contractStart),
                    onTap: _pickStart,
                  ),
                  const SizedBox(height: 14),
                  FieldLabel('Sözleşmedeki artış oranı % (Opsiyonel)'),
                  TextField(
                    controller: _contractRateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: 'Örn: 25',
                      suffixText: '%',
                    ),
                  ),
                  if (missing) ...[
                    const SizedBox(height: 14),
                    InfoBanner(
                      title: '${formatMonthKey(_renewalKey)} için oran henüz yok',
                      message:
                          'Eski oran bu aya uygulanamaz.'
                          '${latest != null ? ' Son açıklanan oran: ${formatMonthKey(latest)}.' : ''}\n\n'
                          'Not: TÜİK verileri genellikle her ayın ilk günlerinde güncellenir.',
                      icon: Icons.info_outline,
                    ),
                  ],
                  if (_outcome is CalculationInvalidInput) ...[
                    const SizedBox(height: 12),
                    Text(
                      (_outcome as CalculationInvalidInput).message,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: missing ? null : () => _run(loaded),
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: AppColors.surfaceContainer,
                      disabledForegroundColor: AppColors.outline,
                    ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Hesapla'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const InfoBanner(
              message:
                  'Hesaplama, açıklanan en güncel TÜFE oranlarına dayanmaktadır.',
            ),
            const SizedBox(height: 12),
            Text(
              AppConstants.disclaimerShort,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}

class _ResultView extends ConsumerWidget {
  const _ResultView({
    required this.result,
    required this.isPro,
    required this.onBack,
    required this.onNeedPro,
  });

  final CalculationResult result;
  final bool isPro;
  final VoidCallback onBack;
  final VoidCallback onNeedPro;

  String get _shareText {
    final b = StringBuffer()
      ..writeln('Kira Artışı Hesapla — özet')
      ..writeln('Yenileme: ${formatMonthKey(result.input.renewalMonthKey)}')
      ..writeln('Mevcut kira: ${formatMoney(result.input.currentRent)}')
      ..writeln(
        'TÜFE esaslı azami artış oranı: ${formatPercent(result.tufeMaxRatePercent)}',
      )
      ..writeln(
        'Uygulanan oran: ${formatPercent(result.applicableRatePercent)}',
      )
      ..writeln(
        'Bu orana göre hesaplanan kira: ${formatMoney(result.calculatedRent)}',
      )
      ..writeln()
      ..writeln(AppConstants.disclaimerShort);
    return b.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: SectionLabel('Bu orana göre hesaplanan kira'),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            formatMoney(result.calculatedRent),
            style: GoogleFonts.montserrat(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDeep,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sageSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Artış: +${formatMoney(result.increaseAmount)}',
                  style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'TÜFE esaslı azami artış oranı',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          formatPercent(result.tufeMaxRatePercent),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.onSurface,
              ),
        ),
        if (result.input.contractIncreasePercent != null) ...[
          const SizedBox(height: 12),
          Text(
            'Sözleşmedeki artış oranı',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            formatPercent(result.input.contractIncreasePercent!),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
        ],
        if (result.contractCompare == ContractCompareKind.contractHigher) ...[
          const SizedBox(height: 14),
          InfoBanner(
            tone: InfoBannerTone.amber,
            icon: Icons.warning_amber_rounded,
            title: 'Artış Oranı Bilgilendirmesi',
            message:
                'Sözleşmenizdeki ${formatPercent(result.input.contractIncreasePercent!)} oranı, '
                'TÜFE esaslı azami oran olan ${formatPercent(result.tufeMaxRatePercent)} değerini aşıyor. '
                'Hesap bu azami orana göre gösterildi.',
          ),
        ],
        if (result.contractCompare == ContractCompareKind.contractLower) ...[
          const SizedBox(height: 14),
          InfoBanner(
            tone: InfoBannerTone.sage,
            title: 'Sözleşme oranı',
            message:
                'Sözleşmenizdeki ${formatPercent(result.input.contractIncreasePercent!)} oranı '
                'azami oranın altında. Uygulanan oran: ${formatPercent(result.applicableRatePercent)}.',
          ),
        ],
        if (result.isFiveYearsOrMore) ...[
          const SizedBox(height: 12),
          InfoBanner(
            tone: InfoBannerTone.sage,
            title: '5 Yıl Notu',
            message: AppConstants.fiveYearWarning,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'TÜİK açıklama tarihi: ${formatDateTr(result.tuikReleaseDate)}\n'
          'Son güncelleme: ${formatDateTr(result.datasetUpdatedAt)}\n'
          'Oran kaynağı: ${result.rateSourceLabel}\n'
          'Yıllık TÜFE ile 12 aylık ortalama değişim oranı aynı değildir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => SharePlus.instance.share(
            ShareParams(text: _shareText),
          ),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Paylaş'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _shareText));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Özet kopyalandı')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Kopyala'),
        ),
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            FilledButton.icon(
              onPressed: () async {
                if (!isPro) {
                  onNeedPro();
                  return;
                }
                try {
                  await ref
                      .read(pdfReportServiceProvider)
                      .shareCalculation(result);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF oluşturulamadı: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF Raporu Al'),
            ),
            if (!isPro)
              const Positioned(
                right: 10,
                top: -8,
                child: ProBadge(compact: true),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppConstants.disclaimerShort,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
