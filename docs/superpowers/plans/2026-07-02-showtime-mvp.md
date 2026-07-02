# Showtime MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Showtime MVP — a Flutter Web app, hosted on GitHub Pages, to search TMDB for shows/movies, track them in a Firebase-backed library, mark episodes/movies watched, and see what's next to watch and when new episodes air.

**Architecture:** Flutter Web app calling TMDB's public REST API directly (API key via `--dart-define`, no backend proxy — GitHub Pages is static hosting only, so there is nowhere to run one). Firestore stores only tracking state under `users/{uid}/library/{docId}`; TMDB is queried live for all metadata/posters — never cached into Firestore. Firebase Auth with Google Sign-In (`signInWithPopup`) is the sole auth method; a Firestore rule allowlist restricts writes to two known email addresses since the site is publicly reachable. A GitHub Actions workflow builds and deploys to the `gh-pages` branch on every push to `main`.

**Tech Stack:** Flutter Web (Dart), Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`), `provider` for state management, `http` for TMDB calls, `cached_network_image`, `google_fonts`, `intl`, GitHub Actions (`peaceiris/actions-gh-pages`).

## Global Constraints

- Web only, no native mobile builds. Repo: `Mehdi-F/showtime` on GitHub. Deployed URL: `https://mehdi-f.github.io/showtime/`.
- Every `flutter build web` invocation must pass `--base-href /showtime/` — a GitHub Pages project site is served from that subpath, and the app will fail to load its assets without it.
- TMDB attribution string must appear somewhere in the UI: "This product uses the TMDB API but is not endorsed or certified by TMDB." (TMDB ToS requirement.)
- TMDB data is never written to Firestore — Firestore holds only `type`, `status`, `addedAt`, `watchedEpisodes`/`watched`/`watchedAt`. Screens fetch TMDB metadata live by id every time they render.
- Firestore doc id for a library entry is `"${type}_$tmdbId"` (e.g. `tv_1399`, `movie_550`) — TMDB ids are only unique within a media type, so the type prefix avoids a tv/movie id collision.
- Firestore access is restricted to an email allowlist: `you@example.com`, `teammate@example.com`. Anyone can sign in via Google, but only these two get Firestore read/write — everyone else's Firestore calls are denied.
- **Testing policy (per approved spec):** automated unit tests are written only for pure Dart logic with no I/O (JSON parsing/model mapping, the next-episode algorithm). Everything that touches Firebase, the network, or renders UI is verified manually in-browser — no widget/integration test suite for this MVP.
- No notifications, no ratings/stats/social features, no TV Time import, no custom domain, no offline/PWA support — all explicitly out of scope per spec.

---

## File Structure

```
lib/
  config/
    tmdb_config.dart         # API key + base URLs
  models/
    tmdb_models.dart         # TmdbSearchResult, TvDetails, SeasonSummary, NextEpisode, SeasonDetails, EpisodeRef, MovieDetails
    library_item.dart        # LibraryItem (Firestore doc mapping)
  logic/
    up_next.dart             # nextUnwatchedEpisode() pure function
  services/
    tmdb_service.dart        # TMDB HTTP calls
    auth_service.dart        # Firebase Auth Google sign-in wrapper (signInWithPopup)
    library_service.dart     # Firestore CRUD for the library
  providers/
    auth_provider.dart
    library_provider.dart
  screens/
    login_screen.dart
    home_shell.dart          # bottom nav: Up Next / Calendar / Search / Library
    up_next_screen.dart
    calendar_screen.dart
    search_screen.dart
    library_screen.dart
    show_detail_screen.dart
    movie_detail_screen.dart
  widgets/
    poster_tile.dart
  main.dart
test/
  models/
    tmdb_models_test.dart
    library_item_test.dart
  logic/
    up_next_test.dart
.github/
  workflows/
    deploy.yml                # build + deploy to gh-pages on push to main
firestore.rules
firebase.json
.firebaserc
```

---

### Task 1: Project scaffold and dependencies

**Files:**
- Create: `pubspec.yaml` (via `flutter create`, then edited)
- Create: Flutter default web project skeleton (`lib/main.dart`, `web/`, etc.)

**Interfaces:**
- Produces: a runnable Flutter web project with all MVP dependencies resolved.

- [ ] **Step 1: Scaffold the Flutter project (web platform only)**

Run inside `C:\Users\Mehdi\StudioProjects\showtime` (the folder already contains `docs/` and a git repo — `flutter create` on a non-empty directory is safe, it only adds Flutter files):

```bash
flutter create --platforms web --org com.moudass --project-name showtime .
```

- [ ] **Step 2: Add dependencies**

Edit `pubspec.yaml`, add under `dependencies:`:

```yaml
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.3
  provider: ^6.1.2
  http: ^1.2.2
  cached_network_image: ^3.4.1
  google_fonts: ^6.2.1
  intl: ^0.19.0
```

- [ ] **Step 3: Install and verify**

```bash
flutter pub get
flutter analyze
```

Expected: `flutter analyze` reports "No issues found!".

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter web project with MVP dependencies"
```

---

### Task 2: Firebase project setup

**Files:**
- Create: `lib/firebase_options.dart` (generated by FlutterFire CLI)

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform` used by `Firebase.initializeApp()` in Task 10.

- [ ] **Step 1: Create the Firebase project**

```bash
firebase login
firebase projects:create showtime-mehdi --display-name "Showtime"
```

