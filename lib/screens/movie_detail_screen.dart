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
