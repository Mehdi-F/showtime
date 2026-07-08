import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/watch_list.dart';
import '../providers/auth_provider.dart';
import '../providers/lists_provider.dart';
import '../services/lists_service.dart';
import '../theme/app_theme.dart';

Future<void> showAddToListSheet(
  BuildContext context, {
  required int tmdbId,
  required String type,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => AddToListSheet(tmdbId: tmdbId, type: type),
  );
}

class AddToListSheet extends StatefulWidget {
  final int tmdbId;
  final String type;

  const AddToListSheet({super.key, required this.tmdbId, required this.type});

  @override
  State<AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<AddToListSheet> {
  final _controller = TextEditingController();
  bool _creating = false;
  // list.containsItem() reflects Firestore's live data, so the checkbox
  // otherwise sat unmoved until the write round-tripped back through
  // ListsProvider's stream — the same lag already fixed elsewhere for
  // watched/favorite toggles. Overrides here give instant feedback; a
  // failed write just falls back to the (unchanged) real value.
  final Map<String, bool> _pendingOverrides = {};

  Future<void> _toggleItem(WatchList list, bool checked) async {
    setState(() => _pendingOverrides[list.id] = checked);
    final uid = context.read<AuthProvider>().user!.uid;
    final listsService = context.read<ListsService>();
    try {
      if (checked) {
        await listsService.addItem(uid: uid, listId: list.id, tmdbId: widget.tmdbId, type: widget.type);
      } else {
        await listsService.removeItem(uid: uid, listId: list.id, tmdbId: widget.tmdbId, type: widget.type);
      }
    } finally {
      if (mounted) setState(() => _pendingOverrides.remove(list.id));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createAndAdd() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final uid = context.read<AuthProvider>().user!.uid;
    final listsService = context.read<ListsService>();
    setState(() => _creating = true);
    final listId = await listsService.createList(uid: uid, name: name);
    await listsService.addItem(uid: uid, listId: listId, tmdbId: widget.tmdbId, type: widget.type);
    if (mounted) {
      setState(() => _creating = false);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = context.watch<ListsProvider>().lists;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ajouter à une liste',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            if (lists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune liste pour le moment.',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    final checked =
                        _pendingOverrides[list.id] ?? list.containsItem(widget.tmdbId, widget.type);
                    return CheckboxListTile(
                      value: checked,
                      title: Text(list.name),
                      subtitle: Text('${list.items.length} élément(s)',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) => _toggleItem(list, value ?? false),
                    );
                  },
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Nouvelle liste...'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _creating ? null : _createAndAdd,
                  child: const Text('Créer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
