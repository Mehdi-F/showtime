import 'package:flutter_test/flutter_test.dart';
import 'package:showtime/models/library_item.dart';

void main() {
  test('buildDocId prefixes with type to avoid tv/movie id collisions', () {
    expect(LibraryItem.buildDocId(tmdbId: 1399, type: 'tv'), 'tv_1399');
    expect(LibraryItem.buildDocId(tmdbId: 1399, type: 'movie'), 'movie_1399');
  });

  test('round-trips a tv item through toMap/fromMap', () {
    final addedAt = DateTime.utc(2026, 7, 1);
    final item = LibraryItem(
      docId: 'tv_1399',
      tmdbId: 1399,
      type: 'tv',
      status: 'watching',
      addedAt: addedAt,
      watchedEpisodes: {'s1e1': true, 's1e2': false},
      watched: false,
      watchedAt: null,
    );

    final restored = LibraryItem.fromMap(item.docId, item.toMap());

    expect(restored.tmdbId, 1399);
    expect(restored.type, 'tv');
    expect(restored.watchedEpisodes['s1e1'], true);
    expect(restored.watchedEpisodes['s1e2'], false);
    expect(restored.addedAt, addedAt);
  });

  test('round-trips a movie item through toMap/fromMap', () {
    final watchedAt = DateTime.utc(2026, 7, 2);
    final item = LibraryItem(
      docId: 'movie_550',
      tmdbId: 550,
      type: 'movie',
      status: 'completed',
      addedAt: DateTime.utc(2026, 6, 30),
      watchedEpisodes: const {},
      watched: true,
      watchedAt: watchedAt,
    );

    final restored = LibraryItem.fromMap(item.docId, item.toMap());

    expect(restored.watched, true);
    expect(restored.watchedAt, watchedAt);
  });
}
