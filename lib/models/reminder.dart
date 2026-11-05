class Reminder {
  const Reminder({
    required this.id,
    required this.userId,
    required this.title,
    required this.remindAt,
    required this.notificationId,
    this.notes = '',
    this.isDone = false,
  });

  final String id;
  final String userId;
  final String title;
  final String notes;
  final DateTime remindAt;
  final int notificationId;
  final bool isDone;

  bool get isOverdue => !isDone && remindAt.isBefore(DateTime.now());

  Reminder copyWith({
    String? title,
    String? notes,
    DateTime? remindAt,
    bool? isDone,
  }) {
    return Reminder(
      id: id,
      userId: userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      remindAt: remindAt ?? this.remindAt,
      notificationId: notificationId,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'notes': notes,
      'remindAt': remindAt.toIso8601String(),
      'notificationId': notificationId,
      'isDone': isDone,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      notes: (json['notes'] as String?) ?? '',
      remindAt: DateTime.parse(json['remindAt'] as String),
      notificationId: json['notificationId'] as int,
      isDone: (json['isDone'] as bool?) ?? false,
    );
  }
}
