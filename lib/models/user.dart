import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String _uid;
  final String _username;
  final String _email;
  final DateTime _createdAt;

  User({
    required String uid,
    required String username,
    required String email,
    DateTime? createdAt,
  })  : _uid = uid,
        _username = username,
        _email = email,
        _createdAt = createdAt ?? DateTime.now();

  String get uid => _uid;
  String get username => _username;
  String get email => _email;
  DateTime get createdAt => _createdAt;

  /// First character of username for avatar placeholders.
  String get initial {
    final trimmed = _username.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  factory User.fromMap(Map<String, dynamic> map, [String? docId]) {
    return User(
      uid: map['uid'] ?? docId ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  User copyWith({String? username, String? email}) {
    return User(
      uid: _uid,
      username: username ?? _username,
      email: email ?? _email,
      createdAt: _createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': _uid,
      'username': _username,
      'email': _email,
      'createdAt': _createdAt,
    };
  }
}
