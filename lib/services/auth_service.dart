import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '993029568453-m7pb0jguqvatnl5826vb2ntr6hlu2h6f.apps.googleusercontent.com',
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Sync user profile with Firestore users/{uid}
  Future<void> _syncUserProfile(User user, {String? customName}) async {
    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);
      final doc = await userDocRef.get();
      if (!doc.exists) {
        await userDocRef.set({
          'displayName': customName ?? user.displayName ?? 'BillWave User',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });

        // Initialize default business profile if not existing
        await userDocRef.collection('settings').doc('business').set({
          'businessName': '${user.displayName ?? "My"} Store',
          'address': 'Main Commercial Street',
          'phone': '+91 98765 43210',
          'currency': '₹',
          'configuredTaxRates': [0.0, 5.0, 12.0, 18.0, 28.0],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userDocRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          if (user.displayName != null && user.displayName!.isNotEmpty)
            'displayName': user.displayName,
          if (user.photoURL != null && user.photoURL!.isNotEmpty)
            'photoURL': user.photoURL,
        });
      }
    } catch (e) {
      debugPrint('Error syncing user profile: $e');
    }
  }

  /// Official Google Sign-In Flow
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.addScope('email');
        authProvider.addScope('profile');
        final credential = await _auth.signInWithPopup(authProvider);
        if (credential.user != null) {
          await _syncUserProfile(credential.user!);
        }
        return credential;
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          // The user canceled the sign-in
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCred = await _auth.signInWithCredential(credential);
        if (userCred.user != null) {
          await _syncUserProfile(userCred.user!);
        }
        return userCred;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException during Google Sign-In: ${e.code} - ${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Sign In with Email & Password
  Future<UserCredential> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null) {
        await _syncUserProfile(cred.user!);
      }
      return cred;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Sign Up with Email & Password
  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null) {
        await cred.user!.updateDisplayName(displayName);
        await _syncUserProfile(cred.user!, customName: displayName);
      }
      return cred;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Instant Demo Business Account Sign In (for rapid evaluation & testing)
  Future<UserCredential> signInDemoAccount() async {
    try {
      // Use anonymous or demo credentials
      final cred = await _auth.signInAnonymously();
      if (cred.user != null) {
        await _syncUserProfile(cred.user!, customName: 'Demo Merchant');
      }
      return cred;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
