import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/services/auth_service.dart';

/// Emits the signed-in app user, or null when logged out.
/// Listens to Firebase Auth and hydrates the Firestore profile.
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);

  return firebase_auth.FirebaseAuth.instance.authStateChanges().asyncMap(
    (firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }
      return authService.resolveAppUser(firebaseUser);
    },
  );
});
