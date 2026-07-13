import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showtime/services/tmdb_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String tvJson(String name) =>
      jsonEncode({'id': 1, 'name': name, 'poster_path': null, 'seasons': <dynamic>[]});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('caches a successful response so a second call does not refetch', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response(tvJson('Test Show'), 200);
    });
    final tmdb = TmdbService(client: client);

    final first = await tmdb.getTvDetails(1);
    final second = await tmdb.getTvDetails(1);

    expect(first.name, 'Test Show');
    expect(second.name, 'Test Show');
    expect(callCount, 1);
  });

  test('falls back to a stale cached response when the live request fails', () async {
    SharedPreferences.setMockInitialValues({
      'tmdb_cache:tv:1': tvJson('Stale Show'),
      'tmdb_cache:tv:1:at': DateTime.now().subtract(const Duration(hours: 48)).millisecondsSinceEpoch,
    });
    final client = MockClient((request) async => http.Response('Service Unavailable', 503));
    final tmdb = TmdbService(client: client);

    final details = await tmdb.getTvDetails(1);

    expect(details.name, 'Stale Show');
  });

  test('throws when the request fails and there is no cached fallback', () async {
    final client = MockClient((request) async => http.Response('Service Unavailable', 503));
    final tmdb = TmdbService(client: client);

    await expectLater(tmdb.getTvDetails(1), throwsException);
  });

  test('clearCache wipes both the memory and disk cache, forcing a refetch', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      return http.Response(tvJson('Test Show'), 200);
    });
    final tmdb = TmdbService(client: client);

    await tmdb.getTvDetails(1);
    // The disk write after a successful fetch is fire-and-forget; give it a
    // turn to land before clearing so this assertion isn't racy.
    await Future<void>.delayed(Duration.zero);
    tmdb.clearCache();
    await tmdb.getTvDetails(1);

    expect(callCount, 2);
  });

  test('a failed fetch is not remembered, so the next call retries', () async {
    var callCount = 0;
    final client = MockClient((request) async {
      callCount++;
      if (callCount == 1) return http.Response('Service Unavailable', 503);
      return http.Response(tvJson('Recovered Show'), 200);
    });
    final tmdb = TmdbService(client: client);

    await expectLater(tmdb.getTvDetails(1), throwsException);
    final details = await tmdb.getTvDetails(1);

    expect(details.name, 'Recovered Show');
    expect(callCount, 2);
  });
}
