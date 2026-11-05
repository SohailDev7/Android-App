import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/auth_service.dart';
import 'models/account.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

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
    if (_loading) return const _SplashScreen();

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
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: AppColors.glowShadow,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Classe',
                  style: TextStyle(
                    color: AppColors.textOnDark,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Getting your reminders ready',
                  style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13.5),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
