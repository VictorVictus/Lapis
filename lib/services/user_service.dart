import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/user.dart';

final userServiceProvider = Provider((ref) => UserService());

/// User profile reads from Firestore only (Spark / no Firebase Storage).
class UserService {
  Stream<User?> getUserStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return User.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
    });
  }
}
