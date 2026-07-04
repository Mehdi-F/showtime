import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/tmdb_config.dart';
import '../models/library_item.dart';
import '../models/watch_list.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/lists_provider.dart';
import '../services/lists_service.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import 'show_detail_screen.dart';
import 'movie_detail_screen.dart';

class ListDetailScreen extends StatelessWidget {
  final String listId;

  const ListDetailScreen({super.key, required this.listId});

  Future<void> _rename(BuildContext context, WatchList list) async {
    final controller = TextEditingController(text: list.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Renommer la liste'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      final uid = context.read<AuthProvider>().user!.uid;
      await context.read<ListsService>().renameList(uid: uid, listId: list.id, name: name);
    }
  }

  Future<void> _delete(BuildContext context, WatchList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer la liste ?'),
        content: Text('"${list.name}" sera définitivement supprimée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final uid = context.read<AuthProvider>().user!.uid;
      await context.read<ListsService>().deleteList(uid: uid, listId: list.id);
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = context.watch<ListsProvider>().lists;
    WatchList? maybeList;
    for (final l in lists) {
      if (l.id == listId) maybeList = l;
    }

    if (maybeList == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final list = maybeList;

    final tmdb = context.read<TmdbService>();
    final libraryItems = context.watch<LibraryProvider>().items;
    final uid = context.read<AuthProvider>().user!.uid;
    final listsService = context.read<ListsService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Renommer',
            onPressed: () => _rename(context, list),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Supprimer',
            onPressed: () => _delete(context, list),
          ),
        ],
      ),
      body: list.items.isEmpty
          ? const Center(
              child: Text('Cette liste est vide.', style: TextStyle(color: AppColors.textSecondary)),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 12,
              ),
              itemCount: list.items.length,
              itemBuilder: (context, index) {
                final ref = list.items[index];
                LibraryItem? maybeLibraryItem;
                for (final i in libraryItems) {
                  if (i.tmdbId == ref.tmdbId && i.type == ref.type) maybeLibraryItem = i;
                }
                final libraryItem = maybeLibraryItem;

                return FutureBuilder<dynamic>(
                  future: ref.type == 'tv' ? tmdb.getTvDetails(ref.tmdbId) : tmdb.getMovieDetails(ref.tmdbId),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final title = data == null
                        ? null
                        : (ref.type == 'tv' ? data.name as String? : data.title as String?);
                    final posterPath = data?.posterPath as String?;

                    return GestureDetector(
                      onTap: libraryItem == null
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ref.type == 'tv'
                                    ? ShowDetailScreen(libraryItem: libraryItem)
                                    : MovieDetailScreen(libraryItem: libraryItem),
                              )),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: posterPath != null
                                      ? CachedNetworkImage(
                                          imageUrl: '${TmdbConfig.imageBaseUrl}$posterPath',
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: AppColors.surfaceVariant,
                                          child: const Icon(Icons.tv, color: AppColors.textSecondary),
                                        ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => listsService.removeItem(
                                      uid: uid,
                                      listId: list.id,
                                      tmdbId: ref.tmdbId,
                                      type: ref.type,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (title != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
