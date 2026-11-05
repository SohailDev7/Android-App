import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:classe/data/local_store.dart';
import 'package:classe/models/account.dart';
import 'package:classe/models/reminder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('accounts round-trip through local storage', () async {
    final store = LocalStore();
    final account = Account(
      id: 'user-1',
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      passwordHash: 'hash',
      salt: 'salt',
      createdAt: DateTime(2026, 1, 2, 3, 4),
    );

    await store.saveAccounts([account]);
    final loaded = await store.loadAccounts();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'user-1');
    expect(loaded.single.name, 'Ada Lovelace');
    expect(loaded.single.email, 'ada@example.com');
    expect(loaded.single.createdAt, DateTime(2026, 1, 2, 3, 4));
  });

  test('session is stored and cleared', () async {
    final store = LocalStore();

    expect(await store.loadSessionUserId(), isNull);
    await store.saveSessionUserId('user-1');
    expect(await store.loadSessionUserId(), 'user-1');

    await store.saveSessionUserId(null);
    expect(await store.loadSessionUserId(), isNull);
  });

  test('reminders are scoped per user', () async {
    final store = LocalStore();
    final now = DateTime.now().add(const Duration(hours: 2));

    await store.saveReminders('user-1', [
      Reminder(
        id: 'r1',
        userId: 'user-1',
        title: 'Study',
        remindAt: now,
        notificationId: 1000,
      ),
    ]);
    await store.saveReminders('user-2', [
      Reminder(
        id: 'r2',
        userId: 'user-2',
        title: 'Call mom',
        remindAt: now,
        notificationId: 1000,
      ),
    ]);

    final first = await store.loadReminders('user-1');
    final second = await store.loadReminders('user-2');

    expect(first.single.title, 'Study');
    expect(second.single.title, 'Call mom');
  });

  test('reminder JSON keeps notes and completion state', () async {
    final reminder = Reminder(
      id: 'r1',
      userId: 'user-1',
      title: 'Study',
      notes: 'Chapter 4',
      remindAt: DateTime(2026, 5, 6, 7, 8),
      notificationId: 42,
      isDone: true,
    );

    final roundTripped = Reminder.fromJson(reminder.toJson());

    expect(roundTripped.notes, 'Chapter 4');
    expect(roundTripped.isDone, isTrue);
    expect(roundTripped.remindAt, DateTime(2026, 5, 6, 7, 8));
    expect(roundTripped.notificationId, 42);
  });
}
