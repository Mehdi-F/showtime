# Showtime — MVP Design

**Date:** 2026-07-02 (revised same day: pivoted from Android app to website)
**Status:** Approved
**Context:** TV Time (show/movie tracking app) shuts down 2026-07-15, servers already unreachable. This is a personal replacement — Mehdi plus a small, known set of people he invites, not a public product. Originally scoped as an Android app; pivoted to a website hosted on GitHub Pages before implementation started (no code had been written yet).

## Goal

Replicate TV Time's core tracking loop: search a show/movie, add it to your library, mark episodes/movies watched, see what's next to watch and when new episodes air. Not a social app, not a clone of every TV Time feature — just the tracking mechanic.

## Platform & Stack

- **Flutter Web** — compiles to static HTML/JS/CSS, which is exactly what GitHub Pages hosts. Reuses Mehdi's existing Flutter skillset (same as VoiSi) instead of learning a new web stack.
- **Hosting: GitHub Pages**, serving the `showtime` repo. Static hosting only — no server, no backend process. This constrains the architecture to "client talks directly to third-party services," which the design already assumed (see Architecture below), so the pivot doesn't change the data flow, only the build/deploy target.
- **Firebase**: Firestore (tracking data) + Firebase Auth with Google Sign-In (`signInWithPopup`, the standard flow for Flutter web — no separate `google_sign_in` package needed). Multiple known people can use the site, each with their own isolated Firestore data — see Access Control below.
- **TMDB API** (themoviedb.org) — free, public metadata source for shows/movies: posters, season/episode lists, air dates. Requires a free API key (Mehdi to set up) and in-app attribution per TMDB's ToS ("This product uses the TMDB API but is not endorsed or certified by TMDB").

## Architecture

TMDB is called **directly from the Flutter web app** with the API key embedded client-side — no backend proxy. This was already the plan for the Android version and holds unchanged: GitHub Pages couldn't run a proxy even if the design wanted one.

- Rejected alternative: proxying TMDB through a Firebase Cloud Function to hide the key. No Cloud Functions have been built for VoiSi yet either — avoid taking on that infra for zero practical benefit on a small-audience personal site.

TMDB data is **never duplicated into Firestore** — always fetched live, so posters/episode lists/air dates stay fresh without a sync/cache layer to maintain. Firestore stores only tracking state (what's watched, what's in the library).

## Access Control

The site URL is publicly reachable (GitHub Pages has no access control of its own), so sign-in is gated by a **Firestore security rule allowlist** rather than an open door:

```
allow read, write: if request.auth != null
  && request.auth.token.email in ['you@example.com', 'teammate@example.com'];
```

Anyone can load the page and attempt to sign in, but only allowlisted emails get Firestore read/write access — everyone else's sign-in succeeds at the Firebase Auth level but every Firestore call is denied, so the app effectively refuses them. Mehdi will add more emails to the list later by editing and redeploying `firestore.rules`; no code change needed elsewhere. Each allowlisted person gets their own isolated `users/{uid}/library` — no shared state between people.

The GitHub Pages domain (`<github-username>.github.io`) must be added to Firebase Console → Authentication → Settings → Authorized domains, or `signInWithPopup` will be rejected by Firebase.

## Deployment

A GitHub Actions workflow builds the Flutter web app and publishes it to GitHub Pages on every push to `main`:

```bash
flutter build web --release --base-href /showtime/
```

The `--base-href` must match the repo name (`/showtime/`) because a GitHub Pages project site (as opposed to a `<username>.github.io` user site) is served from that subpath.

## Data Model (Firestore)

```
users/{uid}/library/{type}_{tmdbId}
  type: "tv" | "movie"
  status: "watching" | "completed" | "plan_to_watch"  (light status, not a full state machine)
  addedAt: timestamp
  watchedEpisodes: { "s1e1": true, "s1e2": true, ... }   // tv only
  watched: bool                                            // movie only
  watchedAt: timestamp                                     // movie only
```

One doc per tracked title. The doc id is prefixed with `type` because TMDB ids are only unique within a media type — a tv show and a movie can share the same numeric id, so `{tmdbId}` alone would collide. Episode identity is `s{season}e{episode}` — matches TMDB's season/episode numbering directly, no separate episode ID lookup needed.

## Screens (bottom nav)

1. **Up Next** — one row per tracked show with an unwatched episode: poster, episode title/number, "mark watched" action. This is the daily-use screen.
2. **Calendar** — upcoming air dates for tracked shows, sourced from TMDB's `next_episode_to_air` field on the TV series detail endpoint (no extra API call needed).
3. **Search** — TMDB multi-search (tv + movie combined), add result to library with one tap.
4. **Library** — grid of everything tracked (shows + movies), tap a show to open its full season/episode list with per-episode watched toggle and a "mark whole season watched" bulk action. Tap a movie to toggle watched.

## Explicitly Out of Scope (MVP)

- Notifications for new episode air dates (check Calendar manually instead)
- Ratings/reviews, stats/badges, social features (friends, activity feed) — TV Time had these, not needed for personal tracking
- TV Time data import — TV Time's servers are down as of this writing; the GDPR export tool and password reset are both failing. Import is dropped from MVP scope. If a manual data export is ever obtained later (e.g. via a GDPR support ticket), a one-off parser can be added then — not blocking this build.
- Native mobile builds (Android/iOS) — web-only for this MVP, matching the pivot to GitHub Pages hosting.
- Custom domain, offline/PWA install support — plain GitHub Pages URL is enough for MVP.

## Error Handling

- TMDB request failures (network, rate limit): show inline retry state on the affected screen, don't crash. No offline cache for MVP — app requires connectivity to browse metadata (tracking actions against Firestore can queue offline via Firestore's built-in offline persistence).
- Firestore writes (mark watched, add to library) use Firestore's default offline queueing — actions taken offline apply when connectivity returns.

## Testing

Manual verification in-browser against the golden path (search → add → mark episodes watched → confirm Up Next/Library reflect state) — no automated test suite planned for this MVP; matches the pace of a 2-week personal project.