- [ ] **Step 2: Run FlutterFire configure**

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=showtime-mehdi
```

When prompted for platforms, select **Web only**. This generates `lib/firebase_options.dart` and registers a web app in Firebase.

- [ ] **Step 3: Enable Google Sign-In in Firebase Console**

In the Firebase Console → Authentication → Sign-in method → enable **Google** as a provider.

- [ ] **Step 4: Add the GitHub Pages domain to authorized domains**

In Firebase Console → Authentication → Settings → Authorized domains → add `mehdi-f.github.io`. Without this, `signInWithPopup` will reject sign-in attempts from the deployed site (it works fine on `localhost` during local development without this step, since `localhost` is authorized by default).

- [ ] **Step 5: Verify the app builds with Firebase wired in**

```bash
flutter build web --base-href /showtime/
```

Expected: build succeeds with no Firebase-related errors.

- [ ] **Step 6: Commit**

```bash
git add lib/firebase_options.dart
git commit -m "chore: configure Firebase project for web"
```

---

### Task 3: TMDB config and search endpoint

**Files:**
- Create: `lib/config/tmdb_config.dart`
- Create: `lib/models/tmdb_models.dart`
- Create: `lib/services/tmdb_service.dart`
- Test: `test/models/tmdb_models_test.dart`

**Interfaces:**
- Produces: `TmdbConfig.apiKey`, `TmdbConfig.imageBaseUrl`; `TmdbSearchResult` model; `TmdbSearchResult.fromJson(Map<String, dynamic>)`; `TmdbService.search(String query)`.

- [ ] **Step 1: Write the failing test for search result parsing**

Create `test/models/tmdb_models_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/models/tmdb_models_test.dart
```

Expected: FAIL — `showtime/models/tmdb_models.dart` does not exist yet.

- [ ] **Step 3: Write `lib/config/tmdb_config.dart`**

```dart
class TmdbConfig {
  static const apiKey = String.fromEnvironment('TMDB_API_KEY');
  static const baseUrl = 'https://api.themoviedb.org/3';
  static const imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  static const attribution =
      'This product uses the TMDB API but is not endorsed or certified by TMDB.';
}
```

- [ ] **Step 4: Write `lib/models/tmdb_models.dart` (search result only for now)**

```dart
class TmdbSearchResult {
  final int id;
  final String mediaType; // "tv" | "movie"
  final String title;
  final String? posterPath;
  final String? year;

  TmdbSearchResult({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.year,
  });

  factory TmdbSearchResult.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String;
    final title = mediaType == 'tv' ? json['name'] as String : json['title'] as String;
    final dateField = mediaType == 'tv' ? json['first_air_date'] : json['release_date'];
    final date = dateField as String?;

    return TmdbSearchResult(
      id: json['id'] as int,
      mediaType: mediaType,
      title: title,
      posterPath: json['poster_path'] as String?,
      year: (date != null && date.length >= 4) ? date.substring(0, 4) : null,
    );
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

```bash
flutter test test/models/tmdb_models_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 6: Write `TmdbService.search`**

```dart
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
}
```

- [ ] **Step 7: Commit**

```bash
git add lib/config lib/models lib/services test/models
git commit -m "feat: add TMDB search endpoint and search result model"
```

---

### Task 4: TMDB TV details and season details

**Files:**
- Modify: `lib/models/tmdb_models.dart` (add `SeasonSummary`, `NextEpisode`, `TvDetails`, `EpisodeRef`, `SeasonDetails`)
- Modify: `lib/services/tmdb_service.dart` (add `getTvDetails`, `getSeasonDetails`)
- Test: `test/models/tmdb_models_test.dart` (add cases)

**Interfaces:**
- Consumes: `TmdbConfig` from Task 3.
- Produces: `TvDetails.fromJson`, `SeasonDetails.fromJson`, `EpisodeRef` (with `.key` getter used by Task 5/7), `TmdbService.getTvDetails(int id)`, `TmdbService.getSeasonDetails(int tvId, int seasonNumber)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/models/tmdb_models_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/models/tmdb_models_test.dart
```

Expected: FAIL — `TvDetails`/`SeasonDetails` undefined.

- [ ] **Step 3: Add the models to `lib/models/tmdb_models.dart`**

```dart
class SeasonSummary {
  final int seasonNumber;
  final int episodeCount;
  final String name;

  SeasonSummary({required this.seasonNumber, required this.episodeCount, required this.name});

  factory SeasonSummary.fromJson(Map<String, dynamic> json) => SeasonSummary(
        seasonNumber: json['season_number'] as int,
        episodeCount: json['episode_count'] as int,
        name: json['name'] as String,
      );
}

class NextEpisode {
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final DateTime? airDate;

  NextEpisode({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    required this.airDate,
  });

  factory NextEpisode.fromJson(Map<String, dynamic> json) => NextEpisode(
        seasonNumber: json['season_number'] as int,
        episodeNumber: json['episode_number'] as int,
        name: json['name'] as String,
        airDate: json['air_date'] != null ? DateTime.parse(json['air_date'] as String) : null,
      );
}

class TvDetails {
  final int id;
  final String name;
  final String? posterPath;
  final List<SeasonSummary> seasons;
  final NextEpisode? nextEpisodeToAir;

  TvDetails({
    required this.id,
    required this.name,
    required this.posterPath,
    required this.seasons,
    required this.nextEpisodeToAir,
  });

  factory TvDetails.fromJson(Map<String, dynamic> json) => TvDetails(
        id: json['id'] as int,
        name: json['name'] as String,
        posterPath: json['poster_path'] as String?,
        seasons: (json['seasons'] as List<dynamic>? ?? [])
            // TMDB includes a "Specials" entry as season_number 0 — skip it, MVP only tracks numbered seasons.
            .map((s) => SeasonSummary.fromJson(s as Map<String, dynamic>))
            .where((s) => s.seasonNumber > 0)
            .toList(),
        nextEpisodeToAir: json['next_episode_to_air'] != null
            ? NextEpisode.fromJson(json['next_episode_to_air'] as Map<String, dynamic>)
            : null,
      );
}

class EpisodeRef {
  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final DateTime? airDate;

  EpisodeRef({
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    required this.airDate,
  });

  String get key => 's${seasonNumber}e$episodeNumber';

  factory EpisodeRef.fromJson(int seasonNumber, Map<String, dynamic> json) => EpisodeRef(
        seasonNumber: seasonNumber,
        episodeNumber: json['episode_number'] as int,
        name: json['name'] as String,
        airDate: json['air_date'] != null ? DateTime.parse(json['air_date'] as String) : null,
      );
}

class SeasonDetails {
  final int seasonNumber;
  final List<EpisodeRef> episodes;

  SeasonDetails({required this.seasonNumber, required this.episodes});

