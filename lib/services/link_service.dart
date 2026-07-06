import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages a one-directional "friends" list per user: adding someone by
/// email lets you view their library right away, with no reciprocation
/// required (like following someone on TV Time) — this is a small personal
/// app between people who already know each other, so that tradeoff is
/// accepted. Profile docs (displayName/email/photoUrl/friendUids) are
/// readable by any authenticated user — see firestore.rules — since the
/// email -> uid lookup needs to scan across users; only the actual
/// library/lists data is gated (readable by whoever has you in their own
/// friendUids).
class LinkService {
  final FirebaseFirestore _firestore;

  LinkService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _firestore.collection('users').doc(uid);

  Future<void> ensureProfile({required String uid, String? displayName, String? email, String? photoUrl}) {
    return _userDoc(uid).set({
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email.toLowerCase(),
      if (photoUrl != null) 'photoUrl': photoUrl,
    }, SetOptions(merge: true));
  }

  Stream<List<String>> watchFriendUids(String uid) {
    return _userDoc(uid).snapshots().map((doc) {
      final list = doc.data()?['friendUids'] as List<dynamic>?;
      return list?.cast<String>() ?? const [];
    });
  }

  Future<void> addFriend({required String uid, required String friendUid}) {
    return _userDoc(uid).set({
      'friendUids': FieldValue.arrayUnion([friendUid]),
    }, SetOptions(merge: true));
  }

  Future<void> removeFriend({required String uid, required String friendUid}) {
    return _userDoc(uid).update({
      'friendUids': FieldValue.arrayRemove([friendUid]),
    });
  }

  /// Looks up a user's uid by their sign-in email. Returns null if no one
  /// with that email has ever opened the app.
  Future<String?> findUidByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _userDoc(uid).get();
    return doc.data();
  }
}
