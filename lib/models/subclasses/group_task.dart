import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:to_do_app/core/safe_index.dart';
import 'package:to_do_app/models/task.dart';
import 'package:to_do_app/models/subclasses/sub_task.dart';
import 'package:to_do_app/models/subclasses/task_category.dart';

class GroupTask {
  final String id;
  final String groupId;
  String title;
  TaskStatus status;
  TaskPriority priority;
  TaskCategory category;
  DateTime? scheduledAt;
  DateTime? deadline;
  String? assignedTo;
  final String createdBy;
  String? completedBy;
  DateTime? completedAt;
  String? notes;
  double order;
  final DateTime createdAt;
  List<String> labelIds;
  String? section;

  GroupTask({
    required this.id,
    required this.groupId,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    this.status = TaskStatus.undone,
    this.priority = TaskPriority.none,
    TaskCategory? category,
    this.scheduledAt,
    this.deadline,
    this.assignedTo,
    this.completedBy,
    this.completedAt,
    this.notes,
    this.order = 0,
    this.labelIds = const [],
    this.section,
  }) : category = category ?? TaskCategory(id: 'uncategorized', name: 'General', color: 0xFF9E9E9E);

  factory GroupTask.fromMap(Map<String, dynamic> map, String id, {required String groupId}) {
    return GroupTask(
      id: id,
      groupId: groupId,
      title: map['title'] as String? ?? '',
      status: TaskStatus.values[safeIndex(TaskStatus.values, map['status'], 0)],
      priority: TaskPriority.values[safeIndex(TaskPriority.values, map['priority'], 0)],
      category: map['category'] is Map<String, dynamic>
          ? TaskCategory.fromMap(map['category'] as Map<String, dynamic>)
          : TaskCategory(id: 'uncategorized', name: 'General', color: 0xFF9E9E9E),
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      assignedTo: map['assignedTo'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      completedBy: map['completedBy'] as String?,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
      order: (map['order'] as num?)?.toDouble() ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      labelIds: (map['labelIds'] as List<dynamic>?)?.cast<String>() ?? [],
      section: map['section'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'status': status.index,
      'priority': priority.index,
      'category': category.toMap(),
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'completedBy': completedBy,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'notes': notes,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
      'labelIds': labelIds,
      'section': section,
    };
  }

  Task toTask({String? groupName}) {
    return Task(
      id: id,
      userId: createdBy,
      title: title,
      category: category,
      createdAt: createdAt,
      status: status,
      priority: priority,
      scheduledAt: scheduledAt,
      deadline: deadline,
      notes: notes,
      order: order,
      completedAt: completedAt,
      completedBy: completedBy,
      groupId: groupId,
      groupName: groupName,
      assignedTo: assignedTo,
      labelIds: labelIds,
      section: section,
    );
  }

  GroupTask copyWith({
    String? title,
    TaskStatus? status,
    TaskPriority? priority,
    TaskCategory? category,
    DateTime? scheduledAt,
    DateTime? deadline,
    String? assignedTo,
    String? completedBy,
    DateTime? completedAt,
    String? notes,
    double? order,
    List<String>? labelIds,
    String? section,
  }) {
    return GroupTask(
      id: id,
      groupId: groupId,
      title: title ?? this.title,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      deadline: deadline ?? this.deadline,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      order: order ?? this.order,
      createdAt: createdAt,
      labelIds: labelIds ?? this.labelIds,
      section: section ?? this.section,
    );
  }
}

class GroupSubTask {
  final String id;
  final String groupTaskId;
  String title;
  bool isDone;
  String? doneBy;
  int order;
  TaskPriority priority;
  DateTime? scheduledAt;
  DateTime? deadline;
  String? notes;

  GroupSubTask({
    required this.id,
    required this.groupTaskId,
    required this.title,
    this.isDone = false,
    this.doneBy,
    this.order = 0,
    this.priority = TaskPriority.none,
    this.scheduledAt,
    this.deadline,
    this.notes,
  });

  factory GroupSubTask.fromMap(Map<String, dynamic> map, String id, {required String groupTaskId}) {
    return GroupSubTask(
      id: id,
      groupTaskId: groupTaskId,
      title: map['title'] as String? ?? '',
      isDone: map['isDone'] as bool? ?? false,
      doneBy: map['doneBy'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      priority: TaskPriority.values[safeIndex(TaskPriority.values, map['priority'], 0)],
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupTaskId': groupTaskId,
      'title': title,
      'isDone': isDone,
      'doneBy': doneBy,
      'order': order,
      'priority': priority.index,
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'notes': notes,
    };
  }

  GroupSubTask copyWith({
    String? title,
    bool? isDone,
    String? doneBy,
    int? order,
    TaskPriority? priority,
    DateTime? scheduledAt,
    DateTime? deadline,
    String? notes,
  }) {
    return GroupSubTask(
      id: id,
      groupTaskId: groupTaskId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      doneBy: doneBy ?? this.doneBy,
      order: order ?? this.order,
      priority: priority ?? this.priority,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
    );
  }

  SubTask toSubTask() {
    return SubTask(
      id: id,
      taskId: groupTaskId,
      userId: '',
      title: title,
      isDone: isDone,
      order: order,
      priority: priority,
      scheduledAt: scheduledAt,
      deadline: deadline,
      notes: notes,
    );
  }

  factory GroupSubTask.fromSubTask(SubTask subTask, {required String groupTaskId}) {
    return GroupSubTask(
      id: subTask.id,
      groupTaskId: groupTaskId,
      title: subTask.title,
      isDone: subTask.isDone,
      order: subTask.order,
      priority: subTask.priority,
      scheduledAt: subTask.scheduledAt,
      deadline: subTask.deadline,
      notes: subTask.notes,
    );
  }
}

extension TaskGroupConversion on Task {
  GroupTask toGroupTask() {
    return GroupTask(
      id: id,
      groupId: groupId ?? '',
      title: title,
      createdBy: userId,
      createdAt: createdAt,
      status: status,
      priority: priority,
      category: category,
      scheduledAt: scheduledAt,
      deadline: deadline,
      completedBy: completedBy,
      completedAt: completedAt,
      notes: notes,
      order: order,
      assignedTo: assignedTo,
      labelIds: labelIds,
      section: section,
    );
  }
}
