import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages the lightweight "shared account" link between two users so each
/// can browse the other's library read-only. Deliberately minimal: a single
/// `linkedUid` field per user, resolved by email lookup rather than raw UID
/// copy-paste. Profile docs (displayName/email/linkedUid) are readable by
/// any authenticated user of the app — see firestore.rules — since this is a
/// small personal app between people who already know each other; only the
/// actual library/lists data stays gated behind a true mutual link.
class LinkService {
  final FirebaseFirestore _firestore;

  LinkService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _firestore.collection('users').doc(uid);

  Future<void> ensureProfile({required String uid, String? displayName, String? email}) {
    return _userDoc(uid).set({
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email.toLowerCase(),
    }, SetOptions(merge: true));
  }

  Stream<String?> watchOwnLinkedUid(String uid) {
    return _userDoc(uid).snapshots().map((doc) => doc.data()?['linkedUid'] as String?);
  }

  Future<void> setLinkedUid({required String uid, required String? linkedUid}) {
    return _userDoc(uid).set({'linkedUid': linkedUid}, SetOptions(merge: true));
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
