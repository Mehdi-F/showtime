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

  group('TvDetails', () {
    test('parses seasons and next episode to air', () {
      final json = {
        'id': 1399,
        'name': 'Game of Thrones',
        'poster_path': '/abc.jpg',
        'seasons': [
          {'season_number': 1, 'episode_count': 10, 'name': 'Season 1'},
          {'season_number': 2, 'episode_count': 10, 'name': 'Season 2'},
        ],
        'next_episode_to_air': {
          'season_number': 2,
          'episode_number': 3,
          'name': 'The Next One',
          'air_date': '2026-08-01',
        },
      };

      final details = TvDetails.fromJson(json);

      expect(details.id, 1399);
      expect(details.seasons.length, 2);
      expect(details.seasons[1].episodeCount, 10);
      expect(details.nextEpisodeToAir?.episodeNumber, 3);
      expect(details.nextEpisodeToAir?.airDate, DateTime.parse('2026-08-01'));
    });

    test('handles a null next_episode_to_air', () {
      final json = {
        'id': 1,
        'name': 'Ended Show',
        'poster_path': null,
        'seasons': <dynamic>[],
        'next_episode_to_air': null,
      };

      final details = TvDetails.fromJson(json);

      expect(details.nextEpisodeToAir, isNull);
    });

    test('isEnded is true for Ended and Canceled status, false otherwise', () {
      final ended = TvDetails.fromJson({
        'id': 1,
        'name': 'Ended Show',
        'poster_path': null,
        'seasons': <dynamic>[],
        'status': 'Ended',
      });
      final canceled = TvDetails.fromJson({
        'id': 2,
        'name': 'Canceled Show',
        'poster_path': null,
        'seasons': <dynamic>[],
        'status': 'Canceled',
      });
      final returning = TvDetails.fromJson({
        'id': 3,
        'name': 'Ongoing Show',
        'poster_path': null,
        'seasons': <dynamic>[],
        'status': 'Returning Series',
      });

      expect(ended.isEnded, true);
      expect(canceled.isEnded, true);
      expect(returning.isEnded, false);
    });

    test('defaults status to Returning Series when missing', () {
      final details = TvDetails.fromJson({
        'id': 1,
        'name': 'Untitled',
        'poster_path': null,
        'seasons': <dynamic>[],
      });

      expect(details.status, 'Returning Series');
      expect(details.isEnded, false);
    });
  });

  group('SeasonDetails', () {
    test('parses episodes with a key of s{season}e{episode}', () {
      final json = {
        'season_number': 1,
        'episodes': [
          {'episode_number': 1, 'name': 'Winter Is Coming', 'air_date': '2011-04-17'},
          {'episode_number': 2, 'name': 'The Kingsroad', 'air_date': null},
        ],
      };

      final details = SeasonDetails.fromJson(json);

      expect(details.episodes.length, 2);
      expect(details.episodes[0].key, 's1e1');
      expect(details.episodes[0].airDate, DateTime.parse('2011-04-17'));
      expect(details.episodes[1].airDate, isNull);
    });
  });

  group('MovieDetails', () {
    test('parses a movie', () {
      final json = {
        'id': 550,
        'title': 'Fight Club',
        'poster_path': '/def.jpg',
        'release_date': '1999-10-15',
      };

      final details = MovieDetails.fromJson(json);

      expect(details.id, 550);
      expect(details.title, 'Fight Club');
      expect(details.releaseDate, DateTime.parse('1999-10-15'));
    });
  });
}
