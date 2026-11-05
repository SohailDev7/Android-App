import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/auth_service.dart';
import 'models/account.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

/// Decides which screen to show based on the locally stored session.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, this.authService, this.notifications});

  final AuthService? authService;
  final NotificationService? notifications;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final AuthService _auth = widget.authService ?? AuthService();
  late final NotificationService _notifications =
      widget.notifications ?? LocalNotificationService();

  Account? _account;
  bool _loading = true;
  bool _showSignUp = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final account = await _auth.currentAccount();
    if (!mounted) return;
    setState(() {
      _account = account;
      _loading = false;
    });
  }

  void _handleAuthenticated(Account account) {
    setState(() {
      _account = account;
      _showSignUp = false;
    });
  }

  Future<void> _handleLogOut() async {
    await _auth.logOut();
    if (!mounted) return;
    setState(() => _account = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SplashScreen();
    }

    final account = _account;
    if (account != null) {
      return HomeScreen(
        account: account,
        notifications: _notifications,
        onLogOut: _handleLogOut,
      );
    }

    if (_showSignUp) {
      return SignUpScreen(
        authService: _auth,
        onSignedUp: _handleAuthenticated,
        onBackToLogIn: () => setState(() => _showSignUp = false),
      );
    }

    return LoginScreen(
      authService: _auth,
      onLoggedIn: _handleAuthenticated,
      onCreateAccount: () => setState(() => _showSignUp = true),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppColors.ink,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.ink,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'classe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'reminders, reimagined',
                style: TextStyle(
                  color: Color(0x99FFFFFF),
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(AppColors.lime),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
