import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/library_item.dart';
import '../services/library_service.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryService _libraryService;
  StreamSubscription<List<LibraryItem>>? _subscription;
  List<LibraryItem> _items = [];
  String? _uid;
  bool _loaded = false;

  LibraryProvider(this._libraryService);

  List<LibraryItem> get items => _items;

  // False from app start until the Firestore stream's first snapshot lands.
  // Callers that need to know "is this really the user's whole library, or
  // just the empty placeholder before the stream connects" — e.g. filtering
  // already-followed titles out of a list once and freezing that — must
  // wait for this instead of treating an empty `items` as authoritative.
  bool get isLoaded => _loaded;

  void watch(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _loaded = false;
    _subscription?.cancel();
    _subscription = _libraryService.watchLibrary(uid).listen((items) {
      _items = items;
      _loaded = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
