import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:classe/data/auth_service.dart';
import 'package:classe/data/local_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('signing up stores a salted hash, not the password', () async {
    final service = AuthService();
    final account = await service.signUp(
      name: 'Ada Lovelace',
      email: '  Ada@Example.com ',
      password: 'secret123',
    );

    expect(account.email, 'ada@example.com');
    expect(account.salt, isNotEmpty);
    expect(account.passwordHash, isNot('secret123'));
    expect(account.passwordHash, isNot(contains('secret123')));

    final stored = (await LocalStore().loadAccounts()).single;
    expect(stored.passwordHash, account.passwordHash);
    expect(stored.salt, account.salt);
  });

  test('signing up logs the account in', () async {
    final service = AuthService();
    final account = await service.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );

    final current = await service.currentAccount();
    expect(current?.id, account.id);
  });

  test('duplicate emails are rejected', () async {
    final service = AuthService();
    await service.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );

    expect(
      () => service.signUp(
        name: 'Someone Else',
        email: 'ADA@example.com',
        password: 'another123',
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('already exists'),
        ),
      ),
    );
  });

  test('login accepts the correct password and persists the session', () async {
    final service = AuthService();
    await service.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );
    await service.logOut();

    final account = await service.logIn(
      email: 'ADA@example.com',
      password: 'secret123',
    );

    expect(account.name, 'Ada Lovelace');
    expect((await service.currentAccount())?.id, account.id);
  });

  test('login rejects a wrong password', () async {
    final service = AuthService();
    await service.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );
    await service.logOut();

    expect(
      () => service.logIn(email: 'ada@example.com', password: 'nope'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('Incorrect password'),
        ),
      ),
    );
  });

  test('login rejects an unknown email', () async {
    final service = AuthService();

    expect(
      () => service.logIn(email: 'nobody@example.com', password: 'secret123'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.message,
          'message',
          contains('No account found'),
        ),
      ),
    );
  });

  test('logging out clears the session but keeps the account', () async {
    final service = AuthService();
    await service.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );

    await service.logOut();

    expect(await service.currentAccount(), isNull);
    expect(await LocalStore().loadAccounts(), hasLength(1));
  });
}
