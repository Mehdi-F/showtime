import 'package:home_widget/home_widget.dart';
import '../models/library_item.dart';

const _androidWidgetName = 'LibraryStatsWidgetProvider';

/// Pushes at-a-glance library counts to the Android home screen widget.
/// Best-effort: a widget update failure shouldn't affect the app itself.
Future<void> updateLibraryWidget(List<LibraryItem> items) async {
  final seriesWatching = items.where((i) => i.type == 'tv' && i.status == 'watching').length;
  final moviesToWatch = items.where((i) => i.type == 'movie' && !i.watched).length;
  try {
    await HomeWidget.saveWidgetData<String>('seriesLine', '$seriesWatching série${seriesWatching > 1 ? "s" : ""} en cours');
    await HomeWidget.saveWidgetData<String>('moviesLine', '$moviesToWatch film${moviesToWatch > 1 ? "s" : ""} à voir');
    await HomeWidget.updateWidget(name: _androidWidgetName);
  } catch (_) {
    // No widget placed, or platform doesn't support it — nothing to do.
  }
}