  factory SeasonDetails.fromJson(Map<String, dynamic> json) {
    final seasonNumber = json['season_number'] as int;
    final episodes = (json['episodes'] as List<dynamic>)
        .map((e) => EpisodeRef.fromJson(seasonNumber, e as Map<String, dynamic>))
        .toList();
    return SeasonDetails(seasonNumber: seasonNumber, episodes: episodes);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/models/tmdb_models_test.dart
```

Expected: PASS (7 tests).

- [ ] **Step 5: Add the service methods**

Add to `lib/services/tmdb_service.dart`:

```dart
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
```

- [ ] **Step 6: Commit**

```bash
git add lib/models/tmdb_models.dart lib/services/tmdb_service.dart test/models/tmdb_models_test.dart
git commit -m "feat: add TMDB tv/season details endpoints"
```

---

### Task 5: TMDB movie details

**Files:**
- Modify: `lib/models/tmdb_models.dart` (add `MovieDetails`)
- Modify: `lib/services/tmdb_service.dart` (add `getMovieDetails`)
- Test: `test/models/tmdb_models_test.dart` (add case)

**Interfaces:**
- Produces: `MovieDetails.fromJson`, `TmdbService.getMovieDetails(int id)`.

- [ ] **Step 1: Write the failing test**

Append to `test/models/tmdb_models_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/models/tmdb_models_test.dart
```

Expected: FAIL — `MovieDetails` undefined.

- [ ] **Step 3: Add `MovieDetails` to `lib/models/tmdb_models.dart`**

```dart
class MovieDetails {
  final int id;
  final String title;
  final String? posterPath;
  final DateTime? releaseDate;

  MovieDetails({
    required this.id,
    required this.title,
    required this.posterPath,
    required this.releaseDate,
  });

  factory MovieDetails.fromJson(Map<String, dynamic> json) => MovieDetails(
        id: json['id'] as int,
        title: json['title'] as String,
        posterPath: json['poster_path'] as String?,
        releaseDate:
            json['release_date'] != null && (json['release_date'] as String).isNotEmpty
                ? DateTime.parse(json['release_date'] as String)
                : null,
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/models/tmdb_models_test.dart
```

Expected: PASS (8 tests).

- [ ] **Step 5: Add the service method**

Add to `lib/services/tmdb_service.dart`:

```dart
  Future<MovieDetails> getMovieDetails(int id) async {
    final uri = Uri.parse('${TmdbConfig.baseUrl}/movie/$id')
        .replace(queryParameters: {'api_key': TmdbConfig.apiKey});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('TMDB movie details failed: ${response.statusCode}');
    }
    return MovieDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
```

- [ ] **Step 6: Commit**

```bash
git add lib/models/tmdb_models.dart lib/services/tmdb_service.dart test/models/tmdb_models_test.dart
git commit -m "feat: add TMDB movie details endpoint"
```

---

### Task 6: LibraryItem model (Firestore mapping)

**Files:**
- Create: `lib/models/library_item.dart`
- Test: `test/models/library_item_test.dart`

**Interfaces:**
- Produces: `LibraryItem` with fields `docId`, `tmdbId`, `type`, `status`, `addedAt`, `watchedEpisodes`, `watched`, `watchedAt`; `LibraryItem.fromMap(String docId, Map<String, dynamic> map)`; `LibraryItem.toMap()`; `LibraryItem.buildDocId({required int tmdbId, required String type})`.

- [ ] **Step 1: Write the failing test**

Create `test/models/library_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:showtime/models/library_item.dart';

void main() {
  test('buildDocId prefixes with type to avoid tv/movie id collisions', () {
    expect(LibraryItem.buildDocId(tmdbId: 1399, type: 'tv'), 'tv_1399');
    expect(LibraryItem.buildDocId(tmdbId: 1399, type: 'movie'), 'movie_1399');
  });

  test('round-trips a tv item through toMap/fromMap', () {
    final addedAt = DateTime.utc(2026, 7, 1);
    final item = LibraryItem(
      docId: 'tv_1399',
      tmdbId: 1399,
      type: 'tv',
      status: 'watching',
      addedAt: addedAt,
      watchedEpisodes: {'s1e1': true, 's1e2': false},
      watched: false,
      watchedAt: null,
    );

    final restored = LibraryItem.fromMap(item.docId, item.toMap());

    expect(restored.tmdbId, 1399);
    expect(restored.type, 'tv');
    expect(restored.watchedEpisodes['s1e1'], true);
    expect(restored.watchedEpisodes['s1e2'], false);
    expect(restored.addedAt, addedAt);
  });

  test('round-trips a movie item through toMap/fromMap', () {
    final watchedAt = DateTime.utc(2026, 7, 2);
    final item = LibraryItem(
      docId: 'movie_550',
      tmdbId: 550,
      type: 'movie',
      status: 'completed',
      addedAt: DateTime.utc(2026, 6, 30),
      watchedEpisodes: const {},
      watched: true,
      watchedAt: watchedAt,
    );

    final restored = LibraryItem.fromMap(item.docId, item.toMap());

    expect(restored.watched, true);
    expect(restored.watchedAt, watchedAt);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/models/library_item_test.dart
```

Expected: FAIL — `showtime/models/library_item.dart` does not exist.

- [ ] **Step 3: Write `lib/models/library_item.dart`**

```dart
class LibraryItem {
  final String docId;
  final int tmdbId;
  final String type; // "tv" | "movie"
  final String status; // "watching" | "completed" | "plan_to_watch"
  final DateTime addedAt;
  final Map<String, bool> watchedEpisodes; // tv only, key = "s{season}e{episode}"
  final bool watched; // movie only
  final DateTime? watchedAt; // movie only

  LibraryItem({
    required this.docId,
    required this.tmdbId,
    required this.type,
    required this.status,
    required this.addedAt,
    required this.watchedEpisodes,
    required this.watched,
    required this.watchedAt,
  });

  static String buildDocId({required int tmdbId, required String type}) => '${type}_$tmdbId';

  factory LibraryItem.fromMap(String docId, Map<String, dynamic> map) => LibraryItem(
        docId: docId,
        tmdbId: map['tmdbId'] as int,
        type: map['type'] as String,
        status: map['status'] as String,
        addedAt: DateTime.parse(map['addedAt'] as String),
        watchedEpisodes: Map<String, bool>.from(map['watchedEpisodes'] as Map? ?? {}),
        watched: map['watched'] as bool? ?? false,
        watchedAt: map['watchedAt'] != null ? DateTime.parse(map['watchedAt'] as String) : null,
      );

  Map<String, dynamic> toMap() => {
        'tmdbId': tmdbId,
        'type': type,
        'status': status,
        'addedAt': addedAt.toIso8601String(),
        'watchedEpisodes': watchedEpisodes,
        'watched': watched,
        'watchedAt': watchedAt?.toIso8601String(),
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/models/library_item_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/library_item.dart test/models/library_item_test.dart
git commit -m "feat: add LibraryItem model with Firestore mapping"
```

---

### Task 7: Up Next pure logic

**Files:**
- Create: `lib/logic/up_next.dart`
- Test: `test/logic/up_next_test.dart`

**Interfaces:**
- Consumes: `EpisodeRef` from Task 4 (`.key` getter, `.airDate`).
- Produces: `nextUnwatchedEpisode({required List<EpisodeRef> episodesInOrder, required Map<String, bool> watchedEpisodes, required DateTime now})`. Used by `UpNextScreen` in Task 17.

- [ ] **Step 1: Write the failing tests**

Create `test/logic/up_next_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/logic/up_next_test.dart
```

Expected: FAIL — `showtime/logic/up_next.dart` does not exist.

- [ ] **Step 3: Write `lib/logic/up_next.dart`**

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/logic/up_next_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/logic/up_next.dart test/logic/up_next_test.dart
git commit -m "feat: add pure next-unwatched-episode logic"
```

---

### Task 8: AuthService (Google Sign-In via Firebase Auth popup)

**Files:**
- Create: `lib/services/auth_service.dart`

**Interfaces:**
- Produces: `AuthService.authStateChanges` (`Stream<User?>`), `AuthService.signInWithGoogle()` (`Future<UserCredential?>`), `AuthService.signOut()` (`Future<void>`), `AuthService.currentUser` (`User?`).
- Manual verification only (Firebase Auth requires a real browser and the authorized-domain config from Task 2 — no automated test per Global Constraints).

- [ ] **Step 1: Write `lib/services/auth_service.dart`**

Flutter web's standard Google Sign-In path is `FirebaseAuth.signInWithPopup(GoogleAuthProvider())` — no separate `google_sign_in` package is needed on web.

```dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth}) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential?> signInWithGoogle() {
    return _firebaseAuth.signInWithPopup(GoogleAuthProvider());
  }

  Future<void> signOut() => _firebaseAuth.signOut();
}
```

- [ ] **Step 2: Manual verification (deferred to Task 11)**

`AuthService` has no UI yet — it's exercised end-to-end once `LoginScreen` exists in Task 11. No standalone verification step here.

- [ ] **Step 3: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat: add AuthService using Firebase Auth Google popup sign-in"
```

---

### Task 9: LibraryService (Firestore CRUD) and security rules

**Files:**
- Create: `lib/services/library_service.dart`
- Create: `firestore.rules`
- Create: `firebase.json`
- Create: `.firebaserc`

**Interfaces:**
- Consumes: `LibraryItem` from Task 6.
- Produces: `LibraryService.watchLibrary(String uid)` (`Stream<List<LibraryItem>>`), `LibraryService.addToLibrary({required String uid, required int tmdbId, required String type})`, `LibraryService.markEpisodeWatched({required String uid, required int tmdbId, required int season, required int episode, required bool watched})`, `LibraryService.markSeasonWatched({required String uid, required int tmdbId, required int season, required List<int> episodeNumbers, required bool watched})`, `LibraryService.markMovieWatched({required String uid, required int tmdbId, required bool watched})`.
- Manual verification only (real Firestore instance required per Global Constraints).

- [ ] **Step 1: Write `lib/services/library_service.dart`**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/library_item.dart';

class LibraryService {
  final FirebaseFirestore _firestore;

  LibraryService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _libraryRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('library');

  Stream<List<LibraryItem>> watchLibrary(String uid) {
    return _libraryRef(uid).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => LibraryItem.fromMap(doc.id, doc.data())).toList(),
        );
  }

  Future<void> addToLibrary({required String uid, required int tmdbId, required String type}) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: type);
    final item = LibraryItem(
      docId: docId,
      tmdbId: tmdbId,
      type: type,
      status: 'watching',
      addedAt: DateTime.now(),
      watchedEpisodes: const {},
      watched: false,
      watchedAt: null,
    );
    return _libraryRef(uid).doc(docId).set(item.toMap());
  }

  Future<void> markEpisodeWatched({
    required String uid,
    required int tmdbId,
    required int season,
    required int episode,
    required bool watched,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    return _libraryRef(uid).doc(docId).update({
      'watchedEpisodes.s${season}e$episode': watched,
    });
  }

  Future<void> markSeasonWatched({
    required String uid,
    required int tmdbId,
    required int season,
    required List<int> episodeNumbers,
    required bool watched,
  }) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'tv');
    final updates = <String, dynamic>{
      for (final episode in episodeNumbers) 'watchedEpisodes.s${season}e$episode': watched,
    };
    return _libraryRef(uid).doc(docId).update(updates);
  }

  Future<void> markMovieWatched({required String uid, required int tmdbId, required bool watched}) {
    final docId = LibraryItem.buildDocId(tmdbId: tmdbId, type: 'movie');
    return _libraryRef(uid).doc(docId).update({
      'watched': watched,
      'watchedAt': watched ? DateTime.now().toIso8601String() : null,
    });
  }
}
```

- [ ] **Step 2: Write the email-allowlisted Firestore rules**

Create `firestore.rules` at the project root:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/library/{docId} {
      allow read, write: if request.auth != null
        && request.auth.uid == uid
        && request.auth.token.email in ['you@example.com', 'teammate@example.com'];
    }
  }
}
```

Create `firebase.json`:

```json
{
  "firestore": {
    "rules": "firestore.rules"
  }
}
```

Create `.firebaserc`:

```json
{
  "projects": {
    "default": "showtime-mehdi"
  }
}
```

- [ ] **Step 3: Deploy the rules**

```bash
firebase deploy --only firestore:rules
```

- [ ] **Step 4: Manual verification (deferred to Task 13/14)**

`LibraryService` is exercised end-to-end once `SearchScreen` (add to library) and `LibraryScreen` (read the stream) exist. At that point, confirm both that an allowlisted account can read/write and that a non-allowlisted Google account's Firestore calls are denied (sign in with any other Google account and confirm the app fails to load/write the library rather than silently succeeding).

- [ ] **Step 5: Commit**

```bash
git add lib/services/library_service.dart firestore.rules firebase.json .firebaserc
git commit -m "feat: add LibraryService with Firestore CRUD and email-allowlisted security rules"
```

---

### Task 10: App bootstrap, providers, and auth gate

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/providers/auth_provider.dart`
- Create: `lib/providers/library_provider.dart`

**Interfaces:**
- Consumes: `AuthService` (Task 8), `LibraryService` (Task 9), `DefaultFirebaseOptions` (Task 2).
- Produces: `AuthProvider.user` (`User?`), `LibraryProvider.items` (`List<LibraryItem>`), app-wide `Provider` setup consumed by every screen from Task 11 onward.

- [ ] **Step 1: Write `lib/providers/auth_provider.dart`**

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  User? _user;

  AuthProvider(this._authService) {
    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  User? get user => _user;

  Future<void> signInWithGoogle() => _authService.signInWithGoogle();

  Future<void> signOut() => _authService.signOut();
}
```

- [ ] **Step 2: Write `lib/providers/library_provider.dart`**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/library_item.dart';
import '../services/library_service.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryService _libraryService;
  StreamSubscription<List<LibraryItem>>? _subscription;
  List<LibraryItem> _items = [];

  LibraryProvider(this._libraryService);

  List<LibraryItem> get items => _items;

  void watch(String uid) {
    _subscription?.cancel();
    _subscription = _libraryService.watchLibrary(uid).listen((items) {
      _items = items;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 3: Write `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/library_service.dart';
import 'services/tmdb_service.dart';
import 'providers/auth_provider.dart';
import 'providers/library_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ShowtimeApp());
}

class ShowtimeApp extends StatelessWidget {
  const ShowtimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => TmdbService()),
        Provider(create: (_) => LibraryService()),
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService())),
        ChangeNotifierProvider(create: (context) => LibraryProvider(context.read<LibraryService>())),
      ],
      child: MaterialApp(
        title: 'Showtime',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          textTheme: GoogleFonts.interTextTheme(),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return const LoginScreen();
    }
    context.read<LibraryProvider>().watch(user.uid);
    return const HomeShell();
  }
}
```

- [ ] **Step 4: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Expected: app builds and launches to the login screen (a placeholder is fine here — real `LoginScreen` lands in Task 11). No crash on startup.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/providers
git commit -m "feat: wire up Firebase bootstrap, providers, and auth gate"
```

---

### Task 11: Login screen

**Files:**
- Create: `lib/screens/login_screen.dart`

**Interfaces:**
- Consumes: `AuthProvider.signInWithGoogle()` from Task 10.

- [ ] **Step 1: Write `lib/screens/login_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Showtime', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: const Text('Sign in with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: tap "Sign in with Google" → a Google popup window appears → select the allowlisted account → popup closes → app navigates away from the login screen (to `HomeShell`, built in Task 12). Confirms `AuthService`, `AuthProvider`, and `AuthGate` from Tasks 8/10 work end-to-end on `localhost` (which is authorized by default, unlike the deployed domain which needs Task 2 Step 4 to already be done).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/login_screen.dart
git commit -m "feat: add login screen with Google Sign-In"
```

---

### Task 12: Home shell with bottom navigation

**Files:**
- Create: `lib/screens/home_shell.dart`
- Create: `lib/screens/up_next_screen.dart` (placeholder body, filled in Task 17)
- Create: `lib/screens/calendar_screen.dart` (placeholder body, filled in Task 18)
- Create: `lib/screens/search_screen.dart` (placeholder body, filled in Task 13)
- Create: `lib/screens/library_screen.dart` (placeholder body, filled in Task 14)

**Interfaces:**
- Produces: `HomeShell` widget, the app's post-login root. Each tab screen is a real file from this task on — later tasks replace the placeholder `build()` body, not the file.

- [ ] **Step 1: Write placeholder tab screens**

Create each with the same shape, e.g. `lib/screens/up_next_screen.dart`:

```dart
import 'package:flutter/material.dart';

class UpNextScreen extends StatelessWidget {
  const UpNextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Up Next — coming in Task 17')));
  }
}
```

Repeat for `CalendarScreen` ("coming in Task 18"), `SearchScreen` ("coming in Task 13"), `LibraryScreen` ("coming in Task 14"), each in its own file with matching class name.

- [ ] **Step 2: Write `lib/screens/home_shell.dart`**

```dart
import 'package:flutter/material.dart';
import 'up_next_screen.dart';
import 'calendar_screen.dart';
import 'search_screen.dart';
import 'library_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    UpNextScreen(),
    CalendarScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.play_circle_outline), label: 'Up Next'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined), label: 'Library'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: after signing in, four bottom nav tabs appear and each shows its placeholder text when tapped.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home_shell.dart lib/screens/up_next_screen.dart lib/screens/calendar_screen.dart lib/screens/search_screen.dart lib/screens/library_screen.dart
git commit -m "feat: add home shell with bottom navigation and placeholder tabs"
```

---

### Task 13: Search screen

**Files:**
- Modify: `lib/screens/search_screen.dart`
- Create: `lib/widgets/poster_tile.dart`

**Interfaces:**
- Consumes: `TmdbService.search` (Task 3), `LibraryService.addToLibrary` (Task 9), `AuthProvider.user` (Task 10).
- Produces: `PosterTile` widget, reused by Task 14's `LibraryScreen`.

- [ ] **Step 1: Write `lib/widgets/poster_tile.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';

class PosterTile extends StatelessWidget {
  final String? posterPath;
  final String title;
  final VoidCallback? onTap;
  final Widget? overlay;

  const PosterTile({
    super.key,
    required this.posterPath,
    required this.title,
    this.onTap,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: posterPath != null
                      ? CachedNetworkImage(
                          imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
                          fit: BoxFit.cover,
                        )
                      : Container(color: Colors.grey[800], child: const Icon(Icons.tv)),
                ),
                if (overlay != null) overlay!,
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Write `lib/screens/search_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../services/tmdb_service.dart';
import '../services/library_service.dart';
import '../widgets/poster_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<TmdbSearchResult> _results = [];
  bool _loading = false;
  String? _error;

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context.read<TmdbService>().search(query);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = 'Search failed. Check your connection and try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user!.uid;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Search shows or movies'),
          onSubmitted: _runSearch,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.55,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return PosterTile(
                      posterPath: result.posterPath,
                      title: result.year != null ? '${result.title} (${result.year})' : result.title,
                      onTap: () async {
                        await context.read<LibraryService>().addToLibrary(
                              uid: uid,
                              tmdbId: result.id,
                              type: result.mediaType,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Added ${result.title}')));
                        }
                      },
                    );
                  },
                ),
    );
  }
}
```

- [ ] **Step 3: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: Search tab → type "Game of Thrones" → results grid appears with posters → tap a result → snackbar "Added Game of Thrones" appears → confirm a new document shows up under `users/{uid}/library` in the Firebase Console.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/search_screen.dart lib/widgets/poster_tile.dart
git commit -m "feat: add search screen with add-to-library action"
```

