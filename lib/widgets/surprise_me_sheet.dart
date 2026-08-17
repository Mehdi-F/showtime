import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../l10n/localization_context.dart';
import '../models/library_item.dart';
import '../providers/library_provider.dart';
import '../screens/movie_detail_screen.dart';
import '../screens/show_detail_screen.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'app_page_route.dart';

/// Random pick from the not-yet-completed part of the library — favorites
/// count twice in the pool so they surface more often without being the
/// only thing suggested.
List<LibraryItem> _weightedPool(List<LibraryItem> items) {
  final candidates = items.where((i) => i.status != 'completed').toList();
  return [
    ...candidates,
    ...candidates.where((i) => i.favorite),
  ];
}

void showSurpriseMeSheet(BuildContext context) {
  final items = context.read<LibraryProvider>().items;
  final pool = _weightedPool(items);
  if (pool.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('surprise.empty'))));
    return;
  }
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SurpriseSheet(pool: pool, tmdb: context.read<TmdbService>()),
  );
}

class _SurpriseSheet extends StatefulWidget {
  final List<LibraryItem> pool;
  final TmdbService tmdb;

  const _SurpriseSheet({required this.pool, required this.tmdb});

  @override
  State<_SurpriseSheet> createState() => _SurpriseSheetState();
}

class _SurpriseSheetState extends State<_SurpriseSheet> {
  late LibraryItem _pick;
  String? _title;
  String? _posterPath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _pick = _randomPick();
    _resolve();
  }

  LibraryItem _randomPick({LibraryItem? exclude}) {
    final candidates =
        exclude == null || widget.pool.length == 1 ? widget.pool : widget.pool.where((i) => i.docId != exclude.docId).toList();
    return candidates[Random().nextInt(candidates.length)];
  }

  Future<void> _resolve() async {
    setState(() => _loading = true);
    try {
      if (_pick.type == 'tv') {
        final details = await widget.tmdb.getTvDetails(_pick.tmdbId);
        if (!mounted) return;
        setState(() {
          _title = details.name;
          _posterPath = details.posterPath;
        });
      } else {
        final details = await widget.tmdb.getMovieDetails(_pick.tmdbId);
        if (!mounted) return;
        setState(() {
          _title = details.title;
          _posterPath = details.posterPath;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _title = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reroll() {
    setState(() => _pick = _randomPick(exclude: _pick));
    _resolve();
  }

  void _watch() {
    Navigator.of(context).pop();
    Navigator.of(context).push(appRoute(
      builder: (_) => _pick.type == 'tv'
          ? ShowDetailScreen(libraryItem: _pick)
          : MovieDetailScreen(libraryItem: _pick),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('surprise.title'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _posterPath != null
                          ? CachedNetworkImage(
                              imageUrl: '${TmdbConfig.imageBaseUrlLarge}$_posterPath',
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.surfaceVariant,
                              alignment: Alignment.center,
                              child: Icon(
                                _pick.type == 'tv' ? Icons.tv : Icons.movie,
                                color: AppColors.textSecondary,
                                size: 48,
                              ),
                            ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              _loading ? '' : (_title ?? context.tr('surprise.notFound')),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _watch,
                child: Text(context.tr('surprise.watch')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _loading ? null : _reroll,
                child: Text(context.tr('surprise.reroll')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
