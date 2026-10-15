// Mémoire de traduction (docs/ARCHITECTURE.md §7.6) : correspondances exactes
// puis approximatives, par similarité de trigrammes.
//
// FTS5 n'est pas garanti dans toutes les bibliothèques SQLite fournies avec
// l'application (winsqlite3.dll) : la similarité est calculée en Dart sur un
// index inversé trigramme → chaînes, construit en mémoire. La mesure est celle
// de `pg_trgm` : |A ∩ B| / |A ∪ B| sur les ensembles de trigrammes, chaque
// texte étant complété par deux espaces en tête et un en queue.

import 'package:drift/drift.dart';
import 'package:mh_binary/mh_binary.dart';

import 'tables/translations.dart';
import 'tdb_database.dart';

/// Ensemble des trigrammes de [text] (casse ignorée), codés en entiers de
/// 63 bits (3 points de code de 21 bits).
Set<int> trigrams(String text) {
  if (text.trim().isEmpty) return <int>{};
  final runes = [
    0x20,
    0x20,
    ...text.toLowerCase().runes,
    0x20,
  ];
  final out = <int>{};
  for (var i = 0; i + 2 < runes.length; i++) {
    out.add((runes[i] << 42) | (runes[i + 1] << 21) | runes[i + 2]);
  }
  return out;
}

/// Similarité de [a] et [b] entre 0 et 1 (1 : mêmes trigrammes).
double similarity(String a, String b) {
  final ta = trigrams(a);
  final tb = trigrams(b);
  var inter = 0;
  for (final t in ta) {
    if (tb.contains(t)) inter++;
  }
  final union = ta.length + tb.length - inter;
  return union == 0 ? 0 : inter / union;
}

/// Une correspondance de la mémoire.
final class TmMatch {
  /// Voir les champs.
  const TmMatch({
    required this.sourceId,
    required this.fileId,
    required this.tableIdx,
    required this.slotIdx,
    required this.sourceText,
    required this.targetText,
    required this.status,
    required this.score,
    required this.exact,
  });

  /// Chaîne source dont la traduction est proposée.
  final int sourceId;
  final int fileId;
  final int tableIdx;
  final int slotIdx;
  final String sourceText;

  /// Traduction existante à réutiliser.
  final String targetText;
  final String status;

  /// Similarité entre 0 et 1.
  final double score;

  /// Source identique (aux espaces de bord près).
  final bool exact;
}

class _Entry {
  _Entry(this.row, this.grams);

  final TmMatch row;
  final Set<int> grams;
}

/// Index de la mémoire de traduction d'une locale.
final class TranslationMemory {
  TranslationMemory._(this._entries) {
    for (var i = 0; i < _entries.length; i++) {
      for (final g in _entries[i].grams) {
        (_postings[g] ??= <int>[]).add(i);
      }
    }
  }

  final List<_Entry> _entries;
  final Map<int, List<int>> _postings = {};

  /// Nombre de couples source/traduction indexés.
  int get length => _entries.length;

  /// Construit l'index des traductions de [locale] de statut [minStatus] ou
  /// plus (`translated` par défaut : une ébauche n'est pas une référence),
  /// dont le texte n'est pas vide. Lève [TdbError] si [minStatus] est inconnu.
  static Future<TranslationMemory> load(
    TdbDatabase db, {
    required String locale,
    String minStatus = 'translated',
  }) async {
    final from = translationStatuses.indexOf(minStatus);
    if (from < 0) throw TdbError('unknown status "$minStatus"');
    final src = db.sourceStrings;
    final tr = db.translations;
    final rows = await (db.select(tr).join([
      innerJoin(src, src.id.equalsExp(tr.sourceId)),
    ])
          ..where(
            tr.locale.equals(locale) &
                tr.status.isIn(translationStatuses.sublist(from)) &
                tr.text_.equals('').not() &
                src.aliasOf.isNull(),
          ))
        .get();
    final entries = <_Entry>[];
    for (final r in rows) {
      final s = r.readTable(src);
      final t = r.readTable(tr);
      if (s.sourceText.trim().isEmpty) continue;
      entries.add(
        _Entry(
          TmMatch(
            sourceId: s.id,
            fileId: s.fileId,
            tableIdx: s.tableIdx,
            slotIdx: s.slotIdx,
            sourceText: s.sourceText,
            targetText: t.text_,
            status: t.status,
            score: 1,
            exact: false,
          ),
          trigrams(s.sourceText),
        ),
      );
    }
    return TranslationMemory._(entries);
  }

  /// Index à partir de couples déjà en mémoire (tests, mesures).
  factory TranslationMemory.fromPairs(
    Iterable<({int id, String source, String target})> pairs,
  ) =>
      TranslationMemory._([
        for (final p in pairs)
          if (p.source.trim().isNotEmpty)
            _Entry(
              TmMatch(
                sourceId: p.id,
                fileId: 0,
                tableIdx: 0,
                slotIdx: p.id,
                sourceText: p.source,
                targetText: p.target,
                status: 'translated',
                score: 1,
                exact: false,
              ),
              trigrams(p.source),
            ),
      ]);

  /// Correspondances pour [sourceText], meilleures d'abord (exactes en tête).
  ///
  /// [excludeSourceId] écarte la chaîne en cours d'édition. Seules les
  /// similarités >= [minScore] sont retournées, au plus [limit].
  List<TmMatch> suggest(
    String sourceText, {
    int? excludeSourceId,
    int limit = 5,
    double minScore = 0.5,
  }) {
    final query = sourceText.trim();
    if (query.isEmpty) return const [];
    final grams = trigrams(query);
    final shared = <int, int>{};
    for (final g in grams) {
      final list = _postings[g];
      if (list == null) continue;
      for (final i in list) {
        shared[i] = (shared[i] ?? 0) + 1;
      }
    }
    final out = <TmMatch>[];
    for (final e in shared.entries) {
      final entry = _entries[e.key];
      if (entry.row.sourceId == excludeSourceId) continue;
      final union = grams.length + entry.grams.length - e.value;
      final score = union == 0 ? 0.0 : e.value / union;
      final exact = entry.row.sourceText.trim() == query;
      if (!exact && score < minScore) continue;
      final r = entry.row;
      out.add(
        TmMatch(
          sourceId: r.sourceId,
          fileId: r.fileId,
          tableIdx: r.tableIdx,
          slotIdx: r.slotIdx,
          sourceText: r.sourceText,
          targetText: r.targetText,
          status: r.status,
          score: exact ? 1 : score,
          exact: exact,
        ),
      );
    }
    out.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return _rank(b.status).compareTo(_rank(a.status)); // relue > traduite
    });
    return out.length <= limit ? out : out.sublist(0, limit);
  }

  int _rank(String status) => translationStatuses.indexOf(status);
}
