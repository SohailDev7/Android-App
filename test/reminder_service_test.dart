import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:classe/data/local_store.dart';
import 'package:classe/data/reminder_service.dart';
import 'package:classe/models/reminder.dart';

import 'fakes.dart';

void main() {
  late LocalStore store;
  late FakeNotificationService notifications;
  late ReminderService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore();
    notifications = FakeNotificationService();
    service = ReminderService(store: store, notifications: notifications);
  });

  test('adding a reminder persists it and schedules a notification', () async {
    final remindAt = DateTime.now().add(const Duration(hours: 2));

    final items = await service.add(
      userId: 'user-1',
      title: '  Study for math ',
      notes: '  Chapter 4 ',
      remindAt: remindAt,
    );

    expect(items, hasLength(1));
    expect(items.single.title, 'Study for math');
    expect(items.single.notes, 'Chapter 4');
    expect(items.single.remindAt, remindAt);

    final stored = await store.loadReminders('user-1');
    expect(stored.single.id, items.single.id);
    expect(notifications.scheduled.single.id, items.single.id);
  });

  test(
    'reminders are sorted by time and notification ids are unique',
    () async {
      final later = DateTime.now().add(const Duration(hours: 5));
      final sooner = DateTime.now().add(const Duration(hours: 1));

      await service.add(
        userId: 'user-1',
        title: 'Later',
        notes: '',
        remindAt: later,
      );
      final items = await service.add(
        userId: 'user-1',
        title: 'Sooner',
        notes: '',
        remindAt: sooner,
      );

      expect(items.map((item) => item.title), ['Sooner', 'Later']);
      expect(items.map((item) => item.notificationId).toSet(), hasLength(2));
    },
  );

  test('completing a reminder cancels its notification', () async {
    final items = await service.add(
      userId: 'user-1',
      title: 'Study',
      notes: '',
      remindAt: DateTime.now().add(const Duration(hours: 1)),
    );

    final updated = await service.toggleDone(items.single);

    expect(updated.single.isDone, isTrue);
    expect(notifications.cancelled, [items.single.notificationId]);
  });

  test('restoring a reminder schedules it again', () async {
    final items = await service.add(
      userId: 'user-1',
      title: 'Study',
      notes: '',
      remindAt: DateTime.now().add(const Duration(hours: 1)),
    );

    final done = await service.toggleDone(items.single);
    final restored = await service.toggleDone(done.single);

    expect(restored.single.isDone, isFalse);
    expect(notifications.scheduled, hasLength(2));
    expect(notifications.scheduled.last.id, items.single.id);
  });

  test('deleting a reminder removes it and cancels the notification', () async {
    final items = await service.add(
      userId: 'user-1',
      title: 'Study',
      notes: '',
      remindAt: DateTime.now().add(const Duration(hours: 1)),
    );

    final updated = await service.delete(items.single);

    expect(updated, isEmpty);
    expect(await store.loadReminders('user-1'), isEmpty);
    expect(notifications.cancelled, [items.single.notificationId]);
  });

  test('sync only schedules pending future reminders', () async {
    final now = DateTime.now();
    await store.saveReminders('user-1', [
      Reminder(
        id: 'future',
        userId: 'user-1',
        title: 'Future',
        remindAt: now.add(const Duration(hours: 1)),
        notificationId: 1000,
      ),
      Reminder(
        id: 'past',
        userId: 'user-1',
        title: 'Past',
        remindAt: now.subtract(const Duration(hours: 1)),
        notificationId: 1001,
      ),
      Reminder(
        id: 'done',
        userId: 'user-1',
        title: 'Done',
        remindAt: now.add(const Duration(hours: 2)),
        notificationId: 1002,
        isDone: true,
      ),
    ]);

    final items = await service.load('user-1');
    await service.syncNotifications(items);

    expect(notifications.scheduled, hasLength(1));
    expect(notifications.scheduled.single.id, 'future');
  });
}
