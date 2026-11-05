import 'package:classe/models/reminder.dart';
import 'package:classe/services/notification_service.dart';

/// In-memory notification service used by tests.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.permissionGranted = true});

  bool permissionGranted;
  int permissionRequests = 0;
  final List<Reminder> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> schedule(Reminder reminder) async {
    scheduled.add(reminder);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }
}
