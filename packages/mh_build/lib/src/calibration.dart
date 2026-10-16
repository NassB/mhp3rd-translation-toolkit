// Chaînes de calibrage (docs/PROGRESS.md T36, ARCHITECTURE.md §8.4).
//
// Pour mesurer ce que le jeu affiche réellement (largeur des caractères,
// retours à la ligne, débordement des boîtes), on remplace les chaînes d'un
// petit fichier par des chaînes **de test synthétiques** : chacune porte son
// étiquette `[table.slot]` (on sait donc de quelle chaîne il s'agit à
// l'écran) suivie d'un motif de mesure.
//
// Garanties, par construction :
// - la chaîne de test n'est **jamais plus longue en octets** que la source :
//   le fichier reconstruit ne dépasse donc pas l'original (budget `strict`) ;
// - les sauts de ligne, les codes `~Xnn` et les marqueurs de format `%d`/`%s`
//   de la source sont conservés **tels quels et à leur place** : la mise en
//   page et le comportement du jeu restent ceux de la chaîne d'origine ;
// - une chaîne trop courte pour porter son étiquette est laissée telle quelle.
//
// Aucun texte du jeu n'est produit : seulement de l'ASCII et des lettres
// accentuées latines.

import 'dart:convert';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_tdb/mh_tdb.dart';

/// Un motif de mesure.
final class CalibrationPattern {
  /// Voir les champs.
  const CalibrationPattern(this.name, this.description, this.unit);

  /// Nom court (rapport).
  final String name;

  /// Ce qu'il permet de mesurer.
  final String description;

  /// Caractères répétés pour remplir (`ruler` est traité à part).
  final String unit;
}

/// Motifs, attribués aux slots de façon cyclique (`slot % motifs.length`).
const List<CalibrationPattern> calibrationPatterns = [
  CalibrationPattern(
    'ruler',
    'règle : chiffres, une lettre a, b, c… tous les 10 caractères '
        '(compter les caractères visibles)',
    '',
  ),
  CalibrationPattern('narrow', 'caractère étroit (i)', 'i'),
  CalibrationPattern('wide', 'caractère large (W)', 'W'),
  CalibrationPattern('wide-m', 'caractère large (M)', 'M'),
  CalibrationPattern(
    'alpha',
    'alphabet, minuscules et majuscules',
    'abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ ',
  ),
  CalibrationPattern('accents', 'lettres accentuées', 'éèêëàâùûôîïçÉÈÀÇ'),
  CalibrationPattern('punct', 'ponctuation', '.,;:!?\'"«»()-/% '),
  CalibrationPattern('spaced', 'espaces entre les mots', 'ab cd ef gh '),
];

/// Motif attribué au slot [slotIdx].
CalibrationPattern calibrationPatternFor(int slotIdx) =>
    calibrationPatterns[slotIdx % calibrationPatterns.length];

/// Étiquette d'une chaîne de test.
String calibrationTag(int tableIdx, int slotIdx) => '[$tableIdx.$slotIdx]';

/// Éléments de la source à garder : codes `~Xnn`, marqueurs `%d`/`%s`…,
/// sauts de ligne.
final RegExp _keep = RegExp(
  r'~[A-Za-z][0-9A-Za-z]{2}|%[-+ 0#]*[0-9]*(?:\.[0-9]+)?[sdixXcfu]|\n',
);

int _bytes(String s) => utf8.encode(s).length;

/// Remplit au plus [budget] octets avec le motif [p] (en partant de
/// l'indice [start] du flux), sans couper un caractère.
String _fill(CalibrationPattern p, int budget, int start) {
  final b = StringBuffer();
  var used = 0;
  var i = start;
  while (true) {
    final String ch;
    if (p.name == 'ruler') {
      // Position i : le dernier caractère de chaque dizaine est une lettre.
      ch = i % 10 == 9
          ? String.fromCharCode(0x61 + (i ~/ 10) % 26)
          : '${i % 10}';
    } else {
      final runes = p.unit.runes.toList();
      ch = String.fromCharCode(runes[i % runes.length]);
    }
    final n = _bytes(ch);
    if (used + n > budget) break;
    b.write(ch);
    used += n;
    i++;
  }
  return b.toString();
}

/// Chaîne de test pour la chaîne source [source] du slot [tableIdx].[slotIdx].
///
/// Retourne [source] inchangée si aucune portion de texte n'est assez longue
/// pour porter l'étiquette. Le résultat ne dépasse jamais [source] en octets.
String calibrationText(
  String source, {
  required int tableIdx,
  required int slotIdx,
}) {
  final tag = calibrationTag(tableIdx, slotIdx);
  final pattern = calibrationPatternFor(slotIdx);

  // Portions de texte entre les éléments conservés.
  final out = StringBuffer();
  var last = 0;
  var tagged = false;
  var stream = 0;

  void text(String piece) {
    if (piece.isEmpty) return;
    var budget = _bytes(piece);
    if (piece.trim().isEmpty) {
      out.write(piece); // espaces seuls : conservés
      return;
    }
    if (!tagged && budget >= _bytes(tag)) {
      out.write(tag);
      budget -= _bytes(tag);
      tagged = true;
    }
    final fill = _fill(pattern, budget, stream);
    stream += fill.runes.length;
    out.write(fill);
  }

  for (final m in _keep.allMatches(source)) {
    text(source.substring(last, m.start));
    out.write(m.group(0));
    last = m.end;
  }
  text(source.substring(last));
  return tagged ? out.toString() : source;
}

