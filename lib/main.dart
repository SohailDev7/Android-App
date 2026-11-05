import 'package:flutter/material.dart';

import 'app_root.dart';
import 'data/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'update_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClasseApp());
}

class ClasseApp extends StatelessWidget {
  const ClasseApp({super.key, this.authService, this.notifications});

  final AuthService? authService;
  final NotificationService? notifications;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: UpdateGate(
        child: AppRoot(authService: authService, notifications: notifications),
      ),
    );
  }
}
