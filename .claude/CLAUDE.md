# Showtime – Claude Code Setup

Development environment & workflow for the Showtime Flutter app.

## Quick Start

```bash
git clone https://github.com/Mehdi-F/showtime.git
cd showtime
flutter pub get
flutter run
```

## Repository Structure

```
lib/
├── screens/           # UI pages (ProfileScreen, FriendsScreen, etc.)
├── widgets/          # Reusable Flutter widgets
├── models/           # Data models (LibraryItem, TmdbModels, etc.)
├── providers/        # State management (Provider package)
├── services/         # API & business logic (TmdbService, LinkService, etc.)
├── theme/            # Theming & colors (AppColors, AppTheme)
├── l10n/             # Localization (FR/EN translations)
└── config/           # Configuration (TmdbConfig, constants)
```

## Development Branch

- **main** — Production-ready, deployed to users
- Feature branches — `claude/*` for ongoing work

## Skills & Workflows

### Caveman 🗣️
Ultra-concise responses, 60–70% fewer tokens.
```bash
/caveman      # Activate for this turn
/caveman-review    # Review code terse-style
```

### Superpowers 🦸
Structured development: brainstorm → plan → code → test → review.
```bash
/superpowers:plan     # Planning phase only
/superpowers:tdd      # TDD cycle (RED-GREEN-REFACTOR)
/superpowers:review   # Pre-merge code review
/superpowers         # Full workflow
```

**Combo tip:** `/superpowers:plan` + `/caveman` = efficient long sessions.

## Translation System

All UI text is translatable via `context.tr()` (FR/EN):
- Add keys to `lib/l10n/app_strings.dart`
- Use `Text(context.tr('key.name'))` in screens
- No hardcoded strings in widgets

Example:
```dart
Text(context.tr('friends.title'))  // "Amis" (FR) / "Friends" (EN)
```

## State Management

Uses **Provider** for reactive state:
- `LibraryProvider` — User's library (series/films/lists)
- `SettingsProvider` — User preferences (language, theme)
- `AuthProvider` — Authentication & sign-out
- `ListsProvider` — Custom watch lists

Example:
```dart
final lib = context.watch<LibraryProvider>().items;
```

## Common Tasks

### Add a translation key
1. Add to `lib/l10n/app_strings.dart` (both 'fr' and 'en')
2. Use in widget: `Text(context.tr('key.name'))`

### Fix a bug
1. Use `/superpowers:plan` to break it down
2. Write test first (if logic-heavy)
3. Fix with minimal code
4. Run full test suite
5. Commit with clear message

### Redesign a screen
1. Read existing layout & state
2. Plan changes (what's staying/going/new)
3. Update incrementally (test on device)
4. Use `/design:critique` (if design plugin active)

### Merge to main
- All work is on feature branches
- Push to branch, code is auto-reviewed
- Once ready, cherry-pick or rebase onto main
- Push main for deployment

## Deployment

- `main` branch → Deployed to production
- All pushes to main trigger CI/CD
- Check GitHub Actions for build status

## Useful Commands

```bash
flutter pub get              # Install deps
flutter run                  # Run on emulator/device
flutter analyze             # Lint check
flutter test               # Run tests
git status                 # Check branch & changes
git push origin main       # Deploy
```

## Tips

- **Before coding:** Ask clarifying questions (what, why, who, edge cases?)
- **One task = one commit:** Keep commits small & reviewable
- **Test as you go:** Don't defer testing to the end
- **Use Caveman:** Long sessions? Use `/caveman` to save tokens
- **Use Superpowers:** Complex features? Use `/superpowers:plan` first

## Questions?

Check the README.md or ask in-session. Claude Code is your pair programmer — use it!
