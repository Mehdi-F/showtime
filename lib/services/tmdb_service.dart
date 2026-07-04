import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';

class TmdbService {
  final http.Client _client;

  TmdbService({http.Client? client}) : _client = client ?? http.Client();

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
    final uri = Uri.parse('${TmdbConfig.baseUrl}/tv/$id')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB tv details failed: ${response.statusCode}');
    }
    return TvDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SeasonDetails> getSeasonDetails(int tvId, int seasonNumber) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/tv/$tvId/season/$seasonNumber')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB season details failed: ${response.statusCode}');
    }
    return SeasonDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MovieDetails> getMovieDetails(int id) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/movie/$id')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB movie details failed: ${response.statusCode}');
    }
    return MovieDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<CastMember>> getTvCredits(int id) => _getCredits('tv', id);

  Future<List<CastMember>> getMovieCredits(int id) => _getCredits('movie', id);

  Future<List<CastMember>> _getCredits(String mediaType, int id) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/$mediaType/$id/credits')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB $mediaType credits failed: ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final cast = body['cast'] as List<dynamic>? ?? [];
    return cast.take(12).map((c) => CastMember.fromJson(c as Map<String, dynamic>)).toList();
  }

  Future<List<SimilarMedia>> getSimilarTv(int id) => _getSimilar('tv', id);

  Future<List<SimilarMedia>> getSimilarMovies(int id) => _getSimilar('movie', id);

  Future<List<SimilarMedia>> _getSimilar(String mediaType, int id) async {
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
}
