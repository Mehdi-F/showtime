class TmdbSearchResult {
  final int id;
  final String mediaType; // "tv" | "movie"
  final String title;
  final String? posterPath;
  final String? year;

  TmdbSearchResult({
    required this.id,
    required this.mediaType,
    required this.title,
    required this.posterPath,
    required this.year,
  });

  factory TmdbSearchResult.fromJson(Map<String, dynamic> json) {
    final mediaType = json['media_type'] as String;
    final title = mediaType == 'tv' ? json['name'] as String : json['title'] as String;
    final dateField = mediaType == 'tv' ? json['first_air_date'] : json['release_date'];
    final date = dateField as String?;

    return TmdbSearchResult(
      id: json['id'] as int,
      mediaType: mediaType,
      title: title,
      posterPath: json['poster_path'] as String?,
      year: (date != null && date.length >= 4) ? date.substring(0, 4) : null,
    );
  }
}
