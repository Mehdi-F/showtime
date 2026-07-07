import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';

class TmdbService {
  final http.Client _client;

  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  // Per-id lookups (show/movie details, credits, similar, watch providers)
  // are effectively static — every screen that shows a given title re-fetches
  // it independently, so caching here means navigating between screens for
  // the same title is instant instead of re-hitting TMDB every time. Search
  // and the discover/trending/popular feeds are deliberately NOT cached here:
  // they already have explicit pull-to-refresh affordances that should always
  // hit the network fresh.
  final Map<String, Future<dynamic>> _cache = {};

  /// Drops all cached per-id lookups. Called by screens' pull-to-refresh
  /// handlers so a manual refresh actually re-hits TMDB instead of replaying
  /// cached data — otherwise "refresh" could never surface a new episode,
  /// season, or status change for a title already viewed this session.
  void clearCache() => _cache.clear();

  Future<T> _cached<T>(String key, Future<T> Function() fetch) {
    final existing = _cache[key];
    if (existing != null) return existing as Future<T>;
    // A failed fetch shouldn't be remembered — drop it so the next call
    // actually retries instead of replaying the same rejection forever.
    final future = fetch().catchError((Object e, StackTrace st) {
      _cache.remove(key);
      throw e;
    });
    _cache[key] = future;
    return future;
  }

  Future<List<TmdbSearchResult>> search(String query) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/search/multi').replace(
      queryParameters: {'api_key': TmdbConfig.apiKey, 'query': query},
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB search failed: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>;

    return results
        .where((r) => r['media_type'] == 'tv' || r['media_type'] == 'movie')
        .map((r) => TmdbSearchResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<TvDetails> getTvDetails(int id) => _cached('tv:$id', () async {
        final uri = Uri.parse('${TmdbConfig.baseUrl}/tv/$id')
            .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
        final response = await _client.get(uri);
        if (response.statusCode != 200) {
          throw Exception('TMDB tv details failed: ${response.statusCode}');
        }
        return TvDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      });

  Future<SeasonDetails> getSeasonDetails(int tvId, int seasonNumber) =>
      _cached('season:$tvId:$seasonNumber', () async {
        final uri = Uri.parse('${TmdbConfig.baseUrl}/tv/$tvId/season/$seasonNumber')
            .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
        final response = await _client.get(uri);
        if (response.statusCode != 200) {
          throw Exception('TMDB season details failed: ${response.statusCode}');
        }
        return SeasonDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      });

  Future<MovieDetails> getMovieDetails(int id) => _cached('movie:$id', () async {
        final uri = Uri.parse('${TmdbConfig.baseUrl}/movie/$id')
            .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
        final response = await _client.get(uri);
        if (response.statusCode != 200) {
          throw Exception('TMDB movie details failed: ${response.statusCode}');
        }
        return MovieDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      });

  Future<List<CastMember>> getTvCredits(int id) => _getCredits('tv', id);

  Future<List<CastMember>> getMovieCredits(int id) => _getCredits('movie', id);

  Future<List<CastMember>> _getCredits(String mediaType, int id) =>
      _cached('credits:$mediaType:$id', () async {
        final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/credits')
            .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
        final response = await _client.get(uri);
        if (response.statusCode != 200) {
          throw Exception('TMDB $mediaType credits failed: ${response.statusCode}');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final cast = body['cast'] as List<dynamic>? ?? [];
        return cast.take(12).map((c) => CastMember.fromJson(c as Map<String, dynamic>)).toList();
      });

  Future<List<SimilarMedia>> getSimilarTv(int id) => _getSimilar('tv', id);

  Future<List<SimilarMedia>> getSimilarMovies(int id) => _getSimilar('movie', id);

  Future<List<SimilarMedia>> _getSimilar(String mediaType, int id) =>
      _cached('similar:$mediaType:$id', () async {
        final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/recommendations')
            .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
        final response = await _client.get(uri);
        if (response.statusCode != 200) {
          throw Exception('TMDB $mediaType recommendations failed: ${response.statusCode}');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'] as List<dynamic>? ?? [];
        return results
            .map((r) => SimilarMedia.fromJson(r as Map<String, dynamic>, mediaType))
            .toList();
      });

  Future<List<SimilarMedia>> discoverMedia({
    required String mediaType,
    required int page,
    required String sortBy,
  }) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/discover/$mediaType').replace(queryParameters: {
      'api_key': TmdbConfig.apiKey,
      'sort_by': sortBy,
      'page': '$page',
      'include_adult': 'false',
      'include_video': 'false',
      'vote_count.gte': '10',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB discover $mediaType failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    return results.map((r) => SimilarMedia.fromJson(r as Map<String, dynamic>, mediaType)).toList();
  }

  Future<List<SimilarMedia>> getTrending(String mediaType) => _getListEndpoint('trending/$mediaType/week', mediaType);

  Future<List<SimilarMedia>> getPopular(String mediaType, {int page = 1}) =>
      _getListEndpoint('$mediaType/popular', mediaType, page: page);

  Future<List<SimilarMedia>> getTopRatedTv({int page = 1}) => _getListEndpoint('tv/top_rated', 'tv', page: page);

  Future<List<SimilarMedia>> _getListEndpoint(String path, String mediaType, {int page = 1}) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/$path').replace(queryParameters: {
      'api_key': TmdbConfig.apiKey,
      'page': '$page',
    });
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB $path failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? [];
    return results.map((r) => SimilarMedia.fromJson(r as Map<String, dynamic>, mediaType)).toList();
  }

  Future<List<WatchProvider>> getTvWatchProviders(int id) => _getWatchProviders('tv', id);

  Future<List<WatchProvider>> getMovieWatchProviders(int id) => _getWatchProviders('movie', id);

  Future<List<WatchProvider>> _getWatchProviders(String mediaType, int id) =>
      _cached('watch:$mediaType:$id', () async {
        final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/watch/providers')
            .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
        final response = await _client.get(uri);
        if (response.statusCode != 200) {
          throw Exception('TMDB $mediaType watch providers failed: ${response.statusCode}');
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final results = body['results'] as Map<String, dynamic>? ?? {};
        final country = (results['FR'] ?? results['US']) as Map<String, dynamic>?;
        if (country == null) return <WatchProvider>[];
        final flatrate = country['flatrate'] as List<dynamic>? ?? [];
        return flatrate.map((p) => WatchProvider.fromJson(p as Map<String, dynamic>)).toList();
      });
}
