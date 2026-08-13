import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../domain/models/rental.dart';
import '../../providers/app_providers.dart';
import '../../services/reminder_service.dart';
import '../widgets/design_system.dart';

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({super.key, required this.rentalId});

  final String rentalId;

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  late DateTime _renewal;
  bool _d30 = true;
  bool _d7 = true;
  bool _d0 = true;
  bool _saving = false;
  bool _notificationsBlocked = false;
  bool _enabled = false;
  bool _hydrated = false;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _renewal = DateTime(now.year, now.month + 1, 15);
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    final rental = ref.read(rentalRepositoryProvider).findById(widget.rentalId);
    final svc = ref.read(reminderServiceProvider);
    final phase = await svc.permissionPhase();
    if (!mounted) return;
    if (rental == null) {
      setState(() => _hydrated = true);
      return;
    }
    setState(() {
      _displayName = rental.displayName;
      _renewal = rental.increaseDate;
      _enabled = rental.reminder.enabled;
      _d30 = rental.reminder.notify30;
      _d7 = rental.reminder.notify7;
      _d0 = rental.reminder.notify0;
      _notificationsBlocked =
          phase == NotificationPermissionPhase.permanentlyDenied ||
          phase == NotificationPermissionPhase.restricted ||
          (rental.reminder.enabled &&
              phase != NotificationPermissionPhase.granted);
      _hydrated = true;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewal.isBefore(DateTime.now())
          ? DateTime.now()
          : _renewal,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Kira artış tarihi',
    );
    if (picked != null) setState(() => _renewal = picked);
  }

  DateTime get _minus30 => _renewal.subtract(const Duration(days: 30));
  DateTime get _minus7 => _renewal.subtract(const Duration(days: 7));

  Future<bool> _ensurePermissionForSave() async {
    final svc = ref.read(reminderServiceProvider);
    final phase = await svc.permissionPhase();
    if (phase == NotificationPermissionPhase.granted) return true;

    if (phase == NotificationPermissionPhase.permanentlyDenied ||
        phase == NotificationPermissionPhase.restricted) {
      if (mounted) setState(() => _notificationsBlocked = true);
      return false;
    }

    if (!mounted) return false;
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.paddingOf(ctx).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bildirim izni gerekli',
              style: Theme.of(ctx).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Hatırlatmaların çalışması için bildirim iznine ihtiyacımız var.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('İzin Ver'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Şimdi değil'),
            ),
          ],
        ),
      ),
    );

    if (go != true) return false;

    final after = await svc.requestPermission();
    if (after == NotificationPermissionPhase.granted) {
      setState(() => _notificationsBlocked = false);
      return true;
    }
    setState(() => _notificationsBlocked = true);
    return false;
  }

  Future<Rental?> _persistReminder({required bool enabled}) async {
    final existing = ref
        .read(rentalRepositoryProvider)
        .findById(widget.rentalId);
    if (existing == null) return null;
    final updated = existing.copyWith(
      increaseDate: _renewal,
      updatedAt: DateTime.now(),
      reminder: RentalReminderPrefs(
        enabled: enabled,
        notify30: _d30,
        notify7: _d7,
        notify0: _d0,
      ),
    );
    await ref.read(rentalsProvider.notifier).update(updated);
    return updated;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final allowed = await _ensurePermissionForSave();
      final updated = await _persistReminder(enabled: true);
      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kira kaydı bulunamadı')));
        return;
      }

      if (!allowed) {
        setState(() {
          _enabled = true;
          _notificationsBlocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tercihler kaydedildi. Bildirimler için izin gerekli.',
            ),
          ),
        );
        return;
      }

      final ok = await ref
          .read(reminderServiceProvider)
          .scheduleForRental(updated);
      if (!mounted) return;
      setState(() {
        _enabled = true;
        _notificationsBlocked = !ok;
      });
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hatırlatmalar kaydedildi')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tercihler kaydedildi. Bildirim planlanamadı — izinleri kontrol edin.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kayıt başarısız: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    await _persistReminder(enabled: false);
    await ref.read(reminderServiceProvider).cancelForRental(widget.rentalId);
    if (!mounted) return;
    setState(() => _enabled = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Hatırlatmalar kaldırıldı')));
    Navigator.pop(context);
  }

  Future<void> _openSettings() async {
    await ref.read(reminderServiceProvider).openSystemNotificationSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yenileme Hatırlatması'),
        centerTitle: true,
      ),
      body: ListView(
        padding: scrollablePagePadding(
          context,
          horizontal: 16,
          top: 16,
          bottom: 16,
        ),
        children: [
          if (_displayName.isNotEmpty) ...[
            Text(_displayName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amber,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'KIRAROTA PRO',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Yenileme tarihini unutma',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Kira yenileme döneminiz yaklaşırken size hatırlatalım.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_notificationsBlocked) ...[
            const SizedBox(height: 16),
            SoftCard(
              color: AppColors.surfaceLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bildirimler kapalı',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hatırlatmaların çalışması için uygulama bildirimlerine izin verin.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _openSettings,
                    child: const Text('Ayarları Aç'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kira artış tarihi',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          formatDateTr(_renewal),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ToggleRow(
                  title: '30 gün önce',
                  subtitle: formatDateTr(_minus30),
                  value: _d30,
                  onChanged: (v) => setState(() => _d30 = v),
                ),
                const Divider(height: 1),
                _ToggleRow(
                  title: '7 gün önce',
                  subtitle: formatDateTr(_minus7),
                  value: _d7,
                  onChanged: (v) => setState(() => _d7 = v),
                ),
                const Divider(height: 1),
                _ToggleRow(
                  title: 'Yenileme günü',
                  subtitle: formatDateTr(_renewal),
                  value: _d0,
                  onChanged: (v) => setState(() => _d0 = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Kaydediliyor…' : 'Hatırlatmaları Kaydet'),
          ),
          if (_enabled) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : _remove,
              child: const Text('Hatırlatmaları Kaldır'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}
