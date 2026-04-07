import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { undone, inProgress, fulfilled }

enum TaskType { oneTime, recurrent }

enum TaskPriority { none, low, medium, high }

class Task {
  final String id;
  final String userId; // Correct: tracking who created this
  String title;
  String? description;
  TaskStatus status;
  TaskType type;
  TaskPriority priority;
  TaskCategory category;
  DateTime? scheduledAt;
  DateTime? deadline;
  RecurrentConfig? recurrentConfig;
  String? notes;
  final DateTime createdAt;
  DateTime? completedAt;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.createdAt,
    this.description,
    this.status = TaskStatus.undone,
    this.type = TaskType.oneTime,
    this.priority = TaskPriority.none,
    this.scheduledAt,
    this.deadline,
    this.recurrentConfig,
    this.notes,
    this.completedAt,
  });

  factory Task.fromMap(Map<String, dynamic> map, String id) {
    return Task(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      status: TaskStatus.values[map['status'] ?? 0],
      type: TaskType.values[map['type'] ?? 0],
      priority: TaskPriority.values[map['priority'] ?? 0],
      category: TaskCategory.fromMap(map['category']),
      scheduledAt: map['scheduledAt'] != null
          ? (map['scheduledAt'] as Timestamp).toDate()
          : null,
      deadline: map['deadline'] != null
          ? (map['deadline'] as Timestamp).toDate()
          : null,
      recurrentConfig: map['recurrentConfig'] != null
          ? RecurrentConfig.fromMap(map['recurrentConfig'])
          : null,
      notes: map['notes'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'status': status.index,
      'type': type.index,
      'priority': priority.index,
      'category': category.toMap(),
      'scheduledAt': scheduledAt,
      'deadline': deadline,
      'recurrentConfig': recurrentConfig?.toMap(),
      'notes': notes,
      'createdAt': createdAt,
      'completedAt': completedAt,
    };
  }

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskType? type,
    TaskPriority? priority,
    TaskCategory? category,
    DateTime? scheduledAt,
    DateTime? deadline,
    RecurrentConfig? recurrentConfig,
    String? notes,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      deadline: deadline ?? this.deadline,
      recurrentConfig: recurrentConfig ?? this.recurrentConfig,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
