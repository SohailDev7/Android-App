import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/account.dart';
import 'local_store.dart';

/// Thrown for expected authentication problems (bad password, duplicate email).
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Local-only account system.
///
/// Passwords are salted and SHA-256 hashed before being stored. This is fine
/// for a local demo; a real backend should use a dedicated password hashing
/// algorithm such as Argon2/bcrypt.
class AuthService {
  AuthService({LocalStore? store}) : _store = store ?? LocalStore();

  final LocalStore _store;

  Future<Account?> currentAccount() async {
    final id = await _store.loadSessionUserId();
    if (id == null) return null;

    final accounts = await _store.loadAccounts();
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  Future<Account> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final accounts = await _store.loadAccounts();

    if (accounts.any((account) => account.email == normalizedEmail)) {
      throw const AuthException(
        'An account with that email already exists. Try logging in instead.',
      );
    }

    final salt = _generateSalt();
    final account = Account(
      id: _generateId(),
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: _hashPassword(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
    );

    await _store.saveAccounts([...accounts, account]);
    await _store.saveSessionUserId(account.id);
    return account;
  }

  Future<Account> logIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final accounts = await _store.loadAccounts();

    for (final account in accounts) {
      if (account.email != normalizedEmail) continue;

      if (_hashPassword(password, account.salt) != account.passwordHash) {
        throw const AuthException('Incorrect password. Please try again.');
      }

      await _store.saveSessionUserId(account.id);
      return account;
    }

    throw const AuthException(
      'No account found with that email. Create one to get started.',
    );
  }

  Future<void> logOut() => _store.saveSessionUserId(null);

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _generateId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 31)}';
  }

  static String _hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt:$password')).toString();
  }
}
