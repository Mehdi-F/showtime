import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import '../config/tmdb_config.dart';
import '../logic/up_next.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_bar.dart';
import '../widgets/add_to_list_sheet.dart';
import '../widgets/animated_progress_bar.dart';
import '../widgets/app_page_route.dart';
import '../widgets/media_info_sections.dart';
import '../widgets/episode_detail_sheet.dart';
import '../widgets/round_check.dart';
import 'movie_detail_screen.dart';

enum _GapPromptChoice { yes, no, never }

enum _RewatchChoice { notWatched, rewatch }

Future<void> _forEachBounded<T>(List<T> items, int concurrency, Future<void> Function(T item) action) async {
  var index = 0;
  Future<void> worker() async {
    while (index < items.length) {
      final i = index++;
      await action(items[i]);
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
}

class ShowDetailScreen extends StatefulWidget {
  final LibraryItem? libraryItem;
  final int? previewTmdbId;

  const ShowDetailScreen({super.key, required LibraryItem libraryItem})
      : libraryItem = libraryItem,
        previewTmdbId = null;

  /// Shows a series' details without adding it to the library. Use when the
  /// user is just browsing (e.g. Explorer, recommendations) — following only
  /// happens when they tap "Suivre" or an action that requires it (marking
  /// an episode watched, favoriting, etc).
  const ShowDetailScreen.preview({super.key, required int tmdbId})
      : libraryItem = null,
        previewTmdbId = tmdbId;

  int get tmdbId => libraryItem?.tmdbId ?? previewTmdbId!;

  @override
  State<ShowDetailScreen> createState() => _ShowDetailScreenState();
}

class _ShowDetailScreenState extends State<ShowDetailScreen> with SingleTickerProviderStateMixin {
  LibraryItem? _libraryItem;
  TvDetails? _details;
  bool _loadError = false;
  Map<int, SeasonDetails> _seasonsByNumber = {};
  Set<int> _expandedSeasons = {};
  Map<String, bool> _watchedEpisodes = {};
  Map<String, int> _rewatchCounts = {};
  bool _favorite = false;
  late TabController _tabController;
  late final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 3));

  // Fetched once and reused across rebuilds — building these inline inside
  // _buildAboutTab would re-hit TMDB on every setState in this screen (e.g.
  // every episode checkbox tap), since TabBarView builds both tabs eagerly.
  late Future<List<WatchProvider>> _watchProvidersFuture;
  late Future<List<CastMember>> _creditsFuture;
  late Future<List<SimilarMedia>> _similarFuture;

  @override
  void initState() {
    super.initState();
    _libraryItem = widget.libraryItem;
    _watchedEpisodes = Map.of(widget.libraryItem?.watchedEpisodes ?? {});
    _rewatchCounts = Map.of(widget.libraryItem?.episodeRewatchCounts ?? {});
    _favorite = widget.libraryItem?.favorite ?? false;
    _tabController = TabController(length: 2, vsync: this);
    final tmdb = context.read<TmdbService>();
    _watchProvidersFuture = tmdb.getTvWatchProviders(widget.tmdbId);
    _creditsFuture = tmdb.getTvCredits(widget.tmdbId);
    _similarFuture = tmdb.getSimilarTv(widget.tmdbId);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _showSaveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Échec de la sauvegarde. Réessaie.')),
    );
  }

  Future<LibraryItem?> _ensureFollowed() async {
    final current = _libraryItem;
    if (current != null) return current;
    final uid = context.read<AuthProvider>().user!.uid;
    try {
      final item = await context.read<LibraryService>().addToLibrary(
            uid: uid,
            tmdbId: widget.tmdbId,
            type: 'tv',
          );
      if (mounted) setState(() => _libraryItem = item);
      return item;
    } catch (_) {
      _showSaveError();
      return null;
    }
  }

  Future<void> _toggleFavorite() async {
    final item = await _ensureFollowed();
    if (item == null) return;
    final newValue = !_favorite;
    final previous = _favorite;
    setState(() => _favorite = newValue);
    final uid = context.read<AuthProvider>().user!.uid;
    try {
      await context.read<LibraryService>().toggleFavorite(
            uid: uid,
            tmdbId: item.tmdbId,
            type: 'tv',
            favorite: newValue,
          );
    } catch (_) {
      if (mounted) setState(() => _favorite = previous);
      _showSaveError();
    }
  }

  Future<void> _unfollow() async {
    final item = _libraryItem;
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    try {
      await context.read<LibraryService>().removeFromLibrary(
            uid: uid,
            tmdbId: item.tmdbId,
            type: 'tv',
          );
      if (mounted) Navigator.of(context).maybePop();
    } catch (_) {
      _showSaveError();
    }
  }

  Future<void> _load() async {
    final tmdb = context.read<TmdbService>();
    setState(() => _loadError = false);
    final TvDetails details;
    try {
      details = await tmdb.getTvDetails(widget.tmdbId);
    } catch (_) {
      if (mounted) setState(() => _loadError = true);
      return;
    }
    if (!mounted) return;
    setState(() => _details = details);

    final seasonNumbers = details.seasons.map((s) => s.seasonNumber).toList();
    final loaded = <int, SeasonDetails>{};
    await _forEachBounded(seasonNumbers, 4, (n) async {
      try {
        loaded[n] = await tmdb.getSeasonDetails(widget.tmdbId, n);
      } catch (_) {
        // Leave this season unavailable rather than aborting the rest.
      }
    });
    if (!mounted) return;
    setState(() => _seasonsByNumber = loaded);

    final next = _nextEpisode;
    final defaultSeason =
        next?.seasonNumber ?? (details.seasons.isNotEmpty ? details.seasons.first.seasonNumber : null);
    setState(() => _expandedSeasons = defaultSeason != null ? {defaultSeason} : {});
  }

  Future<void> _refresh() async {
    final tmdb = context.read<TmdbService>();
    tmdb.clearCache();
    setState(() {
      _watchProvidersFuture = tmdb.getTvWatchProviders(widget.tmdbId);
      _creditsFuture = tmdb.getTvCredits(widget.tmdbId);
      _similarFuture = tmdb.getSimilarTv(widget.tmdbId);
    });
    await _load();
  }

  List<EpisodeRef> get _mainEpisodesInOrder {
    final seasons = (_details?.seasons ?? const <SeasonSummary>[]).where((s) => s.seasonNumber >= 1).toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
    final result = <EpisodeRef>[];
    for (final s in seasons) {
      final sd = _seasonsByNumber[s.seasonNumber];
      if (sd != null) result.addAll(sd.episodes);
    }
    return result;
  }

  EpisodeRef? get _nextEpisode => nextUnwatchedEpisode(
        episodesInOrder: _mainEpisodesInOrder,
        watchedEpisodes: _watchedEpisodes,
        now: DateTime.now(),
      );

  int _watchedCountForSeason(int seasonNumber) {
    final prefix = 's${seasonNumber}e';
    return _watchedEpisodes.entries.where((e) => e.value && e.key.startsWith(prefix)).length;
  }

  int get _totalMainEpisodes => (_details?.seasons ?? const <SeasonSummary>[])
      .where((s) => s.seasonNumber >= 1)
      .fold(0, (sum, s) => sum + s.episodeCount);

  int get _totalWatchedMain => (_details?.seasons ?? const <SeasonSummary>[])
      .where((s) => s.seasonNumber >= 1)
      .fold(0, (sum, s) => sum + _watchedCountForSeason(s.seasonNumber));

  bool get _isFullyWatched => _totalMainEpisodes > 0 && _totalWatchedMain >= _totalMainEpisodes;

  void _maybeCelebrate() {
    final details = _details;
    if (details != null && details.isEnded && _isFullyWatched) {
      _confettiController.play();
    }
  }

  Future<_RewatchChoice?> _askRewatchChoice() {
    return showDialog<_RewatchChoice>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Marquer comme...'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_RewatchChoice.notWatched),
            child: const Row(children: [
              Icon(Icons.visibility_off_outlined, color: AppColors.textSecondary),
              SizedBox(width: 12),
              Text('Pas vue'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(_RewatchChoice.rewatch),
            child: const Row(children: [
              Icon(Icons.replay, color: AppColors.accent),
              SizedBox(width: 12),
              Text('+1 Revue'),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEpisode(EpisodeRef ep) async {
    final item = await _ensureFollowed();
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    final library = context.read<LibraryService>();
    final wasWatched = _watchedEpisodes[ep.key] ?? false;

    if (wasWatched) {
      final choice = await _askRewatchChoice();
      if (!mounted || choice == null) return;
      if (choice == _RewatchChoice.rewatch) {
        final previousCount = _rewatchCounts[ep.key] ?? 0;
        setState(() => _rewatchCounts[ep.key] = previousCount + 1);
        try {
          await library.incrementRewatch(uid: uid, tmdbId: item.tmdbId, episodeKeys: [ep.key]);
        } catch (_) {
          if (mounted) setState(() => _rewatchCounts[ep.key] = previousCount);
          _showSaveError();
        }
        return;
      }
      setState(() => _watchedEpisodes[ep.key] = false);
      try {
        await library.markEpisodeWatched(
          uid: uid,
          tmdbId: item.tmdbId,
          season: ep.seasonNumber,
          episode: ep.episodeNumber,
          watched: false,
        );
      } catch (_) {
        if (mounted) setState(() => _watchedEpisodes[ep.key] = true);
        _showSaveError();
      }
      return;
    }

    if (!item.skipGapPrompt) {
      final season = _seasonsByNumber[ep.seasonNumber];
      if (season != null) {
        final earlierUnwatched = season.episodes
            .where((e) => e.episodeNumber < ep.episodeNumber && !(_watchedEpisodes[e.key] ?? false))
            .toList();
        if (earlierUnwatched.isNotEmpty) {
          final choice = await _askMarkPreviousEpisodes();
          if (!mounted) return;
          if (choice == _GapPromptChoice.never) {
            try {
              await library.setSkipGapPrompt(uid: uid, tmdbId: item.tmdbId, skip: true);
              if (mounted) setState(() => _libraryItem = item.copyWith(skipGapPrompt: true));
            } catch (_) {
              _showSaveError();
            }
          } else if (choice == _GapPromptChoice.yes) {
            setState(() {
              for (final e in earlierUnwatched) {
                _watchedEpisodes[e.key] = true;
              }
              _watchedEpisodes[ep.key] = true;
            });
            try {
              await library.markSeasonWatched(
                uid: uid,
                tmdbId: item.tmdbId,
                season: ep.seasonNumber,
                episodeNumbers: [...earlierUnwatched.map((e) => e.episodeNumber), ep.episodeNumber],
                watched: true,
              );
              if (mounted) _maybeCelebrate();
            } catch (_) {
              if (mounted) {
                setState(() {
                  for (final e in earlierUnwatched) {
                    _watchedEpisodes[e.key] = false;
                  }
                  _watchedEpisodes[ep.key] = false;
                });
              }
              _showSaveError();
            }
            return;
          }
        }
      }
    }

    setState(() => _watchedEpisodes[ep.key] = true);
    try {
      await library.markEpisodeWatched(
        uid: uid,
        tmdbId: item.tmdbId,
        season: ep.seasonNumber,
        episode: ep.episodeNumber,
        watched: true,
      );
      if (mounted) _maybeCelebrate();
    } catch (_) {
      if (mounted) setState(() => _watchedEpisodes[ep.key] = false);
      _showSaveError();
    }
  }

  Future<_GapPromptChoice?> _askMarkPreviousEpisodes() {
    return showDialog<_GapPromptChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marquer les épisodes précédents ?'),
        content: const Text('Voulez-vous marquer tous les épisodes précédents comme vus ?'),
        actions: [
          SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_GapPromptChoice.yes),
                    child: const Text('OUI'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(_GapPromptChoice.no),
                    child: const Text('NON'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(_GapPromptChoice.never),
                    child: const Text('JAMAIS POUR CETTE SÉRIE'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSeason(int seasonNumber) async {
    final season = _seasonsByNumber[seasonNumber];
    if (season == null || season.episodes.isEmpty) return;
    final item = await _ensureFollowed();
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    final library = context.read<LibraryService>();
    final keys = season.episodes.map((e) => e.key).toList();
    final episodeNumbers = season.episodes.map((e) => e.episodeNumber).toList();
    final fullyWatched = keys.every((k) => _watchedEpisodes[k] ?? false);

    if (fullyWatched) {
      final choice = await _askRewatchChoice();
      if (!mounted || choice == null) return;
      if (choice == _RewatchChoice.rewatch) {
        final previousCounts = {for (final k in keys) k: _rewatchCounts[k] ?? 0};
        setState(() {
          for (final k in keys) {
            _rewatchCounts[k] = previousCounts[k]! + 1;
          }
        });
        try {
          await library.incrementRewatch(uid: uid, tmdbId: item.tmdbId, episodeKeys: keys);
        } catch (_) {
          if (mounted) {
            setState(() {
              for (final k in keys) {
                _rewatchCounts[k] = previousCounts[k]!;
              }
            });
          }
          _showSaveError();
        }
        return;
      }
      setState(() {
        for (final k in keys) {
          _watchedEpisodes[k] = false;
        }
      });
      try {
        await library.markSeasonWatched(
          uid: uid,
          tmdbId: item.tmdbId,
          season: seasonNumber,
          episodeNumbers: episodeNumbers,
          watched: false,
        );
      } catch (_) {
        if (mounted) {
          setState(() {
            for (final k in keys) {
              _watchedEpisodes[k] = true;
            }
          });
        }
        _showSaveError();
      }
      return;
    }

    setState(() {
      for (final k in keys) {
        _watchedEpisodes[k] = true;
      }
    });
    try {
      await library.markSeasonWatched(
        uid: uid,
        tmdbId: item.tmdbId,
        season: seasonNumber,
        episodeNumbers: episodeNumbers,
        watched: true,
      );
      if (mounted) _maybeCelebrate();
    } catch (_) {
      if (mounted) {
        setState(() {
          for (final k in keys) {
            _watchedEpisodes[k] = false;
          }
        });
      }
      _showSaveError();
    }
  }

  Future<void> _toggleAll() async {
    final keys = _mainEpisodesInOrder.map((e) => e.key).toList();
    if (keys.isEmpty) return;
    final item = await _ensureFollowed();
    if (item == null) return;
    final uid = context.read<AuthProvider>().user!.uid;
    final library = context.read<LibraryService>();

    if (_isFullyWatched) {
      final choice = await _askRewatchChoice();
      if (!mounted || choice == null) return;
      if (choice == _RewatchChoice.rewatch) {
        final previousCounts = {for (final k in keys) k: _rewatchCounts[k] ?? 0};
        setState(() {
          for (final k in keys) {
            _rewatchCounts[k] = previousCounts[k]! + 1;
          }
        });
        try {
          await library.incrementRewatch(uid: uid, tmdbId: item.tmdbId, episodeKeys: keys);
        } catch (_) {
          if (mounted) {
            setState(() {
              for (final k in keys) {
                _rewatchCounts[k] = previousCounts[k]!;
              }
            });
          }
          _showSaveError();
        }
        return;
      }
      setState(() {
        for (final k in keys) {
          _watchedEpisodes[k] = false;
        }
      });
      try {
        await library.setEpisodesWatched(uid: uid, tmdbId: item.tmdbId, episodeKeys: keys, watched: false);
      } catch (_) {
        if (mounted) {
          setState(() {
            for (final k in keys) {
              _watchedEpisodes[k] = true;
            }
          });
        }
        _showSaveError();
      }
      return;
    }

    setState(() {
      for (final k in keys) {
        _watchedEpisodes[k] = true;
      }
    });
    try {
      await library.setEpisodesWatched(uid: uid, tmdbId: item.tmdbId, episodeKeys: keys, watched: true);
      if (mounted) _maybeCelebrate();
    } catch (_) {
      if (mounted) {
        setState(() {
          for (final k in keys) {
            _watchedEpisodes[k] = false;
          }
        });
      }
      _showSaveError();
    }
  }

  Future<void> _openSimilar(SimilarMedia media) async {
    final matches = context
        .read<LibraryProvider>()
        .items
        .where((i) => i.tmdbId == media.id && i.type == media.type);
    if (!mounted) return;
    if (matches.isNotEmpty) {
      final item = matches.first;
      Navigator.of(context).push(appRoute(
        builder: (_) =>
            media.type == 'tv' ? ShowDetailScreen(libraryItem: item) : MovieDetailScreen(libraryItem: item),
      ));
    } else {
      Navigator.of(context).push(appRoute(
        builder: (_) => media.type == 'tv'
            ? ShowDetailScreen.preview(tmdbId: media.id)
            : MovieDetailScreen.preview(tmdbId: media.id),
      ));
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Widget _buildAboutTab(TvDetails details) {
    final String? yearRange;
    if (details.firstAirYear == null) {
      yearRange = null;
    } else if (!details.isEnded) {
      yearRange = '${details.firstAirYear} - présent';
    } else if (details.lastAirYear != null && details.lastAirYear != details.firstAirYear) {
      yearRange = '${details.firstAirYear} - ${details.lastAirYear}';
    } else {
      yearRange = '${details.firstAirYear}';
    }

    final libraryItem = _libraryItem;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        WatchProvidersRow(future: _watchProvidersFuture),
        InfoCard(
          yearRange: yearRange,
          genres: details.genres,
          voteAverage: details.voteAverage,
          overview: details.overview,
          runtimeMinutes: details.episodeRunTime,
          addedCaption: libraryItem != null
              ? 'Ajoutée à votre bibliothèque le ${_formatDate(libraryItem.addedAt)}'
              : 'Pas encore suivie',
        ),
        CastRow(future: _creditsFuture),
        SimilarRow(
          title: 'Vous pourriez aussi aimer',
          future: _similarFuture,
          onTap: _openSimilar,
        ),
      ],
    );
  }

  Widget _buildNextEpisodeCard(EpisodeRef ep) {
    final watched = _watchedEpisodes[ep.key] ?? false;
    return GestureDetector(
      onTap: () => showEpisodeDetailSheet(
        context,
        episode: ep,
        watched: watched,
        onToggleWatched: () => _toggleEpisode(ep),
      ),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 96,
                height: 60,
                child: ep.stillPath != null
                    ? CachedNetworkImage(imageUrl: '${TmdbConfig.imageBaseUrl}${ep.stillPath}', fit: BoxFit.cover)
                    : Container(color: AppColors.surface, child: const Icon(Icons.tv, color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'S${ep.seasonNumber.toString().padLeft(2, '0')} | E${ep.episodeNumber.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(ep.name,
                      style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            RoundCheck(checked: watched, onTap: () => _toggleEpisode(ep)),
          ],
        ),
      ),
    );
  }

  Widget _buildCaughtUpCard(TvDetails details) {
    final done = details.isEnded && _totalMainEpisodes > 0;
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(done ? 'Terminée' : 'À jour', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            done ? "C'est tout, les sériévores !" : 'En attente du prochain épisode.',
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeRow(EpisodeRef ep) {
    final watched = _watchedEpisodes[ep.key] ?? false;
    final rewatchCount = _rewatchCounts[ep.key] ?? 0;
    final subtitleParts = <String>[
      if (ep.airDate != null) formatFrDate(ep.airDate!),
      if (rewatchCount > 0) '+$rewatchCount revue${rewatchCount > 1 ? "s" : ""}',
    ];
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 64,
          height: 40,
          child: ep.stillPath != null
              ? CachedNetworkImage(imageUrl: '${TmdbConfig.imageBaseUrl}${ep.stillPath}', fit: BoxFit.cover)
              : Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.tv, color: AppColors.textSecondary, size: 18),
                ),
        ),
      ),
      title: Text('${ep.episodeNumber}. ${ep.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
      trailing: RoundCheck(checked: watched, onTap: () => _toggleEpisode(ep)),
      onTap: () => showEpisodeDetailSheet(
        context,
        episode: ep,
        watched: watched,
        onToggleWatched: () => _toggleEpisode(ep),
      ),
    );
  }

  Widget _buildSeasonSection(SeasonSummary summary, bool isEnded) {
    final expanded = _expandedSeasons.contains(summary.seasonNumber);
    final watchedCount = _watchedCountForSeason(summary.seasonNumber);
    final total = summary.episodeCount;
    final ratio = total == 0 ? 0.0 : watchedCount / total;
    final fullyWatched = total > 0 && watchedCount >= total;
    final barColor = fullyWatched ? (isEnded ? Colors.purple : Colors.green) : AppColors.accent;
    final seasonDetails = _seasonsByNumber[summary.seasonNumber];

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expandedSeasons.remove(summary.seasonNumber);
            } else {
              _expandedSeasons.add(summary.seasonNumber);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(summary.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text('$watchedCount/$total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _toggleSeason(summary.seasonNumber),
                  child: Icon(
                    fullyWatched ? Icons.check_circle : Icons.check_circle_outline,
                    color: fullyWatched ? barColor : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedProgressBar(
              value: ratio,
              color: barColor,
              backgroundColor: AppColors.surfaceVariant,
            ),
          ),
        ),
        if (expanded && seasonDetails != null)
          ...seasonDetails.episodes.map(_buildEpisodeRow)
        else if (expanded)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSpecialsSection() {
    final expanded = _expandedSeasons.contains(0);
    final seasonDetails = _seasonsByNumber[0];
    final total = seasonDetails?.episodes.length ?? 0;
    final watchedCount = _watchedCountForSeason(0);
    final fullyWatched = total > 0 && watchedCount >= total;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expandedSeasons.remove(0);
            } else {
              _expandedSeasons.add(0);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Spéciaux', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Text('$watchedCount/$total', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _toggleSeason(0),
                  child: Icon(
                    fullyWatched ? Icons.check_circle : Icons.check_circle_outline,
                    color: fullyWatched ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded && seasonDetails != null) ...seasonDetails.episodes.map(_buildEpisodeRow),
      ],
    );
  }

  Widget _buildEpisodesTab(TvDetails details) {
    final next = _nextEpisode;
    final seasons = details.seasons.where((s) => s.seasonNumber >= 1).toList()
      ..sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('DÉMARRER LE SUIVI',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: next != null ? _buildNextEpisodeCard(next) : _buildCaughtUpCard(details),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOUS LES ÉPISODES',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
              GestureDetector(
                onTap: _toggleAll,
                child: Icon(
                  _isFullyWatched ? Icons.check_circle : Icons.check_circle_outline,
                  color: _isFullyWatched ? (details.isEnded ? Colors.purple : Colors.green) : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...seasons.map((s) => _buildSeasonSection(s, details.isEnded)),
        if (details.hasSpecials) _buildSpecialsSection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    if (details == null) {
      if (_loadError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Impossible de charger cette série.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
            children: [
              _ShowBanner(
                title: details.name,
                posterPath: details.posterPath,
                isEnded: details.isEnded,
                seasonCount: details.seasons.where((s) => s.seasonNumber >= 1).length,
                progress: _totalMainEpisodes > 0 ? _totalWatchedMain / _totalMainEpisodes : null,
                favorite: _favorite,
                followed: _libraryItem != null,
                onToggleFavorite: _toggleFavorite,
                onUnfollow: _unfollow,
                onAddToList: () => showAddToListSheet(
                  context,
                  tmdbId: widget.tmdbId,
                  type: 'tv',
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.accent,
                tabs: const [Tab(text: 'À PROPOS'), Tab(text: 'ÉPISODES')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAboutTab(details),
                    _buildEpisodesTab(details),
                  ],
                ),
              ),
            ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              colors: const [Colors.yellow, Colors.green, Colors.blue, Colors.red, Colors.purple],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _libraryItem == null ? AddBar(label: 'AJOUTER LA SÉRIE', onTap: _ensureFollowed) : null,
    );
  }
}

class _ShowBanner extends StatelessWidget {
  final String title;
  final String? posterPath;
  final bool isEnded;
  final int seasonCount;
  final double? progress;
  final bool favorite;
  final bool followed;
  final VoidCallback onToggleFavorite;
  final VoidCallback onUnfollow;
  final VoidCallback onAddToList;

  const _ShowBanner({
    required this.title,
    required this.posterPath,
    required this.isEnded,
    required this.seasonCount,
    required this.progress,
    required this.favorite,
    required this.followed,
    required this.onToggleFavorite,
    required this.onUnfollow,
    required this.onAddToList,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterPath != null)
            CachedNetworkImage(
              imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
              fit: BoxFit.cover,
            )
          else
            Container(color: AppColors.surfaceVariant),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.85)],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 4,
            right: 4,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Row(
                    children: [
                      if (followed)
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              favorite ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey(favorite),
                              color: favorite ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          onPressed: onToggleFavorite,
                        ),
                      if (followed)
                        PopupMenuButton<void>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          color: AppColors.surface,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              onTap: onAddToList,
                              child: const Text('Ajouter à une liste'),
                            ),
                            PopupMenuItem(
                              onTap: onUnfollow,
                              child: const Text('Remove from Library'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$seasonCount saison${seasonCount > 1 ? 's' : ''} • ${isEnded ? 'Terminée' : 'En cours'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (progress != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedProgressBar(
                value: progress!,
                color: progress! >= 1.0 ? (isEnded ? Colors.purple : Colors.green) : AppColors.accent,
                backgroundColor: Colors.black45,
              ),
            ),
        ],
      ),
    );
  }
}
