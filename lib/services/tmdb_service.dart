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
}
