import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/library_item.dart';

class LibraryService {
  final FirebaseFirestore _firestore;

  LibraryService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _libraryRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('library');

  Stream<List<LibraryItem>> watchLibrary(String uid) {
    return _libraryRef(uid).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => LibraryItem.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<LibraryItem> addToLibrary({required String uid, required int tmdbId, required String type}) async {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: type);
    final item = LibraryItem(
      docId: docId,
      tmdbId: tmdbId,
      type: type,
      status: 'watching',
      addedAt: DateTime.now(),
      watchedEpisodes: const {},
      watched: false,
      watchedAt: null,
    );
    await _libraryRef(uid).doc(docId).set(item.toMap());
    return item;
  }

  /// Creates a tv LibraryItem with a pre-populated watched-episodes map and
  /// favorite flag in a single write. Used by the TV Time import — assumes
  /// the show isn't already in the library (callers must dedupe first).
  Future<void> importTvShow({
    required String uid,
    required int tmdbId,
    required Map<String, bool> watchedEpisodes,
    required bool favorite,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    final item = LibraryItem(
      docId: docId,
      tmdbId: tmdbId,
      type: 'tv',
      status: 'watching',
      addedAt: DateTime.now(),
      watchedEpisodes: watchedEpisodes,
      watched: false,
      watchedAt: null,
      favorite: favorite,
    );
    return _libraryRef(uid).doc(docId).set(item.toMap());
  }

  Future<void> markEpisodeWatched({
    required String uid,
    required int tmdbId,
    required int season,
    required int episode,
    required bool watched,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    return _libraryRef(uid).doc(docId).update({
      'watchedEpisodes.s${season}e$episode': watched,
      'lastActivityAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markSeasonWatched({
    required String uid,
    required int tmdbId,
    required int season,
    required List<int> episodeNumbers,
    required bool watched,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    final updates = <String, dynamic>{
      for (final episode in episodeNumbers) 'watchedEpisodes.s${season}e$episode': watched,
      'lastActivityAt': DateTime.now().toIso8601String(),
    };
    return _libraryRef(uid).doc(docId).update(updates);
  }

  /// Sets an arbitrary set of episodes (possibly spanning multiple seasons)
  /// watched/unwatched in a single write. Used by the "mark all" action.
  Future<void> setEpisodesWatched({
    required String uid,
    required int tmdbId,
    required List<String> episodeKeys,
    required bool watched,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    final updates = <String, dynamic>{
      for (final key in episodeKeys) 'watchedEpisodes.$key': watched,
      'lastActivityAt': DateTime.now().toIso8601String(),
    };
    return _libraryRef(uid).doc(docId).update(updates);
  }

  /// Increments the rewatch counter for the given episodes by 1 each.
  Future<void> incrementRewatch({
    required String uid,
    required int tmdbId,
    required List<String> episodeKeys,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    final updates = <String, dynamic>{
      for (final key in episodeKeys) 'episodeRewatchCounts.$key': FieldValue.increment(1),
      'lastActivityAt': DateTime.now().toIso8601String(),
    };
    return _libraryRef(uid).doc(docId).update(updates);
  }

  Future<void> markMovieWatched({required String uid, required int tmdbId, required bool watched}) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'movie');
    return _libraryRef(uid).doc(docId).update({
      'watched': watched,
      'watchedAt': watched ? DateTime.now().toIso8601String() : null,
    });
  }

  Future<void> removeFromLibrary({required String uid, required int tmdbId, required String type}) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: type);
    return _libraryRef(uid).doc(docId).delete();
  }

  Future<void> setSkipGapPrompt({required String uid, required int tmdbId, required bool skip}) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    return _libraryRef(uid).doc(docId).update({'skipGapPrompt': skip});
  }

  Future<void> toggleFavorite({
    required String uid,
    required int tmdbId,
    required String type,
    required bool favorite,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: type);
    return _libraryRef(uid).doc(docId).update({'favorite': favorite});
  }
}