---

### Task 14: Library screen

**Files:**
- Modify: `lib/screens/library_screen.dart`

**Interfaces:**
- Consumes: `LibraryProvider.items` (Task 10), `TmdbService.getTvDetails`/`getMovieDetails` (Tasks 4/5) to resolve title/poster per item, `PosterTile` (Task 13).
- Produces: navigation to `ShowDetailScreen`/`MovieDetailScreen` (Tasks 15/16).

- [ ] **Step 1: Write `lib/screens/library_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/library_item.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../widgets/poster_tile.dart';
import 'show_detail_screen.dart';
import 'movie_detail_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<(String title, String? posterPath)> _resolveMeta(
      BuildContext context, LibraryItem item) async {
    final tmdb = context.read<TmdbService>();
    if (item.type == 'tv') {
      final details = await tmdb.getTvDetails(item.tmdbId);
      return (details.name, details.posterPath);
    } else {
      final details = await tmdb.getMovieDetails(item.tmdbId);
      return (details.title, details.posterPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<LibraryProvider>().items;

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: items.isEmpty
          ? const Center(child: Text('Nothing tracked yet — add shows from Search.'))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.55,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return FutureBuilder<(String title, String? posterPath)>(
                  future: _resolveMeta(context, item),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final (title, posterPath) = snapshot.data!;
                    return PosterTile(
                      posterPath: posterPath,
                      title: title,
                      overlay: item.type == 'movie' && item.watched
                          ? const Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.check_circle, color: Colors.greenAccent),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => item.type == 'tv'
                              ? ShowDetailScreen(libraryItem: item)
                              : MovieDetailScreen(libraryItem: item),
                        ));
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 2: Manual verification (partial — full flow confirmed after Task 15/16)**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: Library tab shows the item added in Task 13 with correct poster/title resolved live from TMDB (not from Firestore). Tapping it will error until Tasks 15/16 land — that's expected at this point.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/library_screen.dart
git commit -m "feat: add library screen resolving tracked items against TMDB"
```

