import 'package:flutter_test/flutter_test.dart';
import 'package:showtime/logic/up_next.dart';
import 'package:showtime/models/tmdb_models.dart';

void main() {
  final now = DateTime.utc(2026, 7, 2);

  EpisodeRef ep(int season, int episode, {DateTime? airDate}) => EpisodeRef(
        seasonNumber: season,
        episodeNumber: episode,
        name: 'S${season}E$episode',
        airDate: airDate ?? DateTime.utc(2020, 1, 1),
        overview: '',
        stillPath: null,
      );

  test('returns the first unwatched aired episode in order', () {
    final episodes = [ep(1, 1), ep(1, 2), ep(1, 3)];
    final watched = {'s1e1': true};

    final result = nextUnwatchedEpisode(
      episodesInOrder: episodes,
      watchedEpisodes: watched,
      now: now,
    );

    expect(result?.key, 's1e2');
  });

  test('returns null when everything aired is watched', () {
    final episodes = [ep(1, 1), ep(1, 2)];
    final watched = {'s1e1': true, 's1e2': true};

    final result = nextUnwatchedEpisode(
      episodesInOrder: episodes,
      watchedEpisodes: watched,
      now: now,
    );

    expect(result, isNull);
  });

  test('skips unaired episodes even if unwatched', () {
    final episodes = [
      ep(1, 1),
      ep(1, 2, airDate: DateTime.utc(2026, 12, 1)), // in the future
    ];
    final watched = {'s1e1': true};

    final result = nextUnwatchedEpisode(
      episodesInOrder: episodes,
      watchedEpisodes: watched,
      now: now,
    );

    expect(result, isNull);
  });

  test('treats an episode with no air date as already aired', () {
    final episodes = [ep(1, 1, airDate: null)];

    final result = nextUnwatchedEpisode(
      episodesInOrder: episodes,
      watchedEpisodes: const {},
      now: now,
    );

    expect(result?.key, 's1e1');
  });
}
