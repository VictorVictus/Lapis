import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:to_do_app/models/user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer';

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    // Initialize GoogleSignIn for mobile only
    if (!kIsWeb) {
      _googleSignIn = GoogleSignIn();
    }
  }

  Future<User?> _handleFirebaseUser(firebase_auth.User firebaseUser, {String? username}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return User(
          uid: firebaseUser.uid,
          username: data['username'] ?? firebaseUser.displayName ?? '',
          email: data['email'] ?? firebaseUser.email ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? firebaseUser.metadata.creationTime,
          profilePictureUrl: data['profilePictureUrl'] ?? firebaseUser.photoURL,
        );
      } else {
        final newUser = User(
          uid: firebaseUser.uid,
          username: username ?? firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
          email: firebaseUser.email ?? '',
          createdAt: DateTime.now(),
          profilePictureUrl: firebaseUser.photoURL,
        );

        await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).set({
          'uid': newUser.uid,
          'email': newUser.email,
          'username': newUser.username,
          'createdAt': FieldValue.serverTimestamp(),
          'profilePictureUrl': newUser.profilePictureUrl,
        });

        return newUser;
      }
    } catch (e) {
      log('Error handling user data: $e');
      return User(
        uid: firebaseUser.uid,
        username: firebaseUser.displayName ?? '',
        email: firebaseUser.email ?? '',
        createdAt: firebaseUser.metadata.creationTime,
      );
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (credential.user == null) return null;
      return await _handleFirebaseUser(credential.user!);
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
      
      return await _handleFirebaseUser(user, username: username);
    } on firebase_auth.FirebaseAuthException catch (e) {
      String errorMessage = 'Error: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(errorMessage)),
      );
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // For web - use popup similar to GitHub
        final googleProvider = firebase_auth.GoogleAuthProvider();
        final firebase_auth.UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        
        if (userCredential.user == null) return null;
        return await _handleFirebaseUser(userCredential.user!);
      } else {
        // For mobile - use GoogleSignIn package
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        final firebaseCredential = await _auth.signInWithCredential(credential);
        if (firebaseCredential.user == null) return null;
        
        return await _handleFirebaseUser(firebaseCredential.user!);
      }
    } catch (e) {
      log('Error Google Sign-In: $e');
      return null;
    }
  }

  Future<User?> signInWithApple() async {
    if (kIsWeb) {
      log('Apple Sign-In is not available on web');
      return null;
    }
    
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final credential = firebase_auth.OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final firebaseCredential = await _auth.signInWithCredential(credential);
      if (firebaseCredential.user == null) return null;

      return await _handleFirebaseUser(firebaseCredential.user!);
    } catch (e) {
      log('Error Apple Sign-In: $e');
      return null;
    }
  }

  Future<User?> signInWithGitHub() async {
    try {
      final githubProvider = firebase_auth.GithubAuthProvider();
      
      firebase_auth.UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await _auth.signInWithPopup(githubProvider);
      } else {
        userCredential = await _auth.signInWithProvider(githubProvider);
      }
      
      if (userCredential.user == null) return null;
      return await _handleFirebaseUser(userCredential.user!);
    } catch (e) {
      log('Error GitHub Sign-In: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }
}