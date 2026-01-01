import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Maximum words allowed per day for free tier
  static const int maxDailyWords = 1000;

  // Get current user ID safely
  String? get _uid => _auth.currentUser?.uid;

  // 🔹 Ensure User Document Exists
  Future<void> _ensureUserExists() async {
    if (_uid == null) return;
    final userRef = _firestore.collection('users').doc(_uid);
    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        'uid': _uid,
        'email': _auth.currentUser?.email,
        'createdAt': FieldValue.serverTimestamp(),
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
    }
  }

  // 🔹 Create a New Chat Session (No Limit Check Here anymore)
  Future<String> createNewSession(String category, String firstMessage) async {
    if (_uid == null) throw Exception("User not logged in");

    await _ensureUserExists(); // Ensure parent doc exists

    // Create session doc directly
    String title = firstMessage.length > 30
        ? "${firstMessage.substring(0, 30)}..."
        : firstMessage;

    final docRef = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        .add({
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': firstMessage,
          'title': title,
          'category': category,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    return docRef.id;
  }

  // 🔹 Check Daily Usage Limit (Combined Text + Voice)
  // Returns null if allowed, or a String message if blocked
  Future<String?> checkUsage(String type, int estimatedWords) async {
    if (_uid == null) return null;

    final userDoc = await _firestore.collection('users').doc(_uid).get();
    if (!userDoc.exists) return null;

    final data = userDoc.data()!;
    final stats = data['usage_stats'] as Map<String, dynamic>? ?? {};

    // Get stats for both types
    final textStats = stats['text'] as Map<String, dynamic>? ?? {};
    final voiceStats = stats['voice'] as Map<String, dynamic>? ?? {};

    // Helper to get count for a type, resetting if new day
    int getValidCount(Map<String, dynamic> typeStats) {
      final Timestamp? lastUpdated = typeStats['last_updated'] as Timestamp?;
      final int currentCount = typeStats['daily_count'] ?? 0;

      if (lastUpdated != null) {
        final lastDate = lastUpdated.toDate();
        final now = DateTime.now();
        if (lastDate.day != now.day ||
            lastDate.month != now.month ||
            lastDate.year != now.year) {
          return 0; // New day, count is effectively 0
        }
      }
      return currentCount;
    }

    final int textCount = getValidCount(textStats);
    final int voiceCount = getValidCount(voiceStats);
    final int totalCurrentUsage = textCount + voiceCount;

    if (totalCurrentUsage + estimatedWords > maxDailyWords) {
      if (totalCurrentUsage >= maxDailyWords) {
        return "Daily limit of $maxDailyWords words reached. Try again tomorrow.";
      }
      return "Message too long. You have ${maxDailyWords - totalCurrentUsage} words remaining.";
    }

    return null;
  }

  // 🔹 Increment Usage
  Future<void> incrementUsage(String type, int wordCount) async {
    if (_uid == null) return;

    await _ensureUserExists();

    final userRef = _firestore.collection('users').doc(_uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      var stats = Map<String, dynamic>.from(data['usage_stats'] ?? {});
      var typeStats = Map<String, dynamic>.from(stats[type] ?? {});

      final Timestamp? lastUpdated = typeStats['last_updated'] as Timestamp?;
      int currentCount = typeStats['daily_count'] ?? 0;

      final now = DateTime.now();

      // Reset if new day
      if (lastUpdated != null) {
        final lastDate = lastUpdated.toDate();
        if (lastDate.day != now.day ||
            lastDate.month != now.month ||
            lastDate.year != now.year) {
          currentCount = 0;
        }
      }

      final newCount = currentCount + wordCount;
      typeStats['daily_count'] = newCount;
      typeStats['last_updated'] = FieldValue.serverTimestamp();
      typeStats['lock_until'] = null; // Removing legacy lock field use

      stats[type] = typeStats;
      transaction.update(userRef, {'usage_stats': stats});
    });
  }

  // 🔹 Send Message
  Future<void> sendMessage({
    required String sessionId,
    required String text,
    required bool isUser,
  }) async {
    if (_uid == null) return;

    // Add message to subcollection
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .add({
          'text': text,
          'isUser': isUser,
          'timestamp': FieldValue.serverTimestamp(),
        });

    // Update last message in session doc
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        .doc(sessionId)
        .update({
          'lastMessage': text,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  // 🔹 Get Stream of Chat Sessions (for Drawer)
  Stream<QuerySnapshot> getChatSessions() {
    if (_uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        // .orderBy('updatedAt', descending: true) // Commented out to potentially fix "Error loading history" if index is missing
        .snapshots();
  }

  // 🔹 Get Stream of Messages (for Chat Screen)
  Stream<QuerySnapshot> getMessages(String sessionId) {
    if (_uid == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // 🔹 Delete a Session
  Future<void> deleteSession(String sessionId) async {
    if (_uid == null) return;

    final messages = await _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        .doc(sessionId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete parent doc
    final sessionRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        .doc(sessionId);

    batch.delete(sessionRef);

    await batch.commit();
  }

  // 🔹 Rename Session (Optional, for better UX later)
  Future<void> renameSession(String sessionId, String newTitle) async {
    if (_uid == null) return;
    await _firestore
        .collection('users')
        .doc(_uid)
        .collection('chat_sessions')
        .doc(sessionId)
        .update({'title': newTitle});
  }
}