/// Auteur des traductions de calibrage dans la base.
const String calibrationAuthor = 'calibration';

/// Une chaîne remplacée par sa version de test.
final class CalibrationRow {
  /// Voir les champs.
  const CalibrationRow({
    required this.tableIdx,
    required this.slotIdx,
    required this.pattern,
    required this.sourceBytes,
    required this.bytes,
    required this.newlines,
  });

  final int tableIdx;
  final int slotIdx;

  /// Nom du motif (`calibrationPatterns`).
  final String pattern;
  final int sourceBytes;
  final int bytes;

  /// Nombre de sauts de ligne (identique à la source).
  final int newlines;
}

/// Résultat de [applyCalibration].
final class CalibrationReport {
  /// Voir les champs.
  const CalibrationReport({
    required this.fileId,
    required this.rows,
    required this.untouched,
  });

  final int fileId;
  final List<CalibrationRow> rows;

  /// Chaînes laissées telles quelles (trop courtes, sans japonais, alias).
  final int untouched;

  /// Écart d'octets total (toujours <= 0).
  int get deltaBytes => rows.fold(0, (sum, r) => sum + r.bytes - r.sourceBytes);
}

final RegExp _japanese = RegExp(r'[぀-ヿ㐀-鿿]');

/// Remplace les chaînes japonaises du fichier [fileId] par leurs chaînes de
/// test, en `translated` (auteur [calibrationAuthor]).
///
/// Refuse (`TdbError`) si le fichier contient déjà une traduction qui n'est
/// pas de calibrage, sauf avec [force] : un vrai travail de traduction ne doit
/// pas être écrasé par erreur. Relancer l'outil est sans danger (les lignes de
/// calibrage sont simplement réécrites).
Future<CalibrationReport> applyCalibration({
  required TranslationRepository repo,
  required int fileId,
  bool force = false,
}) async {
  final slots = await repo.slots(fileId, limit: await repo.countSlots(fileId));
  if (!force) {
    for (final s in slots) {
      final t = s.translation;
      if (t != null && t.authorId != calibrationAuthor) {
        throw TdbError(
          'file already has translations that are not calibration text: '
          'use a separate project, or --force to overwrite them',
          fileId: fileId,
        );
      }
    }
  }
  final rows = <CalibrationRow>[];
  var untouched = 0;
  for (final s in slots) {
    if (s.isAlias || !_japanese.hasMatch(s.sourceText)) {
      untouched++;
      continue;
    }
    final text = calibrationText(
      s.sourceText,
      tableIdx: s.tableIdx,
      slotIdx: s.slotIdx,
    );
    if (text == s.sourceText) {
      untouched++;
      continue;
    }
    final res = await repo.saveTranslation(
      sourceId: s.sourceId,
      text: text,
      status: 'translated',
      expectedRevision: s.translation?.revision,
      authorId: calibrationAuthor,
    );
    if (res is! SaveOk) {
      throw TdbError('concurrent change while calibrating', fileId: fileId);
    }
    rows.add(
      CalibrationRow(
        tableIdx: s.tableIdx,
        slotIdx: s.slotIdx,
        pattern: calibrationPatternFor(s.slotIdx).name,
        sourceBytes: _bytes(s.sourceText),
        bytes: _bytes(text),
        newlines: '\n'.allMatches(text).length,
      ),
    );
  }
  return CalibrationReport(fileId: fileId, rows: rows, untouched: untouched);
}

/// Rapport Markdown à garder à côté de l'ISO de calibrage : légende des
/// motifs, puis une ligne par chaîne remplacée. Aucun texte du jeu.
String calibrationMarkdown(CalibrationReport r) {
  final b = StringBuffer()
    ..writeln('# Calibrage — fichier #${r.fileId}')
    ..writeln()
    ..writeln(
      'Chaque chaîne du fichier porte une étiquette `[table.slot]` suivie '
      'd\'un motif. Dans le jeu, repère l\'étiquette à l\'écran, puis note '
      'combien de caractères sont visibles, où le texte est coupé ou '
      'renvoyé à la ligne, et s\'il déborde de la boîte.',
    )
    ..writeln()
    ..writeln('## Motifs')
    ..writeln();
  for (var i = 0; i < calibrationPatterns.length; i++) {
    final p = calibrationPatterns[i];
    b.writeln('- slot ≡ $i (mod ${calibrationPatterns.length}) : '
        '**${p.name}** — ${p.description}');
  }
  b
    ..writeln()
    ..writeln(
      '## Chaînes (${r.rows.length} remplacées, ${r.untouched} laissées '
      'telles quelles ; écart total ${r.deltaBytes} octets)',
    )
    ..writeln()
    ..writeln(
      '| étiquette | motif | octets source | octets test | sauts de ligne |',
    )
    ..writeln('|---|---|---|---|---|');
  for (final row in r.rows) {
    b.writeln(
      '| ${calibrationTag(row.tableIdx, row.slotIdx)} | ${row.pattern} | '
      '${row.sourceBytes} | ${row.bytes} | ${row.newlines} |',
    );
  }
  return b.toString();
}
