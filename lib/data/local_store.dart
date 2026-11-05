import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/reminder.dart';

/// Tiny persistence layer on top of SharedPreferences.
///
/// Accounts, the active session and per-user reminders are stored as JSON.
class LocalStore {
  static const _accountsKey = 'classe.accounts';
  static const _sessionKey = 'classe.session';

  static String _remindersKey(String userId) => 'classe.reminders.$userId';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<Account>> loadAccounts() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Account.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> saveAccounts(List<Account> accounts) async {
    final prefs = await _prefs;
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }

  Future<String?> loadSessionUserId() async {
    final prefs = await _prefs;
    return prefs.getString(_sessionKey);
  }

  Future<void> saveSessionUserId(String? userId) async {
    final prefs = await _prefs;
    if (userId == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, userId);
    }
  }

  Future<List<Reminder>> loadReminders(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_remindersKey(userId));
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (item) => Reminder.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  Future<void> saveReminders(String userId, List<Reminder> reminders) async {
    final prefs = await _prefs;
    await prefs.setString(
      _remindersKey(userId),
      jsonEncode(reminders.map((reminder) => reminder.toJson()).toList()),
    );
  }
}
