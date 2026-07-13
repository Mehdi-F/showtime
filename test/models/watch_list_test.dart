import 'package:flutter_test/flutter_test.dart';
import 'package:showtime/models/watch_list.dart';

void main() {
  group('ListItemRef', () {
    test('key combines type and tmdbId', () {
      final ref = ListItemRef(tmdbId: 550, type: 'movie');
      expect(ref.key, 'movie_550');
    });

    test('round-trips through toMap/fromMap', () {
      final ref = ListItemRef(tmdbId: 1399, type: 'tv');
      final restored = ListItemRef.fromMap(ref.toMap());

      expect(restored.tmdbId, 1399);
      expect(restored.type, 'tv');
    });
  });

  group('WatchList', () {
    test('containsItem matches on both tmdbId and type', () {
      final list = WatchList(
        id: 'l1',
        name: 'Favoris',
        items: [ListItemRef(tmdbId: 550, type: 'movie')],
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(list.containsItem(550, 'movie'), true);
      expect(list.containsItem(550, 'tv'), false);
      expect(list.containsItem(1, 'movie'), false);
    });

    test('round-trips through toMap/fromMap', () {
      final createdAt = DateTime.utc(2026, 1, 1);
      final list = WatchList(
        id: 'l1',
        name: 'Favoris',
        items: [ListItemRef(tmdbId: 550, type: 'movie'), ListItemRef(tmdbId: 1399, type: 'tv')],
        createdAt: createdAt,
      );

      final restored = WatchList.fromMap(list.id, list.toMap());

      expect(restored.name, 'Favoris');
      expect(restored.items.length, 2);
      expect(restored.containsItem(1399, 'tv'), true);
      expect(restored.createdAt, createdAt);
    });

    test('fromMap defaults to an empty item list when items is missing', () {
      final restored = WatchList.fromMap('l2', {
        'name': 'Vide',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });

      expect(restored.items, isEmpty);
    });
  });
}
