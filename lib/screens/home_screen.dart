import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/reminder_service.dart';
import '../models/account.dart';
import '../models/reminder.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.account,
    required this.notifications,
    required this.onLogOut,
  });

  final Account account;
  final NotificationService notifications;
  final Future<void> Function() onLogOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ReminderService _reminders = ReminderService(
    notifications: widget.notifications,
  );

  List<Reminder> _items = [];
  bool _loading = true;
  bool? _permissionGranted;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensurePermissions());
  }

  Future<void> _load() async {
    final items = await _reminders.load(widget.account.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    await _reminders.syncNotifications(items);
  }

  Future<void> _ensurePermissions() async {
    final granted = await widget.notifications.requestPermissions();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
  }

  Future<void> _requestPermissionsAgain() async {
    final granted = await widget.notifications.requestPermissions();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
    if (!granted) _showMessage('Notifications are off. Turn them on in your device settings.');
  }

  Future<void> _openAddSheet() async {
    final draft = await showModalBottomSheet<_ReminderDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReminderSheet(),
    );
    if (draft == null || !mounted) return;

    final items = await _reminders.add(
      userId: widget.account.id,
      title: draft.title,
      notes: draft.notes,
      remindAt: draft.remindAt,
    );
    if (!mounted) return;
    setState(() => _items = items);
    _showMessage('Reminder set for ${DateFormat('EEE, d MMM · h:mm a').format(draft.remindAt)}');
  }

  Future<void> _toggleDone(Reminder reminder) async {
    final items = await _reminders.toggleDone(reminder);
    if (!mounted) return;
    setState(() => _items = items);
    if (!reminder.isDone) _showMessage('Nice — reminder completed.');
  }

  Future<void> _delete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('"${reminder.title}" will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final items = await _reminders.delete(reminder);
    if (!mounted) return;
    setState(() => _items = items);
    _showMessage('Reminder deleted.');
  }

  Future<void> _confirmLogOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Your reminders stay saved on this device. Log back in anytime.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.onLogOut();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _items.where((item) => !item.isDone).toList();
    final completed = _items.where((item) => item.isDone).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surfaceAlt,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildHeader(upcoming, completed),
                if (_permissionGranted == false) ...[
                  const SizedBox(height: 14),
                  _PermissionBanner(onEnable: _requestPermissionsAgain),
                ],
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 70),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_items.isEmpty)
                  _EmptyState(onAdd: _openAddSheet)
                else ...[
                  if (upcoming.isNotEmpty) ...[
                    _SectionTitle(title: 'Upcoming', count: upcoming.length),
                    const SizedBox(height: 10),
                    for (final reminder in upcoming)
                      _ReminderCard(
                        reminder: reminder,
                        onToggle: () => _toggleDone(reminder),
                        onDelete: () => _delete(reminder),
                      ),
                  ] else
                    const _AllCaughtUpCard(),
                  if (completed.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SectionTitle(title: 'Completed', count: completed.length),
                    const SizedBox(height: 10),
                    for (final reminder in completed)
                      _ReminderCard(
                        reminder: reminder,
                        onToggle: () => _toggleDone(reminder),
                        onDelete: () => _delete(reminder),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddSheet,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New reminder', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _buildHeader(List<Reminder> upcoming, List<Reminder> completed) {
    final now = DateTime.now();
    final today = upcoming.where((r) => _isSameDay(r.remindAt, now)).length;
    final overdue = upcoming.where((r) => r.isOverdue).length;
    final later = (upcoming.length - today).clamp(0, 9999);

    final String summary;
    if (upcoming.isEmpty) {
      summary = 'Your schedule is clear. Add something when you are ready.';
    } else if (overdue > 0) {
      summary = '$overdue overdue · ${upcoming.length} still open';
    } else if (today > 0) {
      summary = '$today due today · $later coming up later';
    } else {
      summary = '${upcoming.length} coming up. You are ahead of it.';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x2912172A), blurRadius: 30, offset: Offset(0, 16))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            const Positioned(top: -70, right: -40, child: _Glow(size: 180, color: Color(0x4D5B7CFF))),
            const Positioned(bottom: -90, left: -20, child: _Glow(size: 180, color: Color(0x332ED3B7))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: Text(
                          DateFormat('EEE, d MMMM').format(now).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _confirmLogOut,
                        tooltip: 'Log out',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hello, ${widget.account.firstName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.1,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(summary, style: const TextStyle(color: AppColors.textOnDarkMuted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _StatTile(value: '$today', label: 'Today', highlight: true),
                      const SizedBox(width: 10),
                      _StatTile(value: '$later', label: 'Later'),
                      const SizedBox(width: 10),
                      _StatTile(value: '${completed.length}', label: 'Done'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDue(DateTime dateTime) {
  final now = DateTime.now();
  final time = DateFormat.jm().format(dateTime);
  if (_isSameDay(dateTime, now)) return 'Today · $time';
  if (_isSameDay(dateTime, now.add(const Duration(days: 1)))) return 'Tomorrow · $time';
  return '${DateFormat('EEE, d MMM').format(dateTime)} · $time';
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.highlight = false});
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primary.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: highlight ? AppColors.primary.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: highlight ? Colors.white : AppColors.accent, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: AppColors.textOnDarkMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
          child: Text('$count', style: const TextStyle(color: AppColors.primaryDeep, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.reminder, required this.onToggle, required this.onDelete});
  final Reminder reminder;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = reminder.isDone;
    final overdue = reminder.isOverdue;
    final accent = done ? AppColors.success : overdue ? AppColors.danger : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: done ? Colors.white.withValues(alpha: 0.72) : AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: overdue && !done ? AppColors.danger.withValues(alpha: 0.22) : AppColors.border),
        boxShadow: done ? null : AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DoneIndicator(done: done, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: done ? AppColors.textMuted : AppColors.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (reminder.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, height: 1.35, color: AppColors.textMuted),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(overdue && !done ? Icons.notification_important_rounded : Icons.schedule_rounded, size: 14, color: accent),
                            const SizedBox(width: 5),
                            Text(
                              overdue && !done ? 'Overdue · ${_formatDue(reminder.remindAt)}' : _formatDue(reminder.remindAt),
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: accent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete reminder',
                  color: AppColors.textMuted,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneIndicator extends StatelessWidget {
  const _DoneIndicator({required this.done, required this.accent});
  final bool done;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? AppColors.accentGradient : null,
        color: done ? null : Colors.transparent,
        border: Border.all(color: done ? Colors.transparent : const Color(0xFFC7D2EE), width: 1.8),
      ),
      child: done ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.glowShadow),
            child: const Icon(Icons.alarm_add_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 18),
          const Text('No reminders yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 8),
          const Text(
            'Create your first reminder and Classe will nudge you at the right moment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add a reminder')),
        ],
      ),
    );
  }
}

class _AllCaughtUpCard extends StatelessWidget {
  const _AllCaughtUpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEFFFFB), Color(0xFFF4F7FF)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7EFE7)),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_rounded, color: AppColors.success),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All caught up. Your next reminder will show up here.',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onEnable});
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.accentWarm.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.notifications_off_rounded, color: AppColors.accentWarm),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notifications are off, so reminders cannot alert you.',
              style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onEnable, style: TextButton.styleFrom(foregroundColor: Colors.white), child: const Text('Turn on')),
        ],
      ),
    );
  }
}

