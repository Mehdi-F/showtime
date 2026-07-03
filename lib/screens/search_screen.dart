import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../services/tmdb_service.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/media_list_tile.dart';

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
  final Set<String> _added = {};

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
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Search shows or movies',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
          ),
          onSubmitted: _runSearch,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    final key = '${result.mediaType}_${result.id}';
                    final added = _added.contains(key);
                    return MediaListTile(
                      posterPath: result.posterPath,
                      title: result.year != null ? '${result.title} (${result.year})' : result.title,
                      subtitle: result.mediaType == 'tv' ? 'Series' : 'Film',
                      trailing: IconButton(
                        icon: Icon(
                          added ? Icons.check_circle : Icons.add_circle_outline,
                          color: added ? Colors.greenAccent : AppColors.accent,
                        ),
                        onPressed: added
                            ? null
                            : () async {
                                await context.read<LibraryService>().addToLibrary(
                                      uid: uid,
                                      tmdbId: result.id,
                                      type: result.mediaType,
                                    );
                                setState(() => _added.add(key));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Added ${result.title}')));
                                }
                              },
                      ),
                    );
                  },
                ),
    );
  }
}
