import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/calculation_engine.dart';
import '../../domain/dashboard_logic.dart';
import '../../domain/models/calculation.dart';
import '../../domain/models/rental.dart';
import '../../domain/models/tufe_rate.dart';
import '../../providers/app_providers.dart';
import '../../services/ads_service.dart';
import '../../services/pdf_report_service.dart';
import '../widgets/calculation_info_sheet.dart';
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
  final _forecastRateCtrl = TextEditingController();
  PropertyType _propertyType = PropertyType.residential;
  late DateTime _renewal;
  late DateTime _contractStart;
  CalculationOutcome? _outcome;
  bool _showResult = false;
  String? _selectedRentalId;

  /// Resmî oran yokken: null = henüz seçilmedi.
  RateBasisKind? _forecastChoice;

  @override
  void initState() {
    super.initState();
    _selectedRentalId = widget.rentalId;
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
    _fillFromRental(rental, notify: false);
  }

  void _fillFromRental(Rental rental, {bool notify = true}) {
    _rentCtrl.text = formatMoneyForEdit(rental.currentRent);
    if (rental.contractIncreaseRate != null) {
      _contractRateCtrl.text = rental.contractIncreaseRate.toString();
    } else {
      _contractRateCtrl.clear();
    }
    setState(() {
      _selectedRentalId = rental.id;
      _renewal = rental.nextRenewalDate;
      _contractStart = rental.contractStartDate;
      _outcome = null;
      _showResult = false;
      _forecastChoice = null;
      _forecastRateCtrl.clear();
    });
    if (notify && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${rental.displayName} bilgileri yüklendi'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showForecastInfoSheet(BuildContext context, String renewalKey) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatMonthKey(renewalKey)} Tahmini Hesaplama',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Bu yenileme döneminde kullanılacak resmî TÜFE oranı henüz TÜİK tarafından açıklanmamıştır. '
                'Dilerseniz son açıklanan oranla veya kendi belirleyeceğiniz bir oranla tahmini hesaplama yapabilirsiniz. '
                'Resmî oran açıklandığında kesin hesaplama yapılması önerilir.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Anladım'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRentalPicker(List<Rental> rentals) {
    if (rentals.isEmpty) return;
    if (rentals.length == 1) {
      _fillFromRental(rentals.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        maintainBottomViewPadding: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Kayıtlı Kiradan Doldur',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Seçilen kiranın mevcut tutarı, artış tarihi ve sözleşme bilgileri forma doldurulur.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: rentals.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = rentals[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceLow,
                        child: Icon(
                          r.role == RentalRole.landlord
                              ? Icons.real_estate_agent_outlined
                              : Icons.home_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        r.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${formatMoney(r.currentRent)} · Yenileme: ${formatDateTr(r.nextRenewalDate)} (${r.role.labelTr})',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.pop(ctx);
                        _fillFromRental(r);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _contractRateCtrl.dispose();
    _forecastRateCtrl.dispose();
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
        _forecastChoice = null;
        _forecastRateCtrl.clear();
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

  double? _parseForecastRate() {
    final raw = _forecastRateCtrl.text.trim();
    if (raw.isEmpty) return null;
    final v = double.tryParse(raw.replaceAll(',', '.'));
    if (v == null || !v.isFinite || v < 0) return null;
    if (v > CalculationEngine.maxUserForecastRatePercent) return null;
    return v;
  }

  void _run(LoadedRates loaded) {
    final parsed = parseMoneyInput(_rentCtrl.text);
    if (!parsed.isOk || parsed.value == null || parsed.value! <= 0) {
      setState(
        () => _outcome = CalculationInvalidInput(
          parsed.message ?? 'Kira tutarı 0’dan büyük olmalıdır.',
        ),
      );
      return;
    }
    final rent = parsed.value!;
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
      currentRent: rent,
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

    final missing =
        loaded.bundle.findByRenewalMonth(input.renewalMonthKey) == null;
    RateBasisKind? forecastBasis;
    double? userForecast;
    if (missing) {
      forecastBasis = _forecastChoice;
      if (forecastBasis == RateBasisKind.estimatedUserProvided) {
        userForecast = _parseForecastRate();
        if (userForecast == null) {
          setState(
            () => _outcome = CalculationInvalidInput(
              'Geçerli bir tahmini oran girin (örn: 25 veya 25,5).',
            ),
          );
          return;
        }
      } else if (forecastBasis != RateBasisKind.estimatedLatestOfficial) {
        setState(
          () => _outcome = CalculationInvalidInput(
            'Tahmini hesaplama için bir yöntem seçin.',
          ),
        );
        return;
      }
    }

    final outcome = ref
        .read(calculationEngineProvider)
        .calculate(
          input: input,
          bundle: loaded.bundle,
          rateSourceLabel: sourceLabel,
          forecastBasis: forecastBasis,
          userForecastRatePercent: userForecast,
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
    final rentals = ref.watch(rentalsProvider);
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
            rentalId: widget.rentalId ?? _selectedRentalId,
            hideTopBack: asStandaloneRoute,
            padding: pagePadding,
            onBack: () => setState(() => _showResult = false),
            onNeedPro: () => showProPaywall(context, ref),
          );
        }

        final missing = loaded.bundle.findByRenewalMonth(_renewalKey) == null;
        final latestRate = loaded.bundle.latest;
        final unsupportedResidential =
            _propertyType == PropertyType.residential &&
            ResidentialRentCapWindow.contains(_renewal);
        // Desteklenmeyen tarihsel dönem: tahmin seçenekleri gösterme.
        final showForecast = missing && !unsupportedResidential;

        bool canRun;
        if (unsupportedResidential) {
          canRun = false;
        } else if (!missing) {
          canRun = true;
        } else if (_forecastChoice == RateBasisKind.estimatedLatestOfficial) {
          canRun = latestRate != null;
        } else if (_forecastChoice == RateBasisKind.estimatedUserProvided) {
          canRun = _parseForecastRate() != null;
        } else {
          canRun = false;
        }

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
              const SizedBox(height: 14),
              if (rentals.isNotEmpty) ...[
                if (_selectedRentalId != null) ...[
                  Builder(
                    builder: (context) {
                      final selected = rentals
                          .where((r) => r.id == _selectedRentalId)
                          .firstOrNull;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.sageSoft,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${selected?.displayName ?? 'Kayıtlı kira'} bilgileri dolduruldu',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryDeep,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Seçimi kaldır',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _selectedRentalId = null),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _showRentalPicker(rentals),
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(
                        rentals.length == 1
                            ? 'Kayıtlı kiradan doldur (${rentals.first.displayName})'
                            : 'Kayıtlı kiradan doldur (${rentals.length})',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
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
              onSelectionChanged: (s) => setState(() {
                _propertyType = s.first;
                _outcome = null;
                _showResult = false;
                _forecastChoice = null;
                _forecastRateCtrl.clear();
              }),
            ),
            if (_propertyType == PropertyType.commercial) ...[
              const SizedBox(height: 8),
              const InfoBanner(
                message:
                    'İşyeri seçimi aynı TÜFE azami oran formülünü kullanır; '
                    'ayrı bir hesap motoru yoktur. Geçici konut tavanı bu seçimde uygulanmaz.',
              ),
            ],
            if (_propertyType == PropertyType.residential &&
                ResidentialRentCapWindow.contains(_renewal)) ...[
              const SizedBox(height: 8),
              const InfoBanner(
                tone: InfoBannerTone.amber,
                message:
                    'Seçilen yenileme tarihi, konut için geçici yasal artış '
                    'sınırı dönemine (11.06.2022–30.06.2024) denk geliyor. '
                    'Bu dönem için uygulama TÜFE hesabı üretmez.',
              ),
            ],
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
                    valueText: formatDateTr(_renewal),
                    onTap: _pickRenewal,
                  ),
                  const SizedBox(height: 14),
                  DatePickerTile(
                    label: 'İlk kira sözleşmesi tarihi',
                    helperText: '5 yılı aşan sözleşmeler için gereklidir.',
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
                  if (showForecast) ...[
                    const SizedBox(height: 14),
                    SoftCard(
                      color: AppColors.sageSoft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${formatMonthKey(_renewalKey)} oranı henüz açıklanmadı',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.info_outline,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                tooltip: 'Tahmin yöntemi hakkında bilgi',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showForecastInfoSheet(context, _renewalKey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RadioGroup<RateBasisKind>(
                            groupValue: _forecastChoice,
                            onChanged: (v) {
                              if (v == null) return;
                              if (v == RateBasisKind.estimatedLatestOfficial &&
                                  latestRate == null) {
                                return;
                              }
                              setState(() {
                                _forecastChoice = v;
                                _outcome = null;
                              });
                            },
                            child: Column(
                              children: [
                                RadioListTile<RateBasisKind>(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  value: RateBasisKind.estimatedLatestOfficial,
                                  enabled: latestRate != null,
                                  title: const Text(
                                    'Son açıklanan oranla tahmin et',
                                  ),
                                  subtitle: latestRate == null
                                      ? const Text('Kullanılabilir oran yok')
                                      : Text(
                                          '${formatPercent(latestRate.ratePercent)} · '
                                          '${formatMonthKey(latestRate.renewalMonth)}',
                                        ),
                                ),
                                RadioListTile<RateBasisKind>(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  value: RateBasisKind.estimatedUserProvided,
                                  title: const Text(
                                    'Kendi oranımı kullan',
                                  ),
                                  subtitle: const Text(
                                    'Senaryo oranı',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_forecastChoice ==
                              RateBasisKind.estimatedUserProvided) ...[
                            const SizedBox(height: 4),
                            TextField(
                              controller: _forecastRateCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Örn: 25',
                                suffixText: '%',
                                labelText: 'Tahmini oran',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (missing && unsupportedResidential) ...[
                    const SizedBox(height: 14),
                    InfoBanner(
                      title:
                          '${formatMonthKey(_renewalKey)} için oran henüz yok',
                      message:
                          'Bu tarih desteklenmeyen konut dönemiyle çakışıyor; '
                          'tahmini hesaplama da yapılamaz.',
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
                  if (_outcome is CalculationUnsupportedPeriod) ...[
                    const SizedBox(height: 12),
                    InfoBanner(
                      tone: InfoBannerTone.amber,
                      message:
                          (_outcome as CalculationUnsupportedPeriod).message,
                    ),
                  ],
                  if (_outcome is CalculationRateMissing && !showForecast) ...[
                    const SizedBox(height: 12),
                    InfoBanner(
                      message:
                          '${formatMonthKey((_outcome as CalculationRateMissing).requestedMonth)} '
                          'için oran bulunamadı.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: canRun ? () => _run(loaded) : null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: AppColors.surfaceContainer,
                      disabledForegroundColor: AppColors.outline,
                    ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(showForecast ? 'Tahmini hesapla' : 'Hesapla'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InfoBanner(
              message: showForecast
                  ? 'Tahmini hesaplama resmi TÜFE verisi değildir; sonuç kiraya uygulanmaz.'
                  : 'Hesaplama, açıklanan en güncel TÜFE oranlarına dayanmaktadır.',
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
  bool _applyInFlight = false;
  bool _compareExpanded = false;

  void _showForecastNotApplicableSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        maintainBottomViewPadding: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tahmini Sonuç Bilgisi',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '• Seçilen yenileme dönemi için resmî TÜFE kira artış oranı henüz TÜİK tarafından açıklanmamıştır.\n\n'
                '• Bu nedenle hesaplanan tutar bir tahmin niteliğindedir; gerçek kira sözleşmesine veya kira kaydına uygulanamaz.\n\n'
                '• Resmî oran açıklandığında, güncel TÜFE verisi ile yeniden hesaplama yapılması gerekir.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anladım'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEstimatedResultDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tahmini Hesaplama Detayı',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                result.rateBasis == RateBasisKind.estimatedLatestOfficial
                    ? '${formatMonthKey(result.input.renewalMonthKey)} resmî kira artış oranı henüz açıklanmadığı için '
                      'son açıklanan ${formatPercent(result.tufeMaxRatePercent)} oranı kullanılmıştır. '
                      'Resmî oran açıklandığında sonuç değişebilir.\n\n'
                      'Kullanılan tahmini oran: ${formatPercent(result.tufeMaxRatePercent)}'
                      '${result.estimateSourceMonthKey != null ? '\nSon resmî dönem: ${formatMonthKey(result.estimateSourceMonthKey!)}' : ''}'
                    : '${formatPercent(result.tufeMaxRatePercent)} oranı tarafınızdan tahmini senaryo olarak girilmiştir. '
                      'Bu oran resmî TÜFE verisi değildir.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
    final parsed = parseMoneyInput(raw);
    if (!parsed.isOk || parsed.value == null || parsed.value! <= 0) return null;
    return parsed.value;
  }

  String get _shareText {
    final b = StringBuffer()
      ..writeln(
        result.isEstimated
            ? '${AppConstants.appName} — tahmini hesaplama özeti'
            : '${AppConstants.appName} — özet',
      )
      ..writeln(
        'Kira artış tarihi: ${formatMonthKey(result.input.renewalMonthKey)}',
      )
      ..writeln('Mevcut kira: ${formatMoney(result.input.currentRent)}');
    if (result.isEstimated) {
      b.writeln(
        'Bu bir tahmini hesaplamadır; resmi TÜFE oranı henüz açıklanmamıştır.',
      );
      switch (result.rateBasis) {
        case RateBasisKind.estimatedLatestOfficial:
          b.writeln(
            'Kullanılan tahmini oran: ${formatPercent(result.tufeMaxRatePercent)}'
            '${result.estimateSourceMonthKey != null ? ' (son resmi dönem: ${formatMonthKey(result.estimateSourceMonthKey!)})' : ''}',
          );
        case RateBasisKind.estimatedUserProvided:
          b.writeln(
            'Kullanıcı tahmini oranı: ${formatPercent(result.tufeMaxRatePercent)} '
            '(resmi TÜFE verisi değildir)',
          );
        case RateBasisKind.official:
          break;
      }
    } else {
      b.writeln(
        'TÜFE esaslı azami artış oranı: ${formatPercent(result.tufeMaxRatePercent)}',
      );
    }
    b
      ..writeln(
        'Uygulanan oran: ${formatPercent(result.applicableRatePercent)}',
      )
      ..writeln(
        result.isEstimated
            ? 'Tahmini kira: ${formatMoney(result.calculatedRent)}'
            : 'Hesaplanan kira: ${formatMoney(result.calculatedRent)}',
      )
      ..writeln()
      ..writeln(AppConstants.disclaimerShort);
    return b.toString();
  }

  String _formatSignedMoney(double value) {
    if (value > 0) return '+${formatMoney(value)}';
    return formatMoney(value);
  }

  Future<void> _saveToRentals(BuildContext context, WidgetRef ref) async {
    if (result.isEstimated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tahmini sonuç kiraya kaydedilemez. Resmi oran açıklandığında hesaplayın.',
          ),
        ),
      );
      return;
    }
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
                      const SizedBox(height: 8),
                      Text(
                        'Kayıt, mevcut kira tutarıyla oluşturulur '
                        '(${formatMoney(result.input.currentRent)}). '
                        'Yeni dönem kirası henüz uygulanmaz; bunu kayıt '
                        'detayından “Yeni dönemi hesapla → Yeni dönemi kiraya uygula” '
                        'ile yaparsınız.',
                        style: Theme.of(ctx).textTheme.bodySmall,
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
    if (_applyInFlight) return;

    if (result.isEstimated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tahmini sonuç kiraya uygulanamaz. Resmi oran açıklandığında yeniden hesaplayın.',
          ),
        ),
      );
      return;
    }

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
          'Bu hesaplama kaydın geçmişine eklenir; sonraki artış tarihi, '
          'hesaplanan yenileme tarihinden bir yıl ileri alınır.',
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
    if (_applyInFlight) return;
    _applyInFlight = true;

    try {
      final before = ref
          .read(rentalRepositoryProvider)
          .findById(id)
          ?.currentRent;
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
      assert(before == null || updated.currentRent == result.calculatedRent);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yeni kira kaydedildi')));
      Navigator.of(context).pop();
    } finally {
      _applyInFlight = false;
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    if (result.isEstimated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Resmi oran açıklanmadan PDF raporu oluşturulamaz',
          ),
        ),
      );
      return;
    }
    if (!isPro) {
      onNeedPro();
      return;
    }
    String? rentalName;
    final rid = rentalId;
    if (rid != null) {
      rentalName =
          ref.read(rentalRepositoryProvider).findById(rid)?.displayName;
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
                  result.isEstimated
                      ? 'Tahmini yeni kira'
                      : 'Hesaplanan Yeni Kira',
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
                      label: result.isEstimated ? 'Tahmini oran' : 'TÜFE oranı',
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
        if (result.isEstimated) ...[
          const SizedBox(height: 12),
          SoftCard(
            color: AppColors.sageSoft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.rateBasis == RateBasisKind.estimatedLatestOfficial
                        ? '${formatPercent(result.tufeMaxRatePercent)} son açıklanan oran kullanıldı · ${formatMonthKey(result.input.renewalMonthKey)} henüz açıklanmadı'
                        : '${formatPercent(result.tufeMaxRatePercent)} senaryo oranı kullanıldı · Resmî TÜFE değildir',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 18, color: AppColors.onSurfaceVariant),
                  tooltip: 'Detay',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showEstimatedResultDetailSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showForecastNotApplicableSheet(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tahmini sonuç kiraya uygulanamaz',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (result.input.contractIncreasePercent != null) ...[
          const SizedBox(height: 12),
          SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sözleşme oranı: ${formatPercent(result.input.contractIncreasePercent!)} · '
                        'Uygulanan: ${formatPercent(result.applicableRatePercent)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (result.contractCompare == ContractCompareKind.contractHigher)
                        Text(
                          'Sözleşme oranı azami sınırı aştığı için yasal azami orana göre gösterildi.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (result.contractCompare == ContractCompareKind.contractHigher)
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 18, color: AppColors.amber),
                    tooltip: 'Yasal oran bilgisi',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sözleşme oranı (${formatPercent(result.input.contractIncreasePercent!)}) TÜFE azami sınırını aştığı için yasal azami oran (${formatPercent(result.tufeMaxRatePercent)}) uygulandı.',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
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
        const SizedBox(height: 12),
        if (!_compareExpanded && compare == null)
          SoftCard(
            color: AppColors.sageSoft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: InkWell(
              onTap: () => setState(() => _compareExpanded = true),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Başka bir kira teklifiyle karşılaştır',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Ev sahibi veya kiracının teklif ettiği tutarı test edin',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.outline),
                ],
              ),
            ),
          )
        else
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kira teklifi karşılaştırma',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Teklif edilen kira ile yasal azami artışı karşılaştırın',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (compare == null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _compareExpanded = false),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const FieldLabel('Teklif edilen / konuşulan kira'),
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
                if (compare != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _CompareRow(
                    label: 'Hesaplanan Azami',
                    value: formatMoney(compare.calculatedRent),
                    secondary: formatSignedPercent(
                      compare.calculatedIncreaseRatePercent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CompareRow(
                    label: 'Teklif Edilen',
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
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (!result.isEstimated) ...[
          if (_fromRental) ...[
            FilledButton.icon(
              onPressed: () => _applyToRental(context),
              icon: const Icon(Icons.check_circle_outline),
              label: Stack(
                alignment: Alignment.center,
                children: const [
                  Opacity(
                    opacity: 0.0,
                    child: Text('Yeni kirayı kaydet'),
                  ),
                  Text('Yeni dönemi kiraya uygula'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => _saveToRentals(context, ref),
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: const Text('Farklı bir kira olarak kaydet'),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _saveToRentals(context, ref),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Kiralarıma kaydet'),
            ),
            const SizedBox(height: 8),
          ],
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    SharePlus.instance.share(ShareParams(text: _shareText)),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('Paylaş'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _shareText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Özet kopyalandı')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Kopyala'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            if (!result.isEstimated) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _exportPdf(context),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                        label: const Text('PDF', maxLines: 1),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    if (!isPro)
                      const Positioned(
                        right: 4,
                        top: -6,
                        child: ProBadge(compact: true),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showCalculationInfoSheet(context, result),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Hesaplama bilgileri ve TÜİK kaynağı',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
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