---

### Task 15: Show detail screen (seasons, episodes, bulk mark)

**Files:**
- Modify: `lib/screens/show_detail_screen.dart`

**Interfaces:**
- Consumes: `TmdbService.getTvDetails`/`getSeasonDetails` (Task 4), `LibraryService.markEpisodeWatched`/`markSeasonWatched` (Task 9), `LibraryItem` (Task 6).

- [ ] **Step 1: Write `lib/screens/show_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';

class ShowDetailScreen extends StatefulWidget {
  final LibraryItem libraryItem;

  const ShowDetailScreen({super.key, required this.libraryItem});

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> {
  TvDetails? _details;
  int _selectedSeason = 1;
  SeasonDetails? _seasonDetails;
  Map<String, bool> _watchedEpisodes = {};

  @override
  void initState() {
    super.initState();
    _watchedEpisodes = Map.of(widget.libraryItem.watchedEpisodes);
    _load();
  }

  Future<void> _load() async {
    final tmdb = context.read<TmdbService>();
    final details = await tmdb.getTvDetails(widget.libraryItem.tmdbId);
    setState(() {
      _details = details;
      _selectedSeason = details.seasons.isNotEmpty ? details.seasons.first.seasonNumber : 1;
    });
    await _loadSeason(_selectedSeason);
  }

  Future<void> _loadSeason(int seasonNumber) async {
    final tmdb = context.read<TmdbService>();
    final season = await tmdb.getSeasonDetails(widget.libraryItem.tmdbId, seasonNumber);
    setState(() {
      _selectedSeason = seasonNumber;
      _seasonDetails = season;
    });
  }

  Future<void> _toggleEpisode(EpisodeRef ep) async {
    final uid = context.read<AuthProvider>().user!.uid;
    final newValue = !(_watchedEpisodes[ep.key] ?? false);
    setState(() => _watchedEpisodes[ep.key] = newValue);
    await context.read<LibraryService>().markEpisodeWatched(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          season: ep.seasonNumber,
          episode: ep.episodeNumber,
          watched: newValue,
        );
  }

  Future<void> _markSeasonWatched(bool watched) async {
    final season = _seasonDetails;
    if (season == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    setState(() {
      for (final ep in season.episodes) {
        _watchedEpisodes[ep.key] = watched;
      }
    });
    await context.read<LibraryService>().markSeasonWatched(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          season: _selectedSeason,
          episodeNumbers: season.episodes.map((e) => e.episodeNumber).toList(),
          watched: watched,
        );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(details.name)),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: details.seasons
                  .map((s) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(s.name),
                          selected: _selectedSeason == s.seasonNumber,
                          onSelected: (_) => _loadSeason(s.seasonNumber),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _markSeasonWatched(true),
                  child: const Text('Mark season watched'),
                ),
                TextButton(
                  onPressed: () => _markSeasonWatched(false),
                  child: const Text('Mark season unwatched'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _seasonDetails == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _seasonDetails!.episodes.length,
                    itemBuilder: (context, index) {
                      final ep = _seasonDetails!.episodes[index];
                      final watched = _watchedEpisodes[ep.key] ?? false;
                      return CheckboxListTile(
                        value: watched,
                        onChanged: (_) => _toggleEpisode(ep),
                        title: Text('${ep.episodeNumber}. ${ep.name}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: from Library, tap a tracked show → season chips appear → episode list loads for the first season → tap a checkbox → it toggles and Firestore's `watchedEpisodes` map updates (check Firebase Console) → "Mark season watched" checks every episode in the current season and updates Firestore in one batch.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/show_detail_screen.dart
git commit -m "feat: add show detail screen with episode and season tracking"
```

