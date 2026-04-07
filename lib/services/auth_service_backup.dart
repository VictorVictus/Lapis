import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/user.dart';
import 'dart:developer';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) return null;

      // Try Firestore, but don't let it block login
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          return User(
            uid: firebaseUser.uid,
            username: data['username'] ?? '',
            email: data['email'] ?? firebaseUser.email ?? '',
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ??
                firebaseUser.metadata.creationTime,
            profilePictureUrl: data['profilePictureUrl'],
          );
        }
      } catch (e) {
        log('Firestore fetch failed, using auth data: $e');
      }

      // Fallback: Firestore doc missing or Firestore failed
      return User(
        uid: firebaseUser.uid,
        username: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        createdAt: firebaseUser.metadata.creationTime,
      );
    } catch (e) {
      log('Error signing in: $e');
      return null;
    }
  }

  Future<User?> register(
    BuildContext context,
    String email,
    String password,
    String username,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) return null;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid, // CRITICAL: Save the uid inside the document
        'email': email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return User(
        uid: user.uid,
        username: username,
        email: email,
        createdAt: DateTime.now(),
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'This e-mail already is in use.';
          break;
        case 'invalid-email':
          errorMessage = 'This e-mail is invalid.';
          break;
        default:
          errorMessage = 'Error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error! ${errorMessage}'),
        ),
      );
      return null;
    }
  }
}
