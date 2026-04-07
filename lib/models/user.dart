import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String _uid;
  final String _username;
  final String _email;
  final DateTime _createdAt;
  final String? _profilePictureUrl;

  User({
    required String uid,
    required String username,
    required String email,
    DateTime? createdAt,
    String? profilePictureUrl,
  }) : _uid = uid,
       _username = username,
       _email = email,
       _createdAt = createdAt ?? DateTime.now(),
       _profilePictureUrl = profilePictureUrl;

  String get uid => _uid;
  String get username => _username;
  String get email => _email;
  DateTime get createdAt => _createdAt;
  String? get profilePictureUrl => _profilePictureUrl;

  /// Crear User desde Firebase Auth + Firestore
  factory User.fromFirebase(
    firebase_auth.User firebaseUser, {
    String? profilePictureUrl,
  }) {
    return User(
      uid: firebaseUser.uid,
      username: firebaseUser.displayName ?? '',
      email: firebaseUser.email ?? '',
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      profilePictureUrl: profilePictureUrl ?? firebaseUser.photoURL,
    );
  }

  factory User.fromFirestore(DocumentSnapshot doc) {
    return User.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Crear User desde un documento Firestore
  factory User.fromMap(Map<String, dynamic> map, [String? docId]) {
    return User(
      uid: map['uid'] ?? docId ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      profilePictureUrl: map['profilePictureUrl'],
    );
  }

  User copyWith({String? profilePictureUrl}) {
    return User(
      uid: _uid,
      username: _username,
      email: _email,
      createdAt: _createdAt,
      profilePictureUrl: profilePictureUrl ?? _profilePictureUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': _uid,
      'username': _username,
      'email': _email,
      'createdAt': _createdAt,
      'profilePictureUrl': _profilePictureUrl,
    };
  }
}
