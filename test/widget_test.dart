import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:classe/data/auth_service.dart';
import 'package:classe/main.dart';

import 'fakes.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  AuthService? authService,
  FakeNotificationService? notifications,
}) async {
  await tester.pumpWidget(
    ClasseApp(
      authService: authService,
      notifications: notifications ?? FakeNotificationService(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillSignUp(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Ada Lovelace');
  await tester.enterText(fields.at(1), 'ada@example.com');
  await tester.enterText(fields.at(2), 'secret123');
  await tester.enterText(fields.at(3), 'secret123');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the login form', (tester) async {
    await _pumpApp(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('validates empty login fields', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('rejects a malformed email', (tester) async {
    await _pumpApp(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'not-an-email');
    await tester.enterText(fields.last, 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('creates an account and opens the reminders home', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await _fillSignUp(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Ada'), findsOneWidget);
    expect(find.text('No reminders yet'), findsOneWidget);
  });

  testWidgets('sign up validates matching passwords', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    await _fillSignUp(tester);
    await tester.enterText(find.byType(TextFormField).at(3), 'different');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('logs in with a stored account', (tester) async {
    final auth = AuthService();
    await auth.signUp(
      name: 'Grace Hopper',
      email: 'grace@example.com',
      password: 'compiler123',
    );
    await auth.logOut();

    await _pumpApp(tester, authService: auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'grace@example.com');
    await tester.enterText(fields.last, 'compiler123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Grace'), findsOneWidget);
  });

  testWidgets('shows an error for a wrong password', (tester) async {
    final auth = AuthService();
    await auth.signUp(
      name: 'Grace Hopper',
      email: 'grace@example.com',
      password: 'compiler123',
    );
    await auth.logOut();

    await _pumpApp(tester, authService: auth);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'grace@example.com');
    await tester.enterText(fields.last, 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password. Please try again.'), findsOneWidget);
  });

  testWidgets('restores the saved session on launch', (tester) async {
    final auth = AuthService();
    await auth.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );

    await _pumpApp(tester, authService: auth);

    expect(find.text('Hello, Ada'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('logs out back to the login screen', (tester) async {
    final auth = AuthService();
    await auth.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );

    await _pumpApp(tester, authService: auth);
    expect(find.text('Hello, Ada'), findsOneWidget);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('adds a reminder and schedules a notification', (tester) async {
    final notifications = FakeNotificationService();
    final auth = AuthService();
    await auth.signUp(
      name: 'Ada Lovelace',
      email: 'ada@example.com',
      password: 'secret123',
    );

    await _pumpApp(tester, authService: auth, notifications: notifications);

    await tester.tap(find.text('New reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Set reminder'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Study for math',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Set reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Study for math'), findsOneWidget);
    expect(notifications.scheduled, hasLength(1));
    expect(notifications.scheduled.single.title, 'Study for math');
  });
}
