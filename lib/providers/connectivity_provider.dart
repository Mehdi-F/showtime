import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Tracks the browser's online/offline state so the UI can tell the user
/// "you're offline, this might be stale/queued" instead of leaving toggles
/// and stats looking like they silently failed or are just slow to load.
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = html.window.navigator.onLine ?? true;
  StreamSubscription<html.Event>? _onlineSub;
  StreamSubscription<html.Event>? _offlineSub;

  bool get isOnline => _isOnline;

  ConnectivityProvider() {
    _onlineSub = html.window.onOnline.listen((_) {
      _isOnline = true;
      notifyListeners();
    });
    _offlineSub = html.window.onOffline.listen((_) {
      _isOnline = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    _offlineSub?.cancel();
    super.dispose();
  }
}