---

### Task 16: Movie detail screen

**Files:**
- Modify: `lib/screens/movie_detail_screen.dart`

**Interfaces:**
- Consumes: `TmdbService.getMovieDetails` (Task 5), `LibraryService.markMovieWatched` (Task 9), `LibraryItem` (Task 6).

- [ ] **Step 1: Write `lib/screens/movie_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../providers/auth_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';

class MovieDetailScreen extends StatefulWidget {
  final LibraryItem libraryItem;

  const MovieDetailScreen({super.key, required this.libraryItem});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _watched = false;

  @override
  void initState() {
    super.initState();
    _watched = widget.libraryItem.watched;
  }

  Future<void> _toggleWatched() async {
    final uid = context.read<AuthProvider>().user!.uid;
    final newValue = !_watched;
    setState(() => _watched = newValue);
    await context.read<LibraryService>().markMovieWatched(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          watched: newValue,
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<TmdbService>().getMovieDetails(widget.libraryItem.tmdbId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final movie = snapshot.data!;
        return Scaffold(
          appBar: AppBar(title: Text(movie.title)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (movie.posterPath != null)
                  SizedBox(
                    width: 200,
                    child: CachedNetworkImage(
                      imageUrl: '${TmdbConfig.imageBaseUrl}${movie.posterPath}',
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _toggleWatched,
                  icon: Icon(_watched ? Icons.check_circle : Icons.check_circle_outline),
                  label: Text(_watched ? 'Watched' : 'Mark watched'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: add a movie from Search → open it from Library → tap "Mark watched" → button flips to "Watched" → confirm `watched: true` and `watchedAt` are set on the Firestore doc → back out to Library, confirm the green checkmark overlay from Task 14 appears on the poster.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/movie_detail_screen.dart
git commit -m "feat: add movie detail screen with watched toggle"
```

