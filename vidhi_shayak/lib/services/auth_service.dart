import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth changes
  Stream<User?> get userChanges => _auth.authStateChanges();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // The user canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google [UserCredential]
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      return null;
    }
  }

  // Check if user profile is fully set up (has DOB)
  Future<bool> checkUserExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      // It only counts as "existing" if it has the 'dob' field set
      return doc.exists &&
          doc.data()!.containsKey('dob') &&
          doc.data()!['dob'] != null;
    } catch (e) {
      debugPrint("Error checking user existence: $e");
      return false;
    }
  }

  // Save User Profile to Firestore (Public for Profile Setup Screen)
  Future<void> saveUserProfile(
    User user, {
    required String name,
    required String dob,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);

      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': name, // Use the name provided in setup
        'dob': dob,
        'photoURL': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        // Default to free tier
        'accountType': 'free',
        'usage_stats': {
          'text': {
            'daily_count': 0,
            'last_updated': FieldValue.serverTimestamp(),
            'lock_until': null,
          },
          'voice': {
            'daily_count': 0,
            'last_updated': FieldValue.serverTimestamp(),
            'lock_until': null,
          },
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving user profile: $e");
      rethrow; // Rethrow so the UI can handle it
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Disconnect ensuring Google asks for permissions again on next login
      await _googleSignIn.disconnect();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }
}
