import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';

class TmdbService {
  final http.Client _client;
  SharedPreferences? _prefs;

  TmdbService({http.Client? client}) : _client = client ?? http.Client() {
    // Fire-and-forget: by the time any request actually needs the disk
    // cache, this has almost certainly already resolved.
    unawaited(SharedPreferences.getInstance().then((p) => _prefs = p));
  }

  static const _prefsKeyPrefix = 'tmdb_cache:';
  static const _prefsTtl = Duration(hours: 6);

  // Per-id lookups (show/movie details, credits, similar, watch providers)
  // are effectively static — every screen that shows a given title re-fetches
  // it independently, so caching here means navigating between screens for
  // the same title is instant instead of re-hitting TMDB every time. This is
  // cached at two levels: in memory for the current session (instant, always
  // fresh within the session) and on disk via SharedPreferences for a few
  // hours (so a cold reload doesn't re-fetch everything from scratch). Search
  // and the discover/trending/popular feeds are deliberately NOT cached here:
  // they already have explicit pull-to-refresh affordances that should always
  // hit the network fresh.
  final Map<String, Future<String>> _memoryCache = {};

  /// Drops all cached per-id lookups, in memory and on disk. Called by
  /// screens' pull-to-refresh handlers so a manual refresh actually re-hits
  /// TMDB instead of replaying cached data — otherwise "refresh" could never
  /// surface a new episode, season, or status change for a title already
  /// viewed this session.
  void clearCache() {
    _memoryCache.clear();
    final prefs = _prefs;
    if (prefs == null) return;
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefsKeyPrefix)) unawaited(prefs.remove(key));
    }
  }

  Future<String> _cachedBody(String key, Uri uri, String errorLabel) {
    final existing = _memoryCache[key];
    if (existing != null) return existing;
    // A failed fetch shouldn't be remembered — drop it so the next call
    // actually retries instead of replaying the same rejection forever.
    final future = _fetchBody(key, uri, errorLabel).catchError((Object e, StackTrace st) {
      _memoryCache.remove(key);
      throw e;
    });
    _memoryCache[key] = future;
    return future;
  }

  Future<String> _fetchBody(String key, Uri uri, String errorLabel) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final prefsKey = '$_prefsKeyPrefix$key';
    final cachedAt = prefs.getInt('$prefsKey:at');
    if (cachedAt != null) {
      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));
      final cachedBody = prefs.getString(prefsKey);
      if (cachedBody != null && age < _prefsTtl) return cachedBody;
    }

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('$errorLabel failed: ${response.statusCode}');
    }
    unawaited(prefs.setString(prefsKey, response.body));
    unawaited(prefs.setInt('$prefsKey:at', DateTime.now().millisecondsSinceEpoch));
    return response.body;
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

  Future<TvDetails> getTvDetails(int id) async {
    final uri =
        Uri.parse('${TmdbConfig.baseUrl}/tv/$id').replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final body = await _cachedBody('tv:$id', uri, 'TMDB tv details');
    return TvDetails.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Future<SeasonDetails> getSeasonDetails(int tvId, int seasonNumber) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/tv/$tvId/season/$seasonNumber')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final body = await _cachedBody('season:$tvId:$seasonNumber', uri, 'TMDB season details');
    return SeasonDetails.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Future<MovieDetails> getMovieDetails(int id) async {
    final uri =
        Uri.parse('${TmdbConfig.baseUrl}/movie/$id').replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final body = await _cachedBody('movie:$id', uri, 'TMDB movie details');
    return MovieDetails.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  Future<List<CastMember>> getTvCredits(int id) => _getCredits('tv', id);

  Future<List<CastMember>> getMovieCredits(int id) => _getCredits('movie', id);

  Future<List<CastMember>> _getCredits(String mediaType, int id) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/credits')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final body = await _cachedBody('credits:$mediaType:$id', uri, 'TMDB $mediaType credits');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final cast = decoded['cast'] as List<dynamic>? ?? [];
    return cast.take(12).map((c) => CastMember.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<List<SimilarMedia>> getSimilarTv(int id) => _getSimilar('tv', id);

  Future<List<SimilarMedia>> getSimilarMovies(int id) => _getSimilar('movie', id);

  Future<List<SimilarMedia>> _getSimilar(String mediaType, int id) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/recommendations')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final body = await _cachedBody('similar:$mediaType:$id', uri, 'TMDB $mediaType recommendations');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>? ?? [];
    return results.map((r) => SimilarMedia.fromJson(r as Map<String, dynamic>, mediaType)).toList();
  }

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

  Future<List<WatchProvider>> _getWatchProviders(String mediaType, int id) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/watch/providers')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final body = await _cachedBody('watch:$mediaType:$id', uri, 'TMDB $mediaType watch providers');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final results = decoded['results'] as Map<String, dynamic>? ?? {};
    final country = (results['FR'] ?? results['US']) as Map<String, dynamic>?;
    if (country == null) return <WatchProvider>[];
    final flatrate = country['flatrate'] as List<dynamic>? ?? [];
    return flatrate.map((p) => WatchProvider.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<TitleImages> getTvImages(int id) => _getImages('tv', id);

  Future<TitleImages> getMovieImages(int id) => _getImages('movie', id);

  Future<TitleImages> _getImages(String mediaType, int id) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/images')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey, 'include_image_language': 'en,null'});
    final body = await _cachedBody('images:$mediaType:$id', uri, 'TMDB $mediaType images');
    return TitleImages.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }
}
