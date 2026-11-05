import 'dart:math';

import '../models/reminder.dart';
import '../services/notification_service.dart';
import 'local_store.dart';

/// Coordinates reminder persistence with device notifications.
class ReminderService {
  ReminderService({
    LocalStore? store,
    required NotificationService notifications,
  }) : _store = store ?? LocalStore() {
    _notifications = notifications;
  }

  final LocalStore _store;
  late final NotificationService _notifications;

  Future<List<Reminder>> load(String userId) async {
    final reminders = await _store.loadReminders(userId);
    return _sorted(reminders);
  }

  Future<List<Reminder>> add({
    required String userId,
    required String title,
    required String notes,
    required DateTime remindAt,
  }) async {
    final existing = await _store.loadReminders(userId);
    final reminder = Reminder(
      id: _generateId(),
      userId: userId,
      title: title.trim(),
      notes: notes.trim(),
      remindAt: remindAt,
      notificationId: _nextNotificationId(existing),
    );

    final updated = _sorted([...existing, reminder]);
    await _store.saveReminders(userId, updated);
    await _notifications.schedule(reminder);
    return updated;
  }

  Future<List<Reminder>> toggleDone(Reminder reminder) async {
    final existing = await _store.loadReminders(reminder.userId);
    final isDone = !reminder.isDone;

    final updated = _sorted([
      for (final item in existing)
        if (item.id == reminder.id) item.copyWith(isDone: isDone) else item,
    ]);
    await _store.saveReminders(reminder.userId, updated);

    if (isDone) {
      await _notifications.cancel(reminder.notificationId);
    } else {
      final restored = updated.firstWhere((item) => item.id == reminder.id);
      if (restored.remindAt.isAfter(DateTime.now())) {
        await _notifications.schedule(restored);
      }
    }

    return updated;
  }

  Future<List<Reminder>> delete(Reminder reminder) async {
    final existing = await _store.loadReminders(reminder.userId);
    final updated = existing.where((item) => item.id != reminder.id).toList();
    await _store.saveReminders(reminder.userId, updated);
    await _notifications.cancel(reminder.notificationId);
    return _sorted(updated);
  }

  /// Re-schedules pending notifications, e.g. after the timezone changes.
  Future<void> syncNotifications(List<Reminder> reminders) async {
    final now = DateTime.now();
    for (final reminder in reminders) {
      if (reminder.isDone || !reminder.remindAt.isAfter(now)) continue;
      await _notifications.schedule(reminder);
    }
  }

  static List<Reminder> _sorted(List<Reminder> reminders) {
    final copy = [...reminders];
    copy.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.remindAt.compareTo(b.remindAt);
    });
    return copy;
  }

  static int _nextNotificationId(List<Reminder> reminders) {
    if (reminders.isEmpty) return 1000;
    return reminders.map((reminder) => reminder.notificationId).reduce(max) + 1;
  }

  static String _generateId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 31)}';
  }
}