class _ReminderDraft {
  const _ReminderDraft({required this.title, required this.notes, required this.remindAt});
  final String title;
  final String notes;
  final DateTime remindAt;
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet();

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late DateTime _remindAt = _defaultTime();
  String? _error;

  static DateTime _defaultTime() {
    final time = DateTime.now().add(const Duration(hours: 1));
    return DateTime(time.year, time.month, time.day, time.hour, time.minute);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _remindAt.isBefore(now) ? now : _remindAt,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() => _remindAt = DateTime(picked.year, picked.month, picked.day, _remindAt.hour, _remindAt.minute));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_remindAt));
    if (picked == null) return;
    setState(() => _remindAt = DateTime(_remindAt.year, _remindAt.month, _remindAt.day, picked.hour, picked.minute));
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Give your reminder a title.');
    if (!_remindAt.isAfter(DateTime.now())) return setState(() => _error = 'Pick a time in the future.');
    Navigator.of(context).pop(_ReminderDraft(title: title, notes: _notesController.text.trim(), remindAt: _remindAt));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.alarm_add_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New reminder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                        SizedBox(height: 2),
                        Text('Pick a moment and Classe will alert you.', style: TextStyle(color: AppColors.textMuted, fontSize: 13.5)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Study for the math test', counterText: '', prefixIcon: Icon(Icons.edit_rounded)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Add a little more detail...', counterText: '', alignLabelWithHint: true),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _PickerTile(icon: Icons.calendar_today_rounded, label: 'Date', value: DateFormat('EEE, d MMM').format(_remindAt), onTap: _pickDate)),
                  const SizedBox(width: 12),
                  Expanded(child: _PickerTile(icon: Icons.schedule_rounded, label: 'Time', value: DateFormat.jm().format(_remindAt), onTap: _pickTime)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              FilledButton(onPressed: _save, child: const Text('Set reminder')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
