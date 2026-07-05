import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/library_item.dart';
import '../services/library_service.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryService _libraryService;
  StreamSubscription<List<LibraryItem>>? _subscription;
  List<LibraryItem> _items = [];
  String? _uid;

  LibraryProvider(this._libraryService);

  List<LibraryItem> get items => _items;

  void watch(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _subscription?.cancel();
    _subscription = _libraryService.watchLibrary(uid).listen((items) {
      _items = items;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