---

### Task 17: Up Next screen

**Files:**
- Modify: `lib/screens/up_next_screen.dart`

**Interfaces:**
- Consumes: `LibraryProvider.items` (Task 10, filtered to `type == 'tv'`), `TmdbService.getTvDetails`/`getSeasonDetails` (Task 4), `nextUnwatchedEpisode` (Task 7).

- [ ] **Step 1: Write `lib/screens/up_next_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/up_next.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';
import '../widgets/poster_tile.dart';

class _UpNextRow {
  final String showTitle;
  final String? posterPath;
  final EpisodeRef episode;

  _UpNextRow({required this.showTitle, required this.posterPath, required this.episode});
}

class UpNextScreen extends StatelessWidget {
  const UpNextScreen({super.key});

  Future<_UpNextRow?> _resolveRow(TmdbService tmdb, LibraryItem item) async {
    final details = await tmdb.getTvDetails(item.tmdbId);
    final allEpisodes = <EpisodeRef>[];
    for (final season in details.seasons) {
      final seasonDetails = await tmdb.getSeasonDetails(item.tmdbId, season.seasonNumber);
      allEpisodes.addAll(seasonDetails.episodes);
    }
    final next = nextUnwatchedEpisode(
      episodesInOrder: allEpisodes,
      watchedEpisodes: item.watchedEpisodes,
      now: DateTime.now(),
    );
    if (next == null) return null;
    return _UpNextRow(showTitle: details.name, posterPath: details.posterPath, episode: next);
  }

  @override
  Widget build(BuildContext context) {
    final tvItems = context.watch<LibraryProvider>().items.where((i) => i.type == 'tv').toList();
    final tmdb = context.read<TmdbService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Up Next')),
      body: tvItems.isEmpty
          ? const Center(child: Text('Track a show from Search to see it here.'))
          : FutureBuilder<List<_UpNextRow?>>(
              future: Future.wait(tvItems.map((item) => _resolveRow(tmdb, item))),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!.whereType<_UpNextRow>().toList();
                if (rows.isEmpty) {
                  return const Center(child: Text('All caught up.'));
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return ListTile(
                      leading: SizedBox(
                        width: 48,
                        child: PosterTile(posterPath: row.posterPath, title: ''),
                      ),
                      title: Text(row.showTitle),
                      subtitle: Text('S${row.episode.seasonNumber}E${row.episode.episodeNumber} — ${row.episode.name}'),
                    );
                  },
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 2: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: track a show, mark its first episode watched from Show Detail → open Up Next tab → the show appears with its second episode listed as next → mark every aired episode watched → the show drops off Up Next entirely.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/up_next_screen.dart
git commit -m "feat: add Up Next screen using next-unwatched-episode logic"
```

---

### Task 18: Calendar screen

**Files:**
- Modify: `lib/screens/calendar_screen.dart`

**Interfaces:**
- Consumes: `LibraryProvider.items` (Task 10, filtered to `type == 'tv'`), `TmdbService.getTvDetails` (Task 4, `.nextEpisodeToAir`).

- [ ] **Step 1: Write `lib/screens/calendar_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/tmdb_models.dart';
import '../providers/library_provider.dart';
import '../services/tmdb_service.dart';

class _CalendarRow {
  final String showTitle;
  final NextEpisode episode;

  _CalendarRow({required this.showTitle, required this.episode});
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  Future<_CalendarRow?> _resolveRow(TmdbService tmdb, int tmdbId) async {
    final details = await tmdb.getTvDetails(tmdbId);
    final next = details.nextEpisodeToAir;
    if (next == null) return null;
    return _CalendarRow(showTitle: details.name, episode: next);
  }

  @override
  Widget build(BuildContext context) {
    final tvItems = context.watch<LibraryProvider>().items.where((i) => i.type == 'tv').toList();
    final tmdb = context.read<TmdbService>();
    final dateFormat = DateFormat.yMMMd();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: tvItems.isEmpty
          ? const Center(child: Text('Track a show from Search to see upcoming episodes.'))
          : FutureBuilder<List<_CalendarRow?>>(
              future: Future.wait(tvItems.map((item) => _resolveRow(tmdb, item.tmdbId))),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!.whereType<_CalendarRow>().toList()
                  ..sort((a, b) {
                    final aDate = a.episode.airDate;
                    final bDate = b.episode.airDate;
                    if (aDate == null) return 1;
                    if (bDate == null) return -1;
                    return aDate.compareTo(bDate);
                  });
                if (rows.isEmpty) {
                  return const Center(child: Text('No upcoming episodes scheduled.'));
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final date = row.episode.airDate;
                    return ListTile(
                      title: Text(row.showTitle),
                      subtitle: Text(
                          'S${row.episode.seasonNumber}E${row.episode.episodeNumber} — ${row.episode.name}'),
                      trailing: Text(date != null ? dateFormat.format(date) : 'TBA'),
                    );
                  },
                );
              },
            ),
    );
  }
}
```

