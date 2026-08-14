import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/models/rental.dart';
import '../../providers/app_providers.dart';
import '../widgets/design_system.dart';
import '../widgets/past_renewal_sheet.dart';

class RentalEditScreen extends ConsumerStatefulWidget {
  const RentalEditScreen({super.key, this.rentalId});

  final String? rentalId;

  bool get isEditing => rentalId != null;

  @override
  ConsumerState<RentalEditScreen> createState() => _RentalEditScreenState();
}

class _RentalEditScreenState extends ConsumerState<RentalEditScreen> {
  final _nameCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _tenantCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  /// Şema uyumluluğu için varsayılan; UI’da birincil kimlik değil.
  RentalRole _role = RentalRole.tenant;
  late DateTime _renewal;
  late DateTime _contractStart;
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _renewal = DateTime(now.year, now.month, now.day);
    _contractStart = DateTime(now.year - 1, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  void _hydrate() {
    if (widget.rentalId == null) {
      setState(() => _hydrated = true);
      return;
    }
    final rental = ref
        .read(rentalRepositoryProvider)
        .findById(widget.rentalId!);
    if (rental == null) {
      setState(() => _hydrated = true);
      return;
    }
    _nameCtrl.text = rental.propertyName;
    _rentCtrl.text = rental.currentRent.toStringAsFixed(
      rental.currentRent.truncateToDouble() == rental.currentRent ? 0 : 2,
    );
    _tenantCtrl.text = rental.tenantName ?? '';
    _ownerCtrl.text = rental.ownerName ?? '';
    _addressCtrl.text = rental.address ?? '';
    _notesCtrl.text = rental.notes ?? '';
    setState(() {
      _role = rental.role;
      _renewal = rental.nextRenewalDate;
      _contractStart = rental.contractStartDate;
      _hydrated = true;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rentCtrl.dispose();
    _tenantCtrl.dispose();
    _ownerCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRenewal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewal,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(DateTime.now().year + 3, 12, 31),
      helpText: 'Yenileme tarihi',
    );
    if (picked != null) setState(() => _renewal = picked);
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

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Taşınmaz adı gerekli. Örn: Beşiktaş Daire 4');
      return;
    }
    if (name.length < 2) {
      _snack('Taşınmaz adı en az 2 karakter olmalı');
      return;
    }

    final rentRaw = _rentCtrl.text.replaceAll('.', '').replaceAll(',', '.');
    final rent = double.tryParse(rentRaw);
    if (rent == null || rent <= 0) {
      _snack('Geçerli bir aylık kira tutarı girin');
      return;
    }

    final tenant = _tenantCtrl.text.trim();
    final owner = _ownerCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final now = DateTime.now();
    final today = dateOnly(now);
    final picked = dateOnly(_renewal);

    DateTime next = picked;
    DateTime? last;

    if (widget.isEditing) {
      final existing = ref
          .read(rentalRepositoryProvider)
          .findById(widget.rentalId!);
      last = existing?.lastRenewalDate;
    }

    if (picked.isBefore(today)) {
      final suggested = nextIncreaseAnniversary(picked);
      final choice = await showPastRenewalConfirmationSheet(
        context,
        pastDate: picked,
        suggestedNext: suggested,
      );
      if (!mounted) return;
      if (choice == null || choice == PastRenewalChoice.changeDate) return;
      if (choice == PastRenewalChoice.completed) {
        last = picked;
        next = suggested;
      } else {
        next = picked;
      }
    }

    if (widget.isEditing) {
      final existing = ref
          .read(rentalRepositoryProvider)
          .findById(widget.rentalId!);
      if (existing == null) return;
      final updated = existing.copyWith(
        role: _role,
        displayName: name,
        currentRent: rent,
        contractStartDate: _contractStart,
        increaseDate: next,
        lastRenewalDate: last,
        renewalResolved: true,
        tenantName: tenant.isEmpty ? null : tenant,
        clearTenantName: tenant.isEmpty,
        ownerName: owner.isEmpty ? null : owner,
        clearOwnerName: owner.isEmpty,
        address: address.isEmpty ? null : address,
        clearAddress: address.isEmpty,
        notes: notes.isEmpty ? null : notes,
        clearNotes: notes.isEmpty,
        updatedAt: now,
      );
      await ref.read(rentalsProvider.notifier).update(updated);
    } else {
      final rental = Rental(
        id: now.microsecondsSinceEpoch.toString(),
        role: _role,
        displayName: name,
        currentRent: rent,
        contractStartDate: _contractStart,
        increaseDate: next,
        lastRenewalDate: last,
        renewalResolved: true,
        tenantName: tenant.isEmpty ? null : tenant,
        ownerName: owner.isEmpty ? null : owner,
        address: address.isEmpty ? null : address,
        notes: notes.isEmpty ? null : notes,
        createdAt: now,
        updatedAt: now,
      );
      final ok = await ref.read(rentalsProvider.notifier).add(rental);
      if (!ok) {
        if (mounted) {
          _snack('Ücretsiz planda en fazla 1 kira kaydı ekleyebilirsiniz');
        }
        return;
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Kirayı Düzenle' : 'Kira Ekle'),
      ),
      body: ListView(
        padding: scrollablePagePadding(
          context,
          horizontal: AppSpace.margin,
          top: 12,
          bottom: AppSpace.md,
        ),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Temel bilgiler',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.md),
                FieldLabel('Taşınmaz adı'),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Beşiktaş Daire 4',
                  ),
                ),
                const SizedBox(height: 14),
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
                  label: 'Sözleşme başlangıcı',
                  helperText:
                      'Kiracılığın ilk başladığı tarih. 5 yıl ve üzeri değerlendirmelerde kullanılır.',
                  valueText: formatDateTr(_contractStart),
                  onTap: _pickStart,
                ),
                const SizedBox(height: 14),
                DatePickerTile(
                  label: 'Yenileme tarihi',
                  helperText:
                      'Bir sonraki yenileme tarihini gir. Son yenileme '
                      'geçmişteyse kaydederken sana soracağız.',
                  valueText: formatDateTr(_renewal),
                  onTap: _pickRenewal,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İsteğe bağlı bilgiler',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                FieldLabel('Kiracı adı'),
                TextField(
                  controller: _tenantCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'İsteğe bağlı'),
                ),
                const SizedBox(height: 14),
                FieldLabel('Ev sahibi adı'),
                TextField(
                  controller: _ownerCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'İsteğe bağlı'),
                ),
                const SizedBox(height: 14),
                FieldLabel('Adres'),
                TextField(
                  controller: _addressCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'İsteğe bağlı'),
                ),
                const SizedBox(height: 14),
                FieldLabel('Notlar'),
                TextField(
                  controller: _notesCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'İsteğe bağlı'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              widget.isEditing ? 'Değişiklikleri Kaydet' : 'Kirayı Kaydet',
            ),
          ),
        ],
      ),
    );
  }
}
