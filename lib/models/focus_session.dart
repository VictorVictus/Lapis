import 'package:cloud_firestore/cloud_firestore.dart';

class FocusSession {
  final String id;
  final String userId;
  final String taskId;
  final String taskTitle;
  final int durationSeconds;
  final DateTime createdAt;

  FocusSession({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.taskTitle,
    required this.durationSeconds,
    required this.createdAt,
  });

  factory FocusSession.fromMap(Map<String, dynamic> map, String id) {
    return FocusSession(
      id: id,
      userId: map['userId'] as String? ?? '',
      taskId: map['taskId'] as String? ?? '',
      taskTitle: map['taskTitle'] as String? ?? '',
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  FocusSession copyWith({
    String? userId,
    String? taskId,
    String? taskTitle,
    int? durationSeconds,
    DateTime? createdAt,
  }) {
    return FocusSession(
      id: id,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'durationSeconds': durationSeconds,
      'createdAt': createdAt,
    };
  }
}
