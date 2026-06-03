import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:to_do_app/core/firebase_bootstrap.dart';
import 'package:to_do_app/core/legal_config.dart';
import 'package:to_do_app/models/auth_result.dart';
import 'package:to_do_app/models/user.dart';
import 'package:to_do_app/services/auth_validator.dart';
import 'package:to_do_app/services/fcm_service.dart';
import 'package:to_do_app/services/password_strength.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;

  AuthService() {
    if (!kIsWeb) {
      _googleSignIn = GoogleSignIn();
    }
  }

  /// Resolves or creates the Firestore user profile for a signed-in Firebase user.
  Future<User?> resolveAppUser(
    firebase_auth.User firebaseUser, {
    String? username,
    bool recordTermsAcceptance = false,
  }) async {
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
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
              firebaseUser.metadata.creationTime,
        );
      }

      final newUser = User(
        uid: firebaseUser.uid,
        username: username ??
            firebaseUser.displayName ??
            firebaseUser.email?.split('@').first ??
            'User',
        email: firebaseUser.email ?? '',
        createdAt: DateTime.now(),
      );

      final userData = <String, dynamic>{
        'uid': newUser.uid,
        'email': newUser.email,
        'username': newUser.username,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (recordTermsAcceptance) {
        userData.addAll(_termsAcceptanceFields());
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set(userData);

      unawaited(_storeFcmToken());
      return newUser;
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

  Map<String, dynamic> _termsAcceptanceFields() {
    return {
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': LegalConfig.termsVersion,
      'privacyPolicyVersion': LegalConfig.privacyPolicyVersion,
    };
  }

  AuthResult _mapFirebaseAuthException(firebase_auth.FirebaseAuthException e) {
    final code = switch (e.code) {
      'invalid-email' => AuthFailureCode.invalidEmail,
      'weak-password' => AuthFailureCode.weakPassword,
      'email-already-in-use' => AuthFailureCode.emailAlreadyInUse,
      'wrong-password' || 'invalid-credential' => AuthFailureCode.wrongPassword,
      'user-not-found' => AuthFailureCode.userNotFound,
      'user-disabled' => AuthFailureCode.userDisabled,
      'too-many-requests' => AuthFailureCode.tooManyRequests,
      'network-request-failed' => AuthFailureCode.networkError,
      'requires-recent-login' => AuthFailureCode.requiresRecentLogin,
      _ => AuthFailureCode.unknown,
    };

    return AuthResult.failure(
      failureCode: code,
      message: _friendlyMessage(code, e.message),
    );
  }

  String _friendlyMessage(AuthFailureCode code, [String? firebaseMessage]) {
    return switch (code) {
      AuthFailureCode.invalidEmail => 'Enter a valid email address.',
      AuthFailureCode.invalidUsername =>
        'Username must be 3–24 characters (letters, numbers, . _ -).',
      AuthFailureCode.weakPassword =>
        'Password must be at least ${PasswordStrength.minLength} characters with upper, lower case, and a number.',
      AuthFailureCode.termsNotAccepted =>
        'Accept the Terms of Service and Privacy Policy to create an account.',
      AuthFailureCode.emailAlreadyInUse =>
        'An account with this email already exists. Try signing in.',
      AuthFailureCode.wrongPassword => 'Incorrect email or password.',
      AuthFailureCode.userNotFound => 'No account found for this email.',
      AuthFailureCode.userDisabled =>
        'This account has been disabled. Contact support.',
      AuthFailureCode.tooManyRequests =>
        'Too many attempts. Please wait and try again.',
      AuthFailureCode.networkError =>
        'Network error. Check your connection and try again.',
      AuthFailureCode.requiresRecentLogin =>
        'Please re-enter your password to confirm this action.',
      AuthFailureCode.cancelled => 'Sign-in was cancelled.',
      AuthFailureCode.unknown =>
        firebaseMessage ?? 'Something went wrong. Please try again.',
    };
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final emailErr = AuthValidator.emailError(email);
    if (emailErr != null) {
      return AuthResult.failure(
        failureCode: AuthFailureCode.invalidEmail,
        message: emailErr,
      );
    }
    if (password.trim().isEmpty) {
      return AuthResult.failure(
        failureCode: AuthFailureCode.weakPassword,
        message: 'Password is required.',
      );
    }

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      if (credential.user == null) {
        return const AuthResult.failure(
          failureCode: AuthFailureCode.unknown,
          message: 'Sign-in failed. Please try again.',
        );
      }
      final user = await resolveAppUser(credential.user!);
      if (user == null) {
        return const AuthResult.failure(
          failureCode: AuthFailureCode.unknown,
          message: 'Could not load your profile.',
        );
      }
      return AuthResult.success(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      log('Error signing in: $e');
      return _mapFirebaseAuthException(e);
    } catch (e) {
      log('Error signing in: $e');
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: _friendlyMessage(AuthFailureCode.unknown),
      );
    }
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String username,
    required bool termsAccepted,
  }) async {
    if (!termsAccepted) {
      return AuthResult.failure(
        failureCode: AuthFailureCode.termsNotAccepted,
        message: _friendlyMessage(AuthFailureCode.termsNotAccepted),
      );
    }

    final emailErr = AuthValidator.emailError(email);
    if (emailErr != null) {
      return AuthResult.failure(
        failureCode: AuthFailureCode.invalidEmail,
        message: emailErr,
      );
    }

    final usernameErr = AuthValidator.usernameError(username);
    if (usernameErr != null) {
      return AuthResult.failure(
        failureCode: AuthFailureCode.invalidUsername,
        message: usernameErr,
      );
    }

    final passwordErr = PasswordStrength.passwordError(password);
    if (passwordErr != null) {
      return AuthResult.failure(
        failureCode: AuthFailureCode.weakPassword,
        message: passwordErr,
      );
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return const AuthResult.failure(
          failureCode: AuthFailureCode.unknown,
          message: 'Registration failed. Please try again.',
        );
      }

      final user = await resolveAppUser(
        firebaseUser,
        username: username.trim(),
        recordTermsAcceptance: true,
      );
      if (user == null) {
        return const AuthResult.failure(
          failureCode: AuthFailureCode.unknown,
          message: 'Account created but profile could not be loaded.',
        );
      }

      unawaited(setCrashReportingConsent(true));
      return AuthResult.success(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      log('Error registering: $e');
      return _mapFirebaseAuthException(e);
    } catch (e) {
      log('Error registering: $e');
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: _friendlyMessage(AuthFailureCode.unknown),
      );
    }
  }

  Future<AuthResult> signInWithGoogle({bool recordTermsAcceptance = false}) async {
    try {
      firebase_auth.UserCredential userCredential;
      if (kIsWeb) {
        final googleProvider = firebase_auth.GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return AuthResult.failure(
            failureCode: AuthFailureCode.cancelled,
            message: _friendlyMessage(AuthFailureCode.cancelled),
          );
        }

        final googleAuth = await googleUser.authentication;
        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      if (userCredential.user == null) {
        return const AuthResult.failure(
          failureCode: AuthFailureCode.unknown,
          message: 'Google sign-in failed.',
        );
      }

      return _finishSocialSignIn(
        userCredential.user!,
        recordTermsAcceptance: recordTermsAcceptance,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      log('Error Google Sign-In: $e');
      return _mapFirebaseAuthException(e);
    } catch (e) {
      log('Error Google Sign-In: $e');
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: _friendlyMessage(AuthFailureCode.unknown),
      );
    }
  }

  Future<AuthResult> signInWithApple({bool recordTermsAcceptance = false}) async {
    if (kIsWeb) {
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: 'Apple Sign-In is not available on web.',
      );
    }

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final credential = firebase_auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user == null) {
        return const AuthResult.failure(
          failureCode: AuthFailureCode.unknown,
          message: 'Apple sign-in failed.',
        );
      }

      String? username;
      final given = appleCredential.givenName;
      final family = appleCredential.familyName;
      if (given != null || family != null) {
        username = [given, family].whereType<String>().join(' ').trim();
      }

      return _finishSocialSignIn(
        userCredential.user!,
        username: username,
        recordTermsAcceptance: recordTermsAcceptance,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.failure(
          failureCode: AuthFailureCode.cancelled,
          message: _friendlyMessage(AuthFailureCode.cancelled),
        );
      }
      log('Error Apple Sign-In: $e');
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: _friendlyMessage(AuthFailureCode.unknown),
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      log('Error Apple Sign-In: $e');
      return _mapFirebaseAuthException(e);
    } catch (e) {
      log('Error Apple Sign-In: $e');
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: _friendlyMessage(AuthFailureCode.unknown),
      );
    }
  }

  Future<AuthResult> signInWithGitHub({bool recordTermsAcceptance = false}) async {
    try {
      final githubProvider = firebase_auth.GithubAuthProvider();
      final firebase_auth.UserCredential userCredential;
      if (kIsWeb) {
        userCredential = await _auth.signInWithPopup(githubProvider);
      } else {
        userCredential = await _auth.signInWithProvider(githubProvider);
      }

      if (userCredential.user == null) {
        return const AuthResult.failure(
          failureCode: AuthFailureCode.unknown,
          message: 'GitHub sign-in failed.',
        );
      }

      return _finishSocialSignIn(
        userCredential.user!,
        recordTermsAcceptance: recordTermsAcceptance,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      log('Error GitHub Sign-In: $e');
      return _mapFirebaseAuthException(e);
    } catch (e) {
      log('Error GitHub Sign-In: $e');
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: _friendlyMessage(AuthFailureCode.unknown),
      );
    }
  }

  Future<AuthResult> _finishSocialSignIn(
    firebase_auth.User firebaseUser, {
    String? username,
    required bool recordTermsAcceptance,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    final isNewUser = !doc.exists;
    if (isNewUser && !recordTermsAcceptance) {
      await _auth.signOut();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      return AuthResult.failure(
        failureCode: AuthFailureCode.termsNotAccepted,
        message: _friendlyMessage(AuthFailureCode.termsNotAccepted),
      );
    }

    final user = await resolveAppUser(
      firebaseUser,
      username: username,
      recordTermsAcceptance: isNewUser && recordTermsAcceptance,
    );

    if (user == null) {
      return const AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: 'Could not load your profile.',
      );
    }

    return AuthResult.success(user);
  }

  Future<bool> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      final credential = firebase_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      log('Re-authentication failed: $e');
      return false;
    }
  }

  Future<void> _storeFcmToken() async {
    final user = _auth.currentUser;
    if (user == null || kIsWeb) return;
    final fcm = FcmService();
    final token = await fcm.getToken();
    if (token != null) {
      await fcm.storeToken(user.uid, token);
    }
  }

  Future<void> _removeFcmToken() async {
    final user = _auth.currentUser;
    if (user == null || kIsWeb) return;
    final fcm = FcmService();
    final token = await fcm.getToken();
    if (token != null) {
      await fcm.removeToken(user.uid, token);
    }
  }

  Future<void> signOut() async {
    await _removeFcmToken();
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<AuthResult> deleteAccount() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return const AuthResult.failure(
        failureCode: AuthFailureCode.userNotFound,
        message: 'No signed-in account found.',
      );
    }

    try {
      final uid = firebaseUser.uid;
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      batch.delete(firestore.collection('users').doc(uid));

      final tasks = await firestore
          .collection('tasks')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in tasks.docs) {
        batch.delete(doc.reference);
      }

      final categories = await firestore
          .collection('categories')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in categories.docs) {
        batch.delete(doc.reference);
      }

      final subtasks = await firestore
          .collection('subtasks')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in subtasks.docs) {
        batch.delete(doc.reference);
      }

      final focusSessions = await firestore
          .collection('focus_sessions')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in focusSessions.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      await firebaseUser.delete();

      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      return const AuthResult.success();
    } on firebase_auth.FirebaseAuthException catch (e) {
      return _mapFirebaseAuthException(e);
    } catch (e) {
      log('Error deleting account: $e');
      return AuthResult.failure(
        failureCode: AuthFailureCode.unknown,
        message: 'Could not delete account. You may need to sign in again first.',
      );
    }
  }
}
