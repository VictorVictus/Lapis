import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final String inviteCode;
  final DateTime createdAt;
  final int memberCount;

  Group({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.inviteCode,
    required this.createdAt,
    this.memberCount = 1,
  });

  factory Group.fromMap(Map<String, dynamic> map, String id) {
    return Group(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      inviteCode: map['inviteCode'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberCount': memberCount,
    };
  }

  Group copyWith({
    String? name,
    String? description,
    String? inviteCode,
    int? memberCount,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdBy: createdBy,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}

class GroupMember {
  final String uid;
  final String role;
  final DateTime joinedAt;
  final String username;

  GroupMember({
    required this.uid,
    required this.role,
    required this.joinedAt,
    required this.username,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map, String uid) {
    return GroupMember(
      uid: uid,
      role: map['role'] as String? ?? 'member',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      username: map['username'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'username': username,
    };
  }
}
