import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';

class TvTimeShow {
  final String name;
  final int nbEpisodesSeen;
  final bool favorited;

  TvTimeShow({required this.name, required this.nbEpisodesSeen, required this.favorited});
}

class TvTimeParseException implements Exception {
  final String message;
  TvTimeParseException(this.message);
  @override
  String toString() => message;
}

/// Parses a TV Time GDPR export zip into the list of currently-followed
/// shows with their aggregate watched-episode count and favorite flag.
/// TV Time doesn't track movies at all, so there's nothing to extract there.
List<TvTimeShow> parseTvTimeExport(Uint8List zipBytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } catch (_) {
    throw TvTimeParseException("Le fichier n'est pas une archive zip valide.");
  }

  ArchiveFile findFile(String name) {
    for (final f in archive.files) {
      if (f.isFile && f.name.split('/').last == name) return f;
    }
    throw TvTimeParseException('Fichier "$name" introuvable dans l\'archive.');
  }

  List<Map<String, String>> readCsv(String filename) {
    final file = findFile(filename);
    var content = utf8.decode(file.content as List<int>);
    if (content.startsWith('﻿')) content = content.substring(1);
    final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(content);
    if (rows.isEmpty) return [];
    final header = rows.first.map((h) => h.toString()).toList();
    return rows.skip(1).map((row) {
      final map = <String, String>{};
      for (var i = 0; i < header.length && i < row.length; i++) {
        map[header[i]] = row[i].toString();
      }
      return map;
    }).toList();
  }

  final followedRows = readCsv('followed_tv_show.csv');
  final userShowRows = readCsv('user_tv_show_data.csv');

  final dataByTvTimeId = <String, ({int nbEpisodesSeen, bool favorited})>{};
  for (final row in userShowRows) {
    final id = row['tv_show_id'];
    if (id == null) continue;
    dataByTvTimeId[id] = (
      nbEpisodesSeen: int.tryParse(row['nb_episodes_seen'] ?? '') ?? 0,
      favorited: row['is_favorited'] == '1',
    );
  }

  final shows = <TvTimeShow>[];
  for (final row in followedRows) {
    if (row['archived'] == '1') continue;
    final name = row['tv_show_name'];
    if (name == null || name.isEmpty) continue;
    final extra = dataByTvTimeId[row['tv_show_id']];
    shows.add(TvTimeShow(
      name: name,
      nbEpisodesSeen: extra?.nbEpisodesSeen ?? 0,
      favorited: extra?.favorited ?? false,
    ));
  }
  return shows;
}
