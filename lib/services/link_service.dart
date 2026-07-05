import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages the lightweight "shared account" link between two users so each
/// can browse the other's library read-only. Deliberately minimal: a single
/// `linkedUid` field per user, made visible to each other only once both
/// sides point at one another (see firestore.rules).
class LinkService {
  final FirebaseFirestore _firestore;

  LinkService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _firestore.collection('users').doc(uid);

  Future<void> ensureProfile({required String uid, String? displayName, String? email}) {
    return _userDoc(uid).set({
      if (displayName != null) 'displayName': displayName,
      if (email != null) 'email': email,
    }, SetOptions(merge: true));
  }

  Stream<String?> watchOwnLinkedUid(String uid) {
    return _userDoc(uid).snapshots().map((doc) => doc.data()?['linkedUid'] as String?);
  }

  Future<void> setLinkedUid({required String uid, required String? linkedUid}) {
    return _userDoc(uid).set({'linkedUid': linkedUid}, SetOptions(merge: true));
  }

  /// Fetches the other user's small profile doc (displayName/linkedUid only).
  /// Only readable once this user has pointed their own linkedUid at them —
  /// see firestore.rules — so this returns null until that's done.
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _userDoc(uid).get();
    return doc.data();
  }
}
