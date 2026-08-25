import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/dashboard_logic.dart';
import '../../domain/models/calculation.dart';
import '../../domain/models/rental.dart';
import '../../domain/models/tufe_rate.dart';
import '../../providers/app_providers.dart';
import '../../services/ads_service.dart';
import '../../services/external_link_service.dart';
import '../../services/pdf_report_service.dart';
import '../widgets/design_system.dart';
import '../widgets/pdf_export_sheet.dart';
import '../widgets/pro_paywall.dart';
import 'rental_detail_screen.dart';

class CalculateScreen extends ConsumerStatefulWidget {
  const CalculateScreen({
    super.key,
    this.initialRenewal,
    this.initialContractStart,
    this.initialRentText,
    this.rentalId,
  });

  /// Test / önizleme için başlangıç yenileme tarihi.
  final DateTime? initialRenewal;

  /// Test / önizleme için sözleşme başlangıcı.
  final DateTime? initialContractStart;

  /// Test için önceden doldurulmuş kira metni.
  final String? initialRentText;

  /// Doluysa bu kira kaydı üzerinden hesaplama (sonuçta "Yeni kirayı kaydet").
  final String? rentalId;

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
    _contractStart =
        widget.initialContractStart ??
        DateTime(now.year - 2, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFromRental());
  }

  void _hydrateFromRental() {
    final id = widget.rentalId;
    if (id == null) return;
    final rental = ref.read(rentalRepositoryProvider).findById(id);
    if (rental == null) return;
    _rentCtrl.text = rental.currentRent.toStringAsFixed(
      rental.currentRent.truncateToDouble() == rental.currentRent ? 0 : 2,
    );
    if (rental.contractIncreaseRate != null) {
      _contractRateCtrl.text = rental.contractIncreaseRate.toString();
    }
    setState(() {
      _renewal = rental.increaseDate;
      _contractStart = rental.contractStartDate;
    });
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
      helpText: 'Kira artış tarihi',
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
      helpText: 'İlk kira sözleşmesi tarihi',
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

    final sourceLabel = loaded.source == RateSource.remote
        ? 'Veriler güncel'
        : 'Yerel veri';

    final outcome = ref
        .read(calculationEngineProvider)
        .calculate(
          input: input,
          bundle: loaded.bundle,
          rateSourceLabel: sourceLabel,
        );

    if (outcome is! CalculationSuccess) {
      setState(() {
        _outcome = outcome;
        _showResult = false;
      });
      return;
    }

    // Başarılı hesap — interstitial (koşullu) sonra sonuç. Otomatik geçmiş yok.
    () async {
      final prefs = ref.read(sharedPreferencesProvider);
      final isPro = ref.read(hasProFeaturesProvider);
      await AdsService.onSuccessfulCalculation(
        prefs: prefs,
        isPro: isPro,
        onContinue: () {
          if (!mounted) return;
          setState(() {
            _outcome = outcome;
            _showResult = true;
          });
        },
      );
    }();
  }

  @override
  Widget build(BuildContext context) {
    final ratesAsync = ref.watch(ratesProvider);
    final isPro = ref.watch(hasProFeaturesProvider);
    final asStandaloneRoute = widget.rentalId != null;
    // Tab: HomeShell SafeArea + NavigationBar inset yönetir.
    // Push edilen "Yeni dönemi hesapla": sistem nav altına taşmamak için viewPadding.
    final pagePadding = asStandaloneRoute
        ? scrollablePagePadding(context, horizontal: 16, top: 8, bottom: 24)
        : const EdgeInsets.fromLTRB(16, 8, 16, 24);

    final body = ratesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Oranlar yüklenemedi: $e')),
      data: (loaded) {
        if (_showResult && _outcome is CalculationSuccess) {
          return _ResultView(
            result: (_outcome as CalculationSuccess).result,
            isPro: isPro,
            rentalId: widget.rentalId,
            hideTopBack: asStandaloneRoute,
            padding: pagePadding,
            onBack: () => setState(() => _showResult = false),
            onNeedPro: () => showProPaywall(context, ref),
          );
        }

        final missing = loaded.bundle.findByRenewalMonth(_renewalKey) == null;
        final latest = loaded.bundle.latest?.renewalMonth;

        return ListView(
          padding: pagePadding,
          children: [
            if (!asStandaloneRoute) ...[
              Text(
                'Kira Artışı Hesapla',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Manuel hesaplama için bilgileri girin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Son güncelleme: ${formatDateTr(loaded.bundle.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            SegmentedButton<PropertyType>(
              segments: const [
                ButtonSegment(
                  value: PropertyType.residential,
                  label: Text('Konut'),
                ),
                ButtonSegment(
                  value: PropertyType.commercial,
                  label: Text('İşyeri'),
                ),
              ],
              selected: {_propertyType},
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((s) {
                  if (s.contains(WidgetState.selected)) {
                    return AppColors.sageSoft;
                  }
                  return AppColors.surfaceLowest;
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                    label: 'Kira artış tarihi',
                    helperText:
                        'Yeni kira döneminin başladığı tarih. Genellikle sözleşmenizin yıl dönümüdür.',
                    valueText: formatDateTr(_renewal),
                    onTap: _pickRenewal,
                  ),
                  const SizedBox(height: 14),
                  DatePickerTile(
                    label: 'İlk kira sözleşmesi tarihi',
                    helperText:
                        'Kiracılığın ilk başladığı tarih. 5 yıl ve üzeri durumların değerlendirilmesinde kullanılır.',
                    valueText: formatDateTr(_contractStart),
                    onTap: _pickStart,
                  ),
                  const SizedBox(height: 14),
                  FieldLabel('Sözleşmedeki artış oranı (isteğe bağlı)'),
                  TextField(
                    controller: _contractRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
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
                      title:
                          '${formatMonthKey(_renewalKey)} için oran henüz yok',
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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

    if (!asStandaloneRoute) return body;

    // Rental detayından push edilen route: HomeShell Scaffold yok → theme
    // background için kendi Scaffold gerekir (aksi halde siyah Material page).
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Yeni dönemi hesapla'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_showResult) {
              setState(() => _showResult = false);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: body,
    );
  }
}

class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({
    required this.result,
    required this.isPro,
    required this.onBack,
    required this.onNeedPro,
    this.rentalId,
    this.hideTopBack = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final CalculationResult result;
  final bool isPro;
  final VoidCallback onBack;
  final VoidCallback onNeedPro;
  final String? rentalId;
  final bool hideTopBack;
  final EdgeInsets padding;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  final _requestedCtrl = TextEditingController();

  CalculationResult get result => widget.result;
  bool get isPro => widget.isPro;
  String? get rentalId => widget.rentalId;
  bool get hideTopBack => widget.hideTopBack;
  EdgeInsets get padding => widget.padding;
  VoidCallback get onBack => widget.onBack;
  VoidCallback get onNeedPro => widget.onNeedPro;

  bool get _fromRental => rentalId != null;

  @override
  void dispose() {
    _requestedCtrl.dispose();
    super.dispose();
  }

  double? get _parsedRequested {
    final raw = _requestedCtrl.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));
  }

  String get _shareText {
    final b = StringBuffer()
      ..writeln('${AppConstants.appName} — özet')
      ..writeln(
        'Kira artış tarihi: ${formatMonthKey(result.input.renewalMonthKey)}',
      )
      ..writeln('Mevcut kira: ${formatMoney(result.input.currentRent)}')
      ..writeln(
        'TÜFE esaslı azami artış oranı: ${formatPercent(result.tufeMaxRatePercent)}',
      )
      ..writeln(
        'Uygulanan oran: ${formatPercent(result.applicableRatePercent)}',
      )
      ..writeln('Hesaplanan kira: ${formatMoney(result.calculatedRent)}')
      ..writeln()
      ..writeln(AppConstants.disclaimerShort);
    return b.toString();
  }

  String _formatSignedMoney(double value) {
    if (value > 0) return '+${formatMoney(value)}';
    return formatMoney(value);
  }

  Future<void> _saveToRentals(BuildContext context, WidgetRef ref) async {
    final isPro = ref.read(hasProFeaturesProvider);
    final count = ref.read(rentalsProvider).length;
    if (!isPro && count >= AppConstants.freeRentalLimit) {
      onNeedPro();
      return;
    }

    final nameCtrl = TextEditingController();
    var role = RentalRole.tenant;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Flutter 3.44 modal sheet kenardan kenara uzanır; klavye/nav inset
        // otomatik uygulanmaz (Review Access ile aynı model).
        final keyboardInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SafeArea(
            maintainBottomViewPadding: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: StatefulBuilder(
                builder: (ctx, setModal) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Kiralarıma kaydet',
                        style: Theme.of(ctx).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<RentalRole>(
                        segments: const [
                          ButtonSegment(
                            value: RentalRole.tenant,
                            label: Text('Kiracıyım'),
                          ),
                          ButtonSegment(
                            value: RentalRole.landlord,
                            label: Text('Ev sahibiyim'),
                          ),
                        ],
                        selected: {role},
                        onSelectionChanged: (s) =>
                            setModal(() => role = s.first),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Kayıt adı',
                          hintText: 'Örn: Evim, Kadıköy Daire',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          Navigator.pop(ctx, true);
                        },
                        child: const Text('Kaydet'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true || name.isEmpty) return;

    final created = await ref
        .read(rentalsProvider.notifier)
        .createFromCalculation(displayName: name, role: role, result: result);
    if (!context.mounted) return;
    if (created == null) {
      onNeedPro();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('"$name" Kiralarıma eklendi')));
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RentalDetailScreen(rentalId: created.id),
      ),
    );
  }

  Future<void> _applyToRental(BuildContext context) async {
    final id = rentalId;
    if (id == null) return;

    final repo = ref.read(rentalRepositoryProvider);
    if (repo.wouldDuplicateApply(rentalId: id, result: result)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu dönem için aynı hesaplama zaten kayıtlı'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni kirayı kaydet'),
        content: Text(
          'Mevcut kira ${formatMoney(result.input.currentRent)} → '
          '${formatMoney(result.calculatedRent)} olarak güncellensin mi?\n\n'
          'Bu hesaplama kaydın geçmişine eklenir; sonraki artış tarihi bir yıl ileri alınır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final before = ref.read(rentalRepositoryProvider).findById(id)?.currentRent;
    final updated = await ref
        .read(rentalsProvider.notifier)
        .applyCalculation(rentalId: id, result: result);
    if (!context.mounted) return;
    if (updated == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kayıt güncellenemedi')));
      return;
    }
    // Onaysız değişmediğini doğrulamak testlerde before ile karşılaştırılır;
    // burada onay sonrası currentRent zaten yeni değer.
    assert(before == null || updated.currentRent == result.calculatedRent);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Yeni kira kaydedildi')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final requested = _parsedRequested;
    final compare = requested == null
        ? null
        : RequestedRentCompare(
            calculatedRent: result.calculatedRent,
            requestedRent: requested,
            currentRent: result.input.currentRent,
            calculatedIncreaseRatePercent: result.applicableRatePercent,
          );

    return ListView(
      padding: padding,
      children: [
        if (!hideTopBack) ...[
          Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: Text(
                  'Hesap Sonucu',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  'Hesaplanan Yeni Kira',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatMoney(result.calculatedRent),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ResultStatCell(
                      label: 'Mevcut kira',
                      value: formatMoney(result.input.currentRent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ResultStatCell(
                      label: 'TÜFE oranı',
                      value: formatPercent(result.tufeMaxRatePercent),
                      emphasize: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ResultStatCell(
                      label: 'Artış tutarı',
                      value: _formatSignedMoney(result.increaseAmount),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (result.input.contractIncreasePercent != null) ...[
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sözleşmedeki artış oranı',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  formatPercent(result.input.contractIncreasePercent!),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (result.applicableRatePercent !=
                    result.tufeMaxRatePercent) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Uygulanan oran: ${formatPercent(result.applicableRatePercent)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
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
          'Yıllık TÜFE ile 12 aylık ortalama değişim oranı aynı değildir.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                openTuikSource(context, sourceUrl: result.tuikSourceUrl),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Kaynak: TÜİK — Resmî kaynağı görüntüle'),
          ),
        ),
        const SizedBox(height: 8),
        SoftCard(
          color: AppColors.sageSoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.compare_arrows, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Başka bir kira tutarıyla karşılaştır',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const FieldLabel('Karşılaştırılacak kira'),
              TextField(
                controller: _requestedCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  prefixText: '₺ ',
                  hintText: 'Örn: 59000',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              Text(
                'Konuşulan veya teklif edilen tutarı gir.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (compare != null) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _CompareRow(
                  label: 'Hesaplanan',
                  value: formatMoney(compare.calculatedRent),
                  secondary: formatSignedPercent(
                    compare.calculatedIncreaseRatePercent,
                  ),
                ),
                const SizedBox(height: 8),
                _CompareRow(
                  label: 'Karşılaştırılan',
                  value: formatMoney(compare.comparisonRent),
                  secondary: compare.comparisonIncreasePercent == null
                      ? null
                      : formatSignedPercent(compare.comparisonIncreasePercent!),
                ),
                const SizedBox(height: 8),
                _CompareRow(
                  label: 'Fark',
                  value: _formatSignedMoney(compare.difference),
                  emphasize: true,
                ),
                if (compare.rateInsightLabel.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    compare.rateInsightLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Bu alan yalnızca karşılaştırma içindir; hesaplamayı değiştirmez ve kaydedilmez.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_fromRental) ...[
          FilledButton.icon(
            onPressed: () => _applyToRental(context),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Yeni kirayı kaydet'),
          ),
          const SizedBox(height: 8),
        ] else ...[
          FilledButton.tonalIcon(
            onPressed: () => _saveToRentals(context, ref),
            icon: const Icon(Icons.home_work_outlined),
            label: const Text('Kiralarıma kaydet'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: () =>
              SharePlus.instance.share(ShareParams(text: _shareText)),
          icon: const Icon(Icons.share_outlined),
          label: const Text('Paylaş'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _shareText));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Özet kopyalandı')));
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
                String? rentalName;
                final rid = rentalId;
                if (rid != null) {
                  rentalName = ref
                      .read(rentalRepositoryProvider)
                      .findById(rid)
                      ?.displayName;
                }
                final pdf = ref.read(pdfReportServiceProvider);
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
                            const SnackBar(
                              content: Text('PDF cihazınıza kaydedildi'),
                            ),
                          );
                        case PdfSaveOutcome.cancelled:
                          break;
                        case PdfSaveOutcome.failed:
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'PDF kaydedilemedi: ${save.error ?? ''}',
                              ),
                            ),
                          );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PDF oluşturulamadı: $e')),
                        );
                      }
                    }
                  },
                  onShare: () async {
                    try {
                      await pdf.shareCalculation(
                        result,
                        rentalName: rentalName,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('PDF oluşturulamadı: $e')),
                        );
                      }
                    }
                  },
                );
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF raporu al'),
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

class _ResultStatCell extends StatelessWidget {
  const _ResultStatCell({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: emphasize ? AppColors.sageSoft : AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.hankenGrotesk(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.value,
    this.secondary,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String? secondary;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: emphasize
                  ? GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.primaryDeep,
                    )
                  : Theme.of(context).textTheme.titleMedium,
            ),
            if (secondary != null) ...[
              const SizedBox(height: 2),
              Text(
                secondary!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
