# Showtime

A personal TV show & movie tracker — a TV Time replacement built with Flutter Web.

Track what you're watching, get notified about new episodes, browse and discover
new shows/movies, keep custom lists, and follow friends' libraries — all backed
by [TMDB](https://www.themoviedb.org/) for metadata and Firebase for auth/storage.

Live at: https://mehdi-f.github.io/showtime/

## Features

- **Séries / Films** — track what you're watching, mark episodes/movies as
  watched, see what's next to watch and what's coming up.
- **Explorer** — discover trending, popular, and top-rated shows/movies by genre.
- **Profile** — stats (episodes watched, watch time), custom lists, and
  carousels of your series/films/favorites with a grouped sticky-section view
  (En cours / Pas commencé / À jour / Terminé / Arrêtée for series, Vu / Pas vu
  for films).
- **Friends** — link accounts by email to view a friend's library and profile
  read-only.
- **Custom lists** — group shows/movies into your own lists.
- **TV Time import** — import your watch history from a TV Time GDPR data export.
- Season/episode rewatch tracking, gap-detection prompts, watch providers, cast
  and recommendations on every detail page.

## Tech stack

- [Flutter](https://flutter.dev/) (web target)
- [Firebase](https://firebase.google.com/) — Google sign-in auth + Cloud Firestore
- [TMDB API](https://www.themoviedb.org/documentation/api) — show/movie metadata
- Deployed to GitHub Pages via GitHub Actions on every push to `main`

## Development

```
flutter pub get
flutter run -d chrome
```

Requires a TMDB API key configured in `lib/config/tmdb_config.dart` and a
Firebase project (`lib/firebase_options.dart`) to run locally.
