class TaskCategory {
  final String id;
  final String name;
  final int color; // Color.value

  TaskCategory({required this.id, required this.name, required this.color});

  // Constructor desde Map (Firestore)
  factory TaskCategory.fromMap(Map<String, dynamic> map) {
    return TaskCategory(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      color: map['color'] ?? 0xFFFFFFFF, // blanco por defecto
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'color': color};
  }
}
