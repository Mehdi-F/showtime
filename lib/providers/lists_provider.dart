import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/watch_list.dart';
import '../services/lists_service.dart';

class ListsProvider extends ChangeNotifier {
  final ListsService _listsService;
  StreamSubscription<List<WatchList>>? _subscription;
  List<WatchList> _lists = [];
  String? _uid;

  ListsProvider(this._listsService);

  List<WatchList> get lists => _lists;

  void watch(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _subscription?.cancel();
    _subscription = _listsService.watchLists(uid).listen((lists) {
      _lists = lists;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
