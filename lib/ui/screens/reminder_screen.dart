import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../services/reminder_service.dart';
import '../widgets/design_system.dart';

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  late DateTime _renewal;
  bool _d30 = true;
  bool _d7 = true;
  bool _d0 = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _renewal = widget.initialDate ?? DateTime(now.year, now.month + 1, 15);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final saved = ref.read(reminderServiceProvider).saved;
      if (saved == null || !mounted) return;
      setState(() {
        _renewal = saved.renewalDate;
        _d30 = saved.notify30;
        _d7 = saved.notify7;
        _d0 = saved.notify0;
      });
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _renewal.isBefore(DateTime.now()) ? DateTime.now() : _renewal,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _renewal = picked);
  }

  DateTime get _minus30 => _renewal.subtract(const Duration(days: 30));
  DateTime get _minus7 => _renewal.subtract(const Duration(days: 7));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(reminderServiceProvider).schedule(
            ReminderConfig(
              renewalDate: _renewal,
              notify30: _d30,
              notify7: _d7,
              notify0: _d0,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hatırlatmalar kaydedildi')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt başarısız: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove() async {
    await ref.read(reminderServiceProvider).clearSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hatırlatmalar kaldırıldı')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yenileme Hatırlatması'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    'KİRA ASİSTANI PRO',
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
          const SizedBox(height: 20),
          SoftCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.sageSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yenileme tarihi', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        formatDateTr(_renewal),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.edit_outlined),
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
                const Divider(),
                _ToggleRow(
                  title: '7 gün önce',
                  subtitle: formatDateTr(_minus7),
                  value: _d7,
                  onChanged: (v) => setState(() => _d7 = v),
                ),
                const Divider(),
                _ToggleRow(
                  title: 'Yenileme günü',
                  subtitle: formatDateTr(_renewal),
                  value: _d0,
                  onChanged: (v) => setState(() => _d0 = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const InfoBanner(
            message:
                'Hatırlatmalar cihazınızda planlanır. Bildirimlerin çalışması için uygulama bildirimlerine izin verilmelidir.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Hatırlatmayı Kaydet'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving ? null : _remove,
            child: const Text('Hatırlatmayı Kaldır'),
          ),
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
