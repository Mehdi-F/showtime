import '../models/tmdb_models.dart';

EpisodeRef? nextUnwatchedEpisode({
  required List<EpisodeRef> episodesInOrder,
  required Map<String, bool> watchedEpisodes,
  required DateTime now,
}) {
  for (final ep in episodesInOrder) {
    if (watchedEpisodes[ep.key] == true) continue;
    if (ep.airDate != null && ep.airDate!.isAfter(now)) continue;
    return ep;
  }
  return null;
}
