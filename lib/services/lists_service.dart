import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/watch_list.dart';

class ListsService {
  final FirebaseFirestore _firestore;

  ListsService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _listsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('lists');

  Stream<List<WatchList>> watchLists(String uid) {
    return _listsRef(uid).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => WatchList.fromMap(doc.id, doc.data())).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<String> createList({required String uid, required String name}) async {
    final list = WatchList(id: '', name: name, items: const [], createdAt: DateTime.now());
    final doc = await _listsRef(uid).add(list.toMap());
    return doc.id;
  }

  Future<void> renameList({required String uid, required String listId, required String name}) {
    return _listsRef(uid).doc(listId).update({'name': name});
  }

  Future<void> deleteList({required String uid, required String listId}) {
    return _listsRef(uid).doc(listId).delete();
  }

  Future<void> addItem({
    required String uid,
    required String listId,
    required int tmdbId,
    required String type,
  }) {
    return _listsRef(uid).doc(listId).update({
      'items': FieldValue.arrayUnion([ListItemRef(tmdbId: tmdbId, type: type).toMap()]),
    });
  }

  Future<void> removeItem({
    required String uid,
    required String listId,
    required int tmdbId,
    required String type,
  }) {
    return _listsRef(uid).doc(listId).update({
      'items': FieldValue.arrayRemove([ListItemRef(tmdbId: tmdbId, type: type).toMap()]),
    });
  }
}
