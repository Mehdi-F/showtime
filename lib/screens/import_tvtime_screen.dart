import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tmdb_config.dart';
import '../models/tmdb_models.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../services/library_service.dart';
import '../services/tmdb_service.dart';
import '../services/tvtime_import_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';

enum _Stage { pickFile, matching, review, importing, done }

class _MatchRow {
  final TvTimeShow show;
  TmdbSearchResult? match;
  bool selected;
  final bool alreadyInLibrary;

  _MatchRow({required this.show, this.match, required this.selected, required this.alreadyInLibrary});
}

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

class ImportTvTimeScreen extends StatefulWidget {
  const ImportTvTimeScreen({super.key});

  @override
  State<ImportTvTimeScreen> createState() => _ImportTvTimeScreenState();
}

class _ImportTvTimeScreenState extends State<ImportTvTimeScreen> {
  _Stage _stage = _Stage.pickFile;
  String? _error;

  List<_MatchRow> _rows = [];
  int _progress = 0;
  int _total = 0;

  int _importedCount = 0;
  int _failedCount = 0;

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    List<TvTimeShow> shows;
    try {
      shows = parseTvTimeExport(result.files.single.bytes!);
    } catch (e) {
      setState(() => _error = e.toString());
      return;
    }
    if (!mounted) return;
    _startMatching(shows);
  }

  Future<void> _startMatching(List<TvTimeShow> shows) async {
    final tmdb = context.read<TmdbService>();
    final existingIds = context.read<LibraryProvider>().items.where((i) => i.type == 'tv').map((i) => i.tmdbId).toSet();

    setState(() {
      _stage = _Stage.matching;
      _progress = 0;
      _total = shows.length;
    });

    final rows = List<_MatchRow?>.filled(shows.length, null);
    await _forEachBounded(List.generate(shows.length, (i) => i), 4, (i) async {
      final show = shows[i];
      TmdbSearchResult? match;
      try {
        final results = await tmdb.search(show.name);
        final tvResults = results.where((r) => r.mediaType == 'tv').toList();
        if (tvResults.isNotEmpty) match = tvResults.first;
      } catch (_) {
        // leave match null; user can search manually in the review step
      }
      final alreadyInLibrary = match != null && existingIds.contains(match.id);
      rows[i] = _MatchRow(show: show, match: match, selected: match != null && !alreadyInLibrary, alreadyInLibrary: alreadyInLibrary);
      if (mounted) setState(() => _progress++);
    });

    if (!mounted) return;
    setState(() {
      _rows = rows.cast<_MatchRow>();
      _stage = _Stage.review;
    });
  }

  Future<void> _changeMatch(_MatchRow row) async {
    final tmdb = context.read<TmdbService>();
    final picked = await showDialog<TmdbSearchResult>(
      context: context,
      builder: (_) => _ChangeMatchDialog(initialQuery: row.show.name, tmdb: tmdb),
    );
    if (picked != null) {
      setState(() {
        row.match = picked;
        row.selected = true;
      });
    }
  }

  Future<void> _runImport() async {
    final uid = context.read<AuthProvider>().user!.uid;
    final tmdb = context.read<TmdbService>();
    final library = context.read<LibraryService>();
    final toImport = _rows.where((r) => r.selected && r.match != null).toList();
    final usedTmdbIds = <int>{};

    setState(() {
      _stage = _Stage.importing;
      _progress = 0;
      _total = toImport.length;
      _importedCount = 0;
      _failedCount = 0;
    });

    await _forEachBounded(toImport, 3, (row) async {
      try {
        final match = row.match!;
        if (!usedTmdbIds.add(match.id)) {
          // Another row in this batch already claimed this TMDB show — skip to avoid overwriting it.
          if (mounted) setState(() => _progress++);
          return;
        }
        var watchedEpisodes = <String, bool>{};
        if (row.show.nbEpisodesSeen > 0) {
          final details = await tmdb.getTvDetails(match.id);
          final seasonNumbers = details.seasons.map((s) => s.seasonNumber).where((n) => n >= 1).toList()..sort();
          final flatEpisodes = <EpisodeRef>[];
          for (final seasonNumber in seasonNumbers) {
            final season = await tmdb.getSeasonDetails(match.id, seasonNumber);
            flatEpisodes.addAll(season.episodes);
          }
          final count = row.show.nbEpisodesSeen < flatEpisodes.length ? row.show.nbEpisodesSeen : flatEpisodes.length;
          watchedEpisodes = {for (final ep in flatEpisodes.take(count)) ep.key: true};
        }
        await library.importTvShow(
          uid: uid,
          tmdbId: match.id,
          watchedEpisodes: watchedEpisodes,
          favorite: row.show.favorited,
        );
        _importedCount++;
      } catch (_) {
        _failedCount++;
      }
      if (mounted) setState(() => _progress++);
    });

    if (!mounted) return;
    setState(() => _stage = _Stage.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Importer depuis TV Time')),
      body: switch (_stage) {
        _Stage.pickFile => _buildPickFile(),
        _Stage.matching => _buildProgress('Recherche des séries sur TMDB…'),
        _Stage.review => _buildReview(),
        _Stage.importing => _buildProgress('Import en cours… reste sur cet écran.'),
        _Stage.done => _buildDone(),
      },
    );
  }

  Widget _buildPickFile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              "Sélectionne le fichier zip de ton export RGPD TV Time. On importe les séries suivies, "
              "le statut favori, et on marque comme vus les premiers épisodes (dans l'ordre) à hauteur du "
              "nombre d'épisodes vus rapporté par TV Time — TV Time ne fournit pas la liste exacte des "
              "épisodes vus, ni les films.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choisir le fichier zip'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(String label) {
    final progress = _total == 0 ? 0.0 : _progress / _total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('$_progress / $_total', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildReview() {
    final alreadyCount = _rows.where((r) => r.alreadyInLibrary).length;
    final notFoundCount = _rows.where((r) => r.match == null).length;
    final selectedCount = _rows.where((r) => r.selected && r.match != null).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$alreadyCount déjà dans ta bibliothèque (ignorées) · $notFoundCount sans correspondance TMDB',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];
              if (row.alreadyInLibrary) return const SizedBox.shrink();
              final match = row.match;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  children: [
                    Checkbox(
                      value: row.selected && match != null,
                      onChanged: match == null ? null : (v) => setState(() => row.selected = v ?? false),
                    ),
                    SizedBox(
                      width: 40,
                      height: 56,
                      child: match?.posterPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: '${TmdbConfig.imageBaseUrl}${match!.posterPath}',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              color: AppColors.surfaceVariant,
                              child: const Icon(Icons.tv, color: AppColors.textSecondary, size: 18),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            match != null
                                ? '${match.title}${match.year != null ? ' (${match.year})' : ''}'
                                : 'Aucune correspondance',
                            style: TextStyle(color: match != null ? AppColors.textPrimary : Colors.redAccent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'TV Time : ${row.show.name} · ${row.show.nbEpisodesSeen} épisode(s) vu(s)',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _changeMatch(row),
                      child: const Text('Changer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: selectedCount == 0 ? null : _runImport,
              child: Text('Importer $selectedCount série(s)'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            Text('$_importedCount série(s) importée(s).', textAlign: TextAlign.center),
            if (_failedCount > 0) ...[
              const SizedBox(height: 8),
              Text('$_failedCount échec(s) (réessaie plus tard).',
                  style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Terminé'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeMatchDialog extends StatefulWidget {
  final String initialQuery;
  final TmdbService tmdb;

  const _ChangeMatchDialog({required this.initialQuery, required this.tmdb});

  @override
  State<_ChangeMatchDialog> createState() => _ChangeMatchDialogState();
}

class _ChangeMatchDialogState extends State<_ChangeMatchDialog> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  List<TmdbSearchResult>? _results;
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    final results = await widget.tmdb.search(_controller.text.trim());
    if (!mounted) return;
    setState(() {
      _results = results.where((r) => r.mediaType == 'tv').toList();
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 400,
          height: 480,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Nom de la série'),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.search), onPressed: _search),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const MediaListSkeleton(itemCount: 4)
                    : ListView.builder(
                        itemCount: _results?.length ?? 0,
                        itemBuilder: (context, index) {
                          final r = _results![index];
                          return ListTile(
                            leading: SizedBox(
                              width: 36,
                              height: 50,
                              child: r.posterPath != null
                                  ? CachedNetworkImage(
                                      imageUrl: '${TmdbConfig.imageBaseUrl}${r.posterPath}', fit: BoxFit.cover)
                                  : Container(color: AppColors.surfaceVariant),
                            ),
                            title: Text(r.title),
                            subtitle: r.year != null ? Text(r.year!) : null,
                            onTap: () => Navigator.of(context).pop(r),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
