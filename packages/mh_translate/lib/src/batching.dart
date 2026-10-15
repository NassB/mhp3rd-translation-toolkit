// Lots de chaînes à pré-traduire (docs/DECISIONS/0006-pretraduction-ia.md).
//
// Le contexte chargé de LM Studio mesuré est de 16 384 jetons (2026-10-15) :
// un lot doit laisser de la place à la consigne, au glossaire et à la
// réponse. L'estimation ci-dessous est volontairement prudente ; elle se
// corrige avec `usage.prompt_tokens` mesuré (paramètre [tokensPerEstimate]).

/// Une chaîne à traduire.
final class TranslationUnit {
  /// Voir les champs.
  const TranslationUnit({
    required this.id,
    required this.source,
    required this.maxBytes,
  });

  /// Identifiant stable (par exemple l'id `source_string`), repris dans la
  /// réponse du modèle.
  final int id;

  /// Texte source (UTF-8, `\n` réels).
  final String source;

  /// Longueur maximale de la traduction en octets UTF-8.
  final int maxBytes;
}

/// Estimation prudente du nombre de jetons de [text].
///
/// Les caractères japonais (kana, kanji, ponctuation CJK, pleine largeur) sont
/// comptés à 1 jeton, les autres à 0,35. Une estimation, jamais une mesure.
int estimateTokens(String text) {
  var cjk = 0;
  var other = 0;
  for (final r in text.runes) {
    final isCjk =
        (r >= 0x3000 && r <= 0x30FF) || // ponctuation, hiragana, katakana
            (r >= 0x3400 && r <= 0x9FFF) || // idéogrammes
            (r >= 0xFF00 && r <= 0xFFEF); // pleine largeur
    if (isCjk) {
      cjk++;
    } else {
      other++;
    }
  }
  return cjk + (other * 0.35).ceil();
}

/// Un lot : des chaînes envoyées ensemble.
final class Batch {
  /// Voir les champs.
  Batch(List<TranslationUnit> units, this.estimatedTokens)
      : units = List.unmodifiable(units);

  final List<TranslationUnit> units;

  /// Estimation des jetons de la partie variable du prompt (sources).
  final int estimatedTokens;
}

/// Découpe [units] en lots **dans l'ordre**, sans en perdre.
///
/// Un lot s'arrête quand [maxUnits] chaînes ou [maxBatchTokens] jetons
/// estimés seraient dépassés (par chaîne : texte + [perUnitOverhead] pour
/// l'identifiant et la limite). Une chaîne seule dépassant le plafond forme
/// son propre lot. [tokensPerEstimate] corrige l'estimation d'après des
/// mesures réelles (`usage.prompt_tokens`).
List<Batch> buildBatches(
  Iterable<TranslationUnit> units, {
  int maxUnits = 40,
  int maxBatchTokens = 3000,
  int perUnitOverhead = 12,
  double tokensPerEstimate = 1.0,
}) {
  if (maxUnits < 1) throw ArgumentError.value(maxUnits, 'maxUnits');
  if (maxBatchTokens < 1) {
    throw ArgumentError.value(maxBatchTokens, 'maxBatchTokens');
  }
  final out = <Batch>[];
  var current = <TranslationUnit>[];
  var tokens = 0;
  void flush() {
    if (current.isEmpty) return;
    out.add(Batch(current, tokens));
    current = <TranslationUnit>[];
    tokens = 0;
  }

  for (final u in units) {
    final cost =
        ((estimateTokens(u.source) + perUnitOverhead) * tokensPerEstimate)
            .ceil();
    if (current.isNotEmpty &&
        (current.length >= maxUnits || tokens + cost > maxBatchTokens)) {
      flush();
    }
    current.add(u);
    tokens += cost;
  }
  flush();
  return out;
}