- [ ] **Step 2: Manual verification**

```bash
flutter run -d chrome --dart-define=TMDB_API_KEY=your_key_here
```

Golden path: track a currently-airing show with a known upcoming episode → Calendar tab shows it with the correct air date, sorted soonest-first alongside any other tracked airing shows.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/calendar_screen.dart
git commit -m "feat: add Calendar screen showing upcoming episode air dates"
```

---

### Task 19: TMDB attribution and local release verification

**Files:**
- Modify: `lib/screens/library_screen.dart` (add attribution footer)

**Interfaces:**
- Consumes: `TmdbConfig.attribution` (Task 3).

- [ ] **Step 1: Add the attribution notice**

In `lib/screens/library_screen.dart`, add a `bottomNavigationBar` (or a footer widget below the grid) rendering `TmdbConfig.attribution` in small, muted text — satisfies the Global Constraint that the notice appear somewhere in the UI. Example, added to the `Scaffold` in `build()`:

```dart
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          TmdbConfig.attribution,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
```

(Add `import '../config/tmdb_config.dart';` to the top of the file.)

- [ ] **Step 2: Full golden-path walkthrough in a release build**

```bash
flutter build web --release --base-href /showtime/ --dart-define=TMDB_API_KEY=your_key_here
```

Serve the build output locally to test it as it will actually run (a plain `flutter run` uses debug mode, which behaves slightly differently than the compiled release output):

```bash
cd build/web
python -m http.server 8000
```

Open `http://localhost:8000` in a browser (note: `signInWithPopup` will work here because `localhost` is authorized by default, per Task 2). Walk the entire loop once, end to end: sign in → search for a show → add it → mark a couple of episodes watched from Show Detail → confirm it appears correctly (or drops off) in Up Next → confirm it appears in Calendar if it has an upcoming episode → search for and add a movie → mark it watched from Movie Detail → confirm the watched checkmark shows in Library → confirm the TMDB attribution text is visible on the Library tab.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/library_screen.dart
git commit -m "feat: add TMDB attribution notice and finish MVP golden path"
```

---

### Task 20: GitHub Actions deployment to GitHub Pages

**Files:**
- Create: `.github/workflows/deploy.yml`

**Interfaces:**
- Consumes: the full app from Tasks 1-19; the `TMDB_API_KEY` GitHub Actions repository secret (set manually, not committed).

- [ ] **Step 1: Add the TMDB API key as a repository secret**

In the GitHub repo (`Mehdi-F/showtime`) → Settings → Secrets and variables → Actions → New repository secret → name `TMDB_API_KEY`, value your TMDB key. This keeps the key out of the committed workflow file (it still ends up embedded in the compiled JS output, same accepted tradeoff as local `--dart-define` builds — see the spec's Architecture section).

- [ ] **Step 2: Write `.github/workflows/deploy.yml`**

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - run: flutter pub get

      - run: flutter build web --release --base-href /showtime/ --dart-define=TMDB_API_KEY=${{ secrets.TMDB_API_KEY }}

      - uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: build/web
```

- [ ] **Step 3: Push to `main` and verify the workflow runs**

```bash
git push origin master:main
```

(The local repo's default branch is `master`; the workflow triggers on `main`, matching the GitHub default branch convention — this pushes local `master` to the remote's `main`.)

In the GitHub repo → Actions tab, confirm the "Deploy to GitHub Pages" workflow runs to completion. This creates a `gh-pages` branch with the built site.

- [ ] **Step 4: Enable GitHub Pages**

In the GitHub repo → Settings → Pages → Source: "Deploy from a branch" → Branch: `gh-pages` / `(root)` → Save.

- [ ] **Step 5: Verify the deployed site**

Visit `https://mehdi-f.github.io/showtime/`. Confirm the login screen loads, "Sign in with Google" opens a popup, and an allowlisted account can sign in and reach the four-tab home shell (this is the first real test of the Task 2 Step 4 authorized-domain config against the live domain, not `localhost`).

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/deploy.yml
git commit -m "ci: deploy to GitHub Pages on push to main"
```

---

## Self-Review Notes

- **Spec coverage:** Search+add (Task 13), mark episodes/movies watched incl. bulk season (Tasks 15/16), Up Next (Task 17), Calendar (Task 18), Google Sign-In via popup (Tasks 8/10/11), Firestore data model with `type`-prefixed doc ids (Task 6/9), email-allowlisted access control (Task 9), TMDB attribution (Task 19), web-only build with `--base-href /showtime/` (Tasks 1, 2, 19, 20), GitHub Actions deploy to GitHub Pages (Task 20), authorized-domain config for the live URL (Task 2 Step 4, verified live in Task 20 Step 5). Import explicitly dropped per spec — no task references it.
- **Placeholder scan:** no TBD/TODO left in any step; the only "coming in Task N" text is literal placeholder UI copy for not-yet-built tabs, replaced by the referenced task itself, not a stand-in for missing plan content.
- **Type consistency:** `EpisodeRef.key` (Task 4) matches the map keys used in `LibraryItem.watchedEpisodes` (Task 6), `LibraryService.markEpisodeWatched`/`markSeasonWatched` (Task 9), and `nextUnwatchedEpisode` (Task 7). `LibraryItem.buildDocId` (Task 6) is the single source of truth for doc ids, used identically in `LibraryService` (Task 9) and `LibraryScreen`/`ShowDetailScreen`/`MovieDetailScreen` navigation (Tasks 14-16). `AuthService.signInWithGoogle()` (Task 8) returns `Future<UserCredential?>` and is called the same way from `AuthProvider` (Task 10) and `LoginScreen` (Task 11) regardless of the underlying popup vs. native-plugin mechanism, so no downstream task needed changes beyond Task 8 itself.
