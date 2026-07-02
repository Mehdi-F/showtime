# Showtime — MVP Design

**Date:** 2026-07-02
**Status:** Approved
**Context:** TV Time (show/movie tracking app) shuts down 2026-07-15, servers already unreachable. This is a personal replacement app — solo user (Mehdi), Android only, no app store distribution.

## Goal

Replicate TV Time's core tracking loop: search a show/movie, add it to your library, mark episodes/movies watched, see what's next to watch and when new episodes air. Not a social app, not a clone of every TV Time feature — just the tracking mechanic.

## Platform & Stack

- **Flutter, Android only** — sideloaded APK, no Play Store listing. Matches the existing VoiSi project's stack and Mehdi's current experience.
- **Firebase**: Firestore (tracking data) + Google Sign-In (auth). Single user, but cloud-synced so data survives phone loss/reset — same pattern as VoiSi.
- **TMDB API** (themoviedb.org) — free, public metadata source for shows/movies: posters, season/episode lists, air dates. Requires a free API key (Mehdi to set up) and in-app attribution per TMDB's ToS ("This product uses the TMDB API but is not endorsed or certified by TMDB").

## Architecture

TMDB is called **directly from the Flutter app** with the API key embedded client-side — no backend proxy.

- Rejected alternative: proxying TMDB through a Firebase Cloud Function to hide the key. Correct for a public product, but pure overhead for a sideloaded personal app with one user. No Cloud Functions have been built for VoiSi yet either — avoid taking on that infra for zero practical benefit here.

TMDB data is **never duplicated into Firestore** — always fetched live, so posters/episode lists/air dates stay fresh without a sync/cache layer to maintain. Firestore stores only tracking state (what's watched, what's in the library).

## Data Model (Firestore)

```
users/{uid}/library/{tmdbId}
  type: "tv" | "movie"
  status: "watching" | "completed" | "plan_to_watch"  (light status, not a full state machine)
  addedAt: timestamp
  watchedEpisodes: { "s1e1": true, "s1e2": true, ... }   // tv only
  watched: bool                                            // movie only
  watchedAt: timestamp                                     // movie only
```

One doc per tracked title. Episode identity is `s{season}e{episode}` — matches TMDB's season/episode numbering directly, no separate episode ID lookup needed.

## Screens (bottom nav)

1. **Up Next** — one row per tracked show with an unwatched episode: poster, episode title/number, "mark watched" action. This is the daily-use screen.
2. **Calendar** — upcoming air dates for tracked shows, sourced from TMDB's `next_episode_to_air` field on the TV series detail endpoint (no extra API call needed).
3. **Search** — TMDB multi-search (tv + movie combined), add result to library with one tap.
4. **Library** — grid of everything tracked (shows + movies), tap a show to open its full season/episode list with per-episode watched toggle and a "mark whole season watched" bulk action. Tap a movie to toggle watched.

## Explicitly Out of Scope (MVP)

- Notifications for new episode air dates (check Calendar manually instead)
- Ratings/reviews, stats/badges, social features (friends, activity feed) — TV Time had these, not needed for personal tracking
- TV Time data import — TV Time's servers are down as of this writing; the GDPR export tool and password reset are both failing. Import is dropped from MVP scope. If a manual data export is ever obtained later (e.g. via a GDPR support ticket), a one-off parser can be added then — not blocking this build.
- iOS build (no Apple Developer account currently, per VoiSi project state)

## Error Handling

- TMDB request failures (network, rate limit): show inline retry state on the affected screen, don't crash. No offline cache for MVP — app requires connectivity to browse metadata (tracking actions against Firestore can queue offline via Firestore's built-in offline persistence).
- Firestore writes (mark watched, add to library) use Firestore's default offline queueing — actions taken offline apply when connectivity returns.

## Testing

Manual verification on-device against the golden path (search → add → mark episodes watched → confirm Up Next/Library reflect state) — no automated test suite planned for this MVP; matches the pace of a 2-week personal project.
