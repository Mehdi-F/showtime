import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_to_list_sheet.dart';
import '../widgets/media_info_sections.dart';

class MovieDetailScreen extends StatefulWidget {
  final LibraryItem libraryItem;

  const MovieDetailScreen({super.key, required this.libraryItem});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _watched = false;
  late bool _favorite;

  @override
  void initState() {
    super.initState();
    _watched = widget.libraryItem.watched;
    _favorite = widget.libraryItem.favorite;
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

  Future<void> _toggleFavorite() async {
    final uid = context.read<AuthProvider>().user!.uid;
    final newValue = !_favorite;
    setState(() => _favorite = newValue);
    await context.read<LibraryService>().toggleFavorite(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          type: 'movie',
          favorite: newValue,
        );
  }

  Future<void> _unfollow() async {
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<LibraryService>().removeFromLibrary(
          uid: uid,
          tmdbId: widget.libraryItem.tmdbId,
          type: 'movie',
        );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _openSimilar(SimilarMedia media) async {
    final matches = context
        .read<LibraryProvider>()
        .items
        .where((i) => i.tmdbId == media.id && i.type == media.type);
    LibraryItem item;
    if (matches.isNotEmpty) {
      item = matches.first;
    } else {
      final uid = context.read<AuthProvider>().user!.uid;
      item = await context.read<LibraryService>().addToLibrary(
            uid: uid,
            tmdbId: media.id,
            type: media.type,
          );
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MovieDetailScreen(libraryItem: item),
    ));
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: context.read<TmdbService>().getMovieDetails(widget.libraryItem.tmdbId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final movie = snapshot.data!;
        final tmdb = context.read<TmdbService>();
        return Scaffold(
          body: ListView(
            children: [
              SizedBox(
                height: 320,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (movie.posterPath != null)
                      CachedNetworkImage(
                        imageUrl: '${TmdbConfig.imageBaseUrl}${movie.posterPath}',
                        fit: BoxFit.cover,
                      )
                    else
                      Container(color: AppColors.surfaceVariant),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.9),
                          ],
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
                                IconButton(
                                  icon: Icon(
                                    _favorite ? Icons.favorite : Icons.favorite_border,
                                    color: _favorite ? Colors.redAccent : Colors.white,
                                  ),
                                  onPressed: _toggleFavorite,
                                ),
                                PopupMenuButton<void>(
                                  icon: const Icon(Icons.more_vert, color: Colors.white),
                                  color: AppColors.surface,
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      onTap: () => showAddToListSheet(
                                        context,
                                        tmdbId: widget.libraryItem.tmdbId,
                                        type: 'movie',
                                      ),
                                      child: const Text('Ajouter à une liste'),
                                    ),
                                    PopupMenuItem(
                                      onTap: _unfollow,
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
                      child: Text(
                        movie.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: FilledButton.icon(
                  onPressed: _toggleWatched,
                  icon: Icon(_watched ? Icons.check_circle : Icons.check_circle_outline),
                  label: Text(_watched ? 'Watched' : 'Mark watched'),
                ),
              ),
              InfoCard(
                yearRange: movie.releaseDate?.year.toString(),
                genres: movie.genres,
                voteAverage: movie.voteAverage,
                overview: movie.overview,
                runtimeMinutes: movie.runtime,
                addedCaption: 'Ajouté à votre bibliothèque le ${_formatDate(widget.libraryItem.addedAt)}',
              ),
              CastRow(future: tmdb.getMovieCredits(widget.libraryItem.tmdbId)),
              SimilarRow(
                title: 'Les utilisateurs ont également regardé',
                future: tmdb.getSimilarMovies(widget.libraryItem.tmdbId),
                onTap: _openSimilar,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
