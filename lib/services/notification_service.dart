import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder.dart';

/// Interface so screens (and tests) can work without the platform plugin.
abstract class NotificationService {
  Future<void> initialize();

  /// Requests notification permissions. Returns true when notifications can
  /// be shown.
  Future<bool> requestPermissions();

  Future<void> schedule(Reminder reminder);

  Future<void> cancel(int notificationId);
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'classe_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription = 'Notifications for your reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (error) {
      debugPrint('Could not resolve the local timezone: $error');
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (error) {
      debugPrint('Notification initialization failed: $error');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macos = _plugin
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();
        return await macos?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      return true;
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }
  }

  @override
  Future<void> schedule(Reminder reminder) async {
    await initialize();

    final scheduledDate = tz.TZDateTime.from(reminder.remindAt, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    Future<void> scheduleWith(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.notes.isEmpty ? 'Reminder' : reminder.notes,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: reminder.id,
      );
    }

    try {
      await scheduleWith(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (error) {
      debugPrint('Exact alarm unavailable, falling back to inexact: $error');
      try {
        await scheduleWith(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (fallbackError) {
        debugPrint('Could not schedule notification: $fallbackError');
      }
    }
  }

  @override
  Future<void> cancel(int notificationId) async {
    try {
      await _plugin.cancel(id: notificationId);
    } catch (error) {
      debugPrint('Could not cancel notification: $error');
    }
  }
}
