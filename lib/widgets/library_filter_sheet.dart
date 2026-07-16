import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum LibrarySort { lastActivity, lastAdded, alphabetical }

const _sortLabels = {
  LibrarySort.lastActivity: 'Dernier visionnage',
  LibrarySort.lastAdded: 'Dernier ajout',
  LibrarySort.alphabetical: 'Ordre alphabétique',
};

class LibraryFilterResult<T> {
  final LibrarySort sort;
  final T filter;

  const LibraryFilterResult({required this.sort, required this.filter});
}

/// Shared "Trier par" + progress-status bottom sheet used by the Séries and
/// Films library screens — a single sort row plus a single-select list of
/// status filters (the specific statuses differ per screen and are passed in).
Future<LibraryFilterResult<T>?> showLibraryFilterSheet<T>(
  BuildContext context, {
  required LibrarySort initialSort,
  required String progressTitle,
  required List<T> filterValues,
  required String Function(T) filterLabel,
  required T initialFilter,
  required T defaultFilter,
}) {
  return showModalBottomSheet<LibraryFilterResult<T>>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => _LibraryFilterSheet<T>(
      initialSort: initialSort,
      progressTitle: progressTitle,
      filterValues: filterValues,
      filterLabel: filterLabel,
      initialFilter: initialFilter,
      defaultFilter: defaultFilter,
    ),
  );
}

class _LibraryFilterSheet<T> extends StatefulWidget {
  final LibrarySort initialSort;
  final String progressTitle;
  final List<T> filterValues;
  final String Function(T) filterLabel;
  final T initialFilter;
  final T defaultFilter;

  const _LibraryFilterSheet({
    required this.initialSort,
    required this.progressTitle,
    required this.filterValues,
    required this.filterLabel,
    required this.initialFilter,
    required this.defaultFilter,
  });

  @override
  State<_LibraryFilterSheet<T>> createState() => _LibraryFilterSheetState<T>();
}

class _LibraryFilterSheetState<T> extends State<_LibraryFilterSheet<T>> {
  late LibrarySort _sort = widget.initialSort;
  late T _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trier par', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final option in LibrarySort.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_sortLabels[option]!),
                        selected: _sort == option,
                        onSelected: (_) => setState(() => _sort = option),
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color: _sort == option ? Colors.black : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: AppColors.surfaceVariant,
                        side: BorderSide.none,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(widget.progressTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            for (final value in widget.filterValues)
              RadioListTile<T>(
                value: value,
                groupValue: _filter,
                onChanged: (v) => setState(() => _filter = v as T),
                title: Text(widget.filterLabel(value)),
                activeColor: AppColors.accent,
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _sort = LibrarySort.lastActivity;
                      _filter = widget.defaultFilter;
                    }),
                    child: const Text('RÉINITIALISER'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      LibraryFilterResult<T>(sort: _sort, filter: _filter),
                    ),
                    child: const Text('APPLIQUER'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating "FILTRES" pill, matching TV Time's layout — sits above the
/// scrollable content rather than occupying its own row, same convention as
/// [ViewModeToggle].
class LibraryFilterButton extends StatelessWidget {
  final VoidCallback onTap;

  const LibraryFilterButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, color: Colors.black, size: 18),
              SizedBox(width: 8),
              Text('FILTRES', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small active-filter indicator pill shown above the grid/list, matching the
/// "EN COURS"/"VU" badge in TV Time — tapping it also opens the filter sheet.
class LibraryFilterBadge extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const LibraryFilterBadge({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}
