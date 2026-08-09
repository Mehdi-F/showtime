import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

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
