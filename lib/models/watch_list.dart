class ListItemRef {
  final int tmdbId;
  final String type; // "tv" | "movie"

  ListItemRef({required this.tmdbId, required this.type});

  String get key => '${type}_$tmdbId';

  factory ListItemRef.fromMap(Map<String, dynamic> map) => ListItemRef(
        tmdbId: map['tmdbId'] as int,
        type: map['type'] as String,
      );

  Map<String, dynamic> toMap() => {'tmdbId': tmdbId, 'type': type};
}

class WatchList {
  final String id;
  final String name;
  final List<ListItemRef> items;
  final DateTime createdAt;

  WatchList({required this.id, required this.name, required this.items, required this.createdAt});

  bool containsItem(int tmdbId, String type) => items.any((i) => i.tmdbId == tmdbId && i.type == type);

  factory WatchList.fromMap(String id, Map<String, dynamic> map) => WatchList(
        id: id,
        name: map['name'] as String,
        items: (map['items'] as List<dynamic>? ?? [])
            .map((i) => ListItemRef.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'items': items.map((i) => i.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
