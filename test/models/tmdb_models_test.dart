import 'package:flutter_test/flutter_test.dart';
import 'package:showtime/models/tmdb_models.dart';

void main() {
  group('TmdbSearchResult', () {
    test('parses a tv result', () {
      final json = {
        'id': 1399,
        'media_type': 'tv',
        'name': 'Game of Thrones',
        'poster_path': '/abc.jpg',
        'first_air_date': '2011-04-17',
      };

      final result = TmdbSearchResult.fromJson(json);

      expect(result.id, 1399);
      expect(result.mediaType, 'tv');
      expect(result.title, 'Game of Thrones');
      expect(result.posterPath, '/abc.jpg');
      expect(result.year, '2011');
    });

    test('parses a movie result', () {
      final json = {
        'id': 550,
        'media_type': 'movie',
        'title': 'Fight Club',
        'poster_path': '/def.jpg',
        'release_date': '1999-10-15',
      };

      final result = TmdbSearchResult.fromJson(json);

      expect(result.id, 550);
      expect(result.mediaType, 'movie');
      expect(result.title, 'Fight Club');
      expect(result.year, '1999');
    });

    test('handles a null poster and missing date', () {
      final json = {
        'id': 1,
        'media_type': 'tv',
        'name': 'Untitled',
        'poster_path': null,
      };

      final result = TmdbSearchResult.fromJson(json);

      expect(result.posterPath, isNull);
      expect(result.year, isNull);
    });
  });
}
