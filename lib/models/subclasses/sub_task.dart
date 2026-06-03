class SubTask {
  final String id;
  final String taskId;
  final String userId;
  String title;
  bool isDone;
  int order;

  SubTask({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.title,
    this.isDone = false,
    this.order = 0,
  });

  factory SubTask.fromMap(Map<String, dynamic> map, String id) {
    return SubTask(
      id: id,
      taskId: map['taskId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      isDone: map['isDone'] as bool? ?? false,
      order: (map['order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'userId': userId,
      'title': title,
      'isDone': isDone,
      'order': order,
    };
  }

  SubTask copyWith({
    String? title,
    bool? isDone,
    int? order,
  }) {
    return SubTask(
      id: id,
      taskId: taskId,
      userId: userId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      order: order ?? this.order,
    );
  }
}
