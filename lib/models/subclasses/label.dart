class Label {
  final String id;
  final String name;
  final int color;
  final String userId;

  const Label({
    required this.id,
    required this.name,
    required this.color,
    required this.userId,
  });

  factory Label.fromMap(Map<String, dynamic> map, String id) {
    return Label(
      id: id,
      name: map['name'] as String? ?? '',
      color: map['color'] as int? ?? 0xFF9E9E9E,
      userId: map['userId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color,
      'userId': userId,
    };
  }

  Label copyWith({
    String? name,
    int? color,
  }) {
    return Label(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      userId: userId,
    );
  }
}
