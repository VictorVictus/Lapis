class Section {
  final String id;
  final String name;
  final int order;
  final String userId;

  Section({
    required this.id,
    required this.name,
    required this.order,
    required this.userId,
  });

  factory Section.fromMap(Map<String, dynamic> map, String id) {
    return Section(
      id: id,
      name: map['name'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      userId: map['userId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'order': order,
      'userId': userId,
    };
  }

  Section copyWith({
    String? id,
    String? name,
    int? order,
    String? userId,
  }) {
    return Section(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      userId: userId ?? this.userId,
    );
  }
}
