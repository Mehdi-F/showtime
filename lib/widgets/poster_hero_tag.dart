/// Shared tag format for poster Hero transitions between a library/grid tile
/// and the show/movie detail screen's banner — kept in one place so every
/// source tile and both detail screens agree on the exact same string.
String posterHeroTag(String type, int tmdbId) => 'poster-$type-$tmdbId';
