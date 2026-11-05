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
    if (!granted) {
      _showMessage(
        'Notifications are off. Turn them on in your device settings.',
      );
    }
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
    _showMessage(
      'Reminder set for ${DateFormat('EEE, d MMM · h:mm a').format(draft.remindAt)}',
    );
  }

  Future<void> _toggleDone(Reminder reminder) async {
    final items = await _reminders.toggleDone(reminder);
    if (!mounted) return;
    setState(() => _items = items);

    if (!reminder.isDone) {
      _showMessage('Nice — reminder completed.');
    }
  }

  Future<void> _delete(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('“${reminder.title}” will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
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
        content: const Text(
          'Your reminders stay saved on this device. Log back in anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.onLogOut();
    }
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
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.ink,
            backgroundColor: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildHeader(upcoming, completed),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_permissionGranted == false) ...[
                        _PermissionBanner(onEnable: _requestPermissionsAgain),
                        const SizedBox(height: 18),
                      ],
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_items.isEmpty)
                        _EmptyState(onAdd: _openAddSheet)
                      else ...[
                        if (upcoming.isNotEmpty) ...[
                          _SectionTitle(
                            title: 'Upcoming',
                            count: upcoming.length,
                          ),
                          const SizedBox(height: 12),
                          for (final reminder in upcoming)
                            _ReminderCard(
                              reminder: reminder,
                              onToggle: () => _toggleDone(reminder),
                              onDelete: () => _delete(reminder),
                            ),
                          if (completed.isNotEmpty) const SizedBox(height: 12),
                        ],
                        if (upcoming.isEmpty) const _AllCaughtUpCard(),
                        if (completed.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SectionTitle(
                            title: 'Completed',
                            count: completed.length,
                          ),
                          const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddSheet,
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(Icons.add_rounded, color: AppColors.lime),
          label: const Text(
            'New reminder',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(List<Reminder> upcoming, List<Reminder> completed) {
    final now = DateTime.now();
    final today = upcoming
        .where((reminder) => _isSameDay(reminder.remindAt, now))
        .length;
    final overdue = upcoming.where((reminder) => reminder.isOverdue).length;
    final later = upcoming.length - today;

    final String summary;
    if (upcoming.isEmpty) {
      summary = 'Nothing on the list. Enjoy the calm.';
    } else if (overdue > 0) {
      summary = '$overdue overdue · ${upcoming.length} open';
    } else if (today == 0) {
      summary = upcoming.length == 1
          ? '1 reminder ahead of you.'
          : '${upcoming.length} reminders ahead of you.';
    } else {
      summary = today == 1 ? '1 reminder due today.' : '$today due today.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: ColoredBox(
          color: AppColors.ink,
          child: Stack(
            children: [
              Positioned(
                top: -100,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x59D9FF57), Color(0x00D9FF57)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, d MMMM')
                                    .format(now)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.lime,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Hello, ${widget.account.firstName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                summary,
                                style: const TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _confirmLogOut,
                          tooltip: 'Log out',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.08,
                            ),
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _StatTile(
                          value: '$today',
                          label: 'Today',
                          accent: AppColors.lime,
                        ),
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
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatDue(DateTime dateTime) {
  final now = DateTime.now();
  final time = DateFormat.jm().format(dateTime);
  if (_isSameDay(dateTime, now)) return 'Today · $time';
  if (_isSameDay(dateTime, now.add(const Duration(days: 1)))) {
    return 'Tomorrow · $time';
  }
  return '${DateFormat('EEE, d MMM').format(dateTime)} · $time';
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.accent = Colors.white,
  });

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0x8CFFFFFF),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.lime,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onDelete,
  });

  final Reminder reminder;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = reminder.isDone;
    final overdue = reminder.isOverdue;
    final accent = done
        ? AppColors.success
        : overdue
        ? AppColors.danger
        : AppColors.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFFBFBF7) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overdue && !done ? const Color(0x40E5533C) : AppColors.border,
        ),
        boxShadow: done ? null : AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DoneIndicator(done: done),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: done
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                      if (reminder.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          reminder.notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            overdue && !done
                                ? Icons.error_outline_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            overdue && !done
                                ? 'Overdue · ${_formatDue(reminder.remindAt)}'
                                : _formatDue(reminder.remindAt),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete reminder',
                  color: AppColors.textMuted,
                  iconSize: 19,
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
  const _DoneIndicator({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.lime : Colors.transparent,
        border: Border.all(
          color: done ? AppColors.lime : const Color(0xFFC9CCC3),
          width: 1.7,
        ),
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 17, color: AppColors.ink)
          : null,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 30),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.lime,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.alarm_add_rounded,
              size: 34,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No reminders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your future self will thank you. Add your first reminder and '
            'Classe will nudge you right on time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add a reminder'),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FFD6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDFF59B)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: AppColors.ink, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'All clear. Add something to stay ahead of the day.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: AppColors.lime,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Notifications are off, so reminders cannot alert you.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xB3FFFFFF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: onEnable,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.lime,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
  }
}

class _ReminderDraft {
  const _ReminderDraft({
    required this.title,
    required this.notes,
    required this.remindAt,
  });

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
      helpText: 'Select reminder date',
    );
    if (picked == null) return;

    setState(() {
      _remindAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _remindAt.hour,
        _remindAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_remindAt),
      helpText: 'Select reminder time',
    );
    if (picked == null) return;

    setState(() {
      _remindAt = DateTime(
        _remindAt.year,
        _remindAt.month,
        _remindAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give your reminder a title.');
      return;
    }
    if (!_remindAt.isAfter(DateTime.now())) {
      setState(() => _error = 'Pick a time in the future.');
      return;
    }

    Navigator.of(context).pop(
      _ReminderDraft(
        title: title,
        notes: _notesController.text.trim(),
        remindAt: _remindAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New reminder',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.7,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'We will send a notification at the time you choose.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted,
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Study for the math test',
                  counterText: '',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add a little more detail...',
                  counterText: '',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: DateFormat('EEE, d MMM').format(_remindAt),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.schedule_rounded,
                      label: 'Time',
                      value: DateFormat.jm().format(_remindAt),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.alarm_add_rounded, size: 20),
                label: const Text('Set reminder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fieldFill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
