import 'package:to_do_app/core/safe_index.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';
import 'package:to_do_app/models/subclasses/recurrent_configuration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { undone, inProgress, fulfilled }

enum TaskType { oneTime, recurrent }

enum TaskPriority { none, low, medium, high }

extension TaskPriorityDisplay on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.none:
        return 'None';
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }
}

class Task {
  final String id;
  final String userId; // Correct: tracking who created this
  String title;
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
  DateTime? archivedAt;
  bool isArchived;
  bool pinned;
  double order;
  String? groupId;
  String? groupName;
  String? completedBy;
  String? assignedTo;
  List<String> labelIds;
  String? section;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.createdAt,
    this.order = 0,
    this.status = TaskStatus.undone,
    this.type = TaskType.oneTime,
    this.priority = TaskPriority.none,
    this.scheduledAt,
    this.deadline,
    this.recurrentConfig,
    this.notes,
    this.completedAt,
    this.archivedAt,
    this.isArchived = false,
    this.pinned = false,
    this.groupId,
    this.groupName,
    this.completedBy,
    this.assignedTo,
    this.labelIds = const [],
    this.section,
  });

  factory Task.fromMap(Map<String, dynamic> map, String id) {
    TaskCategory safeCategory(dynamic raw) {
      if (raw is Map<String, dynamic>) {
        return TaskCategory.fromMap(raw);
      }
      return TaskCategory(id: 'unknown', name: 'General', color: 0xFF9E9E9E);
    }

    return Task(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      status: TaskStatus.values[safeIndex(TaskStatus.values, map['status'], 0)],
      type: TaskType.values[safeIndex(TaskType.values, map['type'], 0)],
      priority: TaskPriority.values[safeIndex(TaskPriority.values, map['priority'], 0)],
      category: safeCategory(map['category']),
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      recurrentConfig: map['recurrentConfig'] is Map
          ? RecurrentConfig.fromMap(map['recurrentConfig'] as Map<String, dynamic>)
          : null,
      notes: map['notes'] as String?,
      order: (map['order'] as num?)?.toDouble() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      archivedAt: (map['archivedAt'] as Timestamp?)?.toDate(),
      isArchived: map['isArchived'] as bool? ?? false,
      pinned: map['pinned'] as bool? ?? false,
      groupId: map['groupId'] as String?,
      groupName: map['groupName'] as String?,
      completedBy: map['completedBy'] as String?,
      assignedTo: map['assignedTo'] as String?,
      labelIds: (map['labelIds'] as List<dynamic>?)?.cast<String>() ?? [],
      section: map['section'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'status': status.index,
      'type': type.index,
      'priority': priority.index,
      'category': category.toMap(),
      'scheduledAt': scheduledAt,
      'deadline': deadline,
      'recurrentConfig': recurrentConfig?.toMap(),
      'notes': notes,
      'order': order,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'archivedAt': archivedAt,
      'isArchived': isArchived,
      'pinned': pinned,
      'groupId': groupId,
      'groupName': groupName,
      'completedBy': completedBy,
      'assignedTo': assignedTo,
      'labelIds': labelIds,
      'section': section,
    };
  }

  Task copyWith({
    String? title,
    TaskStatus? status,
    TaskType? type,
    TaskPriority? priority,
    TaskCategory? category,
    DateTime? scheduledAt,
    DateTime? deadline,
    RecurrentConfig? recurrentConfig,
    String? notes,
    DateTime? completedAt,
    DateTime? archivedAt,
    bool? isArchived,
    bool? pinned,
    double? order,
    String? groupId,
    String? groupName,
    String? completedBy,
    String? assignedTo,
    List<String>? labelIds,
    String? section,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
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
      archivedAt: archivedAt ?? this.archivedAt,
      isArchived: isArchived ?? this.isArchived,
      pinned: pinned ?? this.pinned,
      order: order ?? this.order,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      completedBy: completedBy ?? this.completedBy,
      assignedTo: assignedTo ?? this.assignedTo,
      labelIds: labelIds ?? this.labelIds,
      section: section ?? this.section,
    );
  }
}
