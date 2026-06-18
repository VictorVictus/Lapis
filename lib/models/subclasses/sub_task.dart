import 'package:to_do_app/core/safe_index.dart';
import 'package:to_do_app/models/task.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubTask {
  final String id;
  final String taskId;
  final String userId;
  String title;
  bool isDone;
  int order;
  TaskPriority priority;
  DateTime? scheduledAt;
  DateTime? deadline;
  String? notes;

  SubTask({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.title,
    this.isDone = false,
    this.order = 0,
    this.priority = TaskPriority.none,
    this.scheduledAt,
    this.deadline,
    this.notes,
  });

  factory SubTask.fromMap(Map<String, dynamic> map, String id) {
    return SubTask(
      id: id,
      taskId: map['taskId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isDone: map['isDone'] as bool? ?? false,
      order: (map['order'] as num?)?.toInt() ?? 0,
      priority: TaskPriority.values[safeIndex(TaskPriority.values, map['priority'], 0)],
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'userId': userId,
      'title': title,
      'isDone': isDone,
      'order': order,
      'priority': priority.index,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'notes': notes,
    };
  }

  SubTask copyWith({
    String? title,
    bool? isDone,
    int? order,
    TaskPriority? priority,
    DateTime? scheduledAt,
    DateTime? deadline,
    String? notes,
  }) {
    return SubTask(
      id: id,
      taskId: taskId,
      userId: userId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      order: order ?? this.order,
      priority: priority ?? this.priority,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
    );
  }
}
