// Glossaire de terminologie (docs/ARCHITECTURE.md §7.2, §7.6).

import 'package:drift/drift.dart';
import 'package:mh_binary/mh_binary.dart';

import 'tdb_database.dart';

/// Lecture et écriture des termes du glossaire d'une [locale].
final class GlossaryRepository {
  /// Voir les champs.
  GlossaryRepository(this.db, {required this.locale});

  /// Base de traduction.
  final TdbDatabase db;

  /// Locale cible.
  final String locale;

  /// Tous les termes, triés par terme source.
  Future<List<GlossaryTermRow>> all() => (db.select(db.glossaryTerms)
        ..where((t) => t.locale.equals(locale))
        ..orderBy([(t) => OrderingTerm.asc(t.sourceTerm)]))
      .get();

  /// Ajoute un terme et retourne son id. Lève [TdbError] si un terme est vide
  /// ou si [sourceTerm] existe déjà pour la locale.
  Future<int> add({
    required String sourceTerm,
    required String targetTerm,
    String? note,
    bool mandatory = false,
  }) async {
    _validate(sourceTerm, targetTerm);
    final dup = await (db.select(db.glossaryTerms)
          ..where(
            (t) => t.locale.equals(locale) & t.sourceTerm.equals(sourceTerm),
          ))
        .getSingleOrNull();
    if (dup != null) throw TdbError('glossary term already exists');
    return db.into(db.glossaryTerms).insert(
          GlossaryTermsCompanion.insert(
            locale: locale,
            sourceTerm: sourceTerm,
            targetTerm: targetTerm,
            note: Value(note),
            mandatory: Value(mandatory),
          ),
        );
  }

  /// Modifie la traduction, la note ou le caractère obligatoire d'un terme.
  /// Lève [TdbError] si l'id est inconnu ou le terme cible vide.
  Future<void> update(
    int id, {
    required String targetTerm,
    String? note,
    required bool mandatory,
  }) async {
    if (targetTerm.trim().isEmpty) throw const TdbError('empty glossary term');
    final n = await (db.update(db.glossaryTerms)
          ..where((t) => t.id.equals(id) & t.locale.equals(locale)))
        .write(
      GlossaryTermsCompanion(
        targetTerm: Value(targetTerm),
        note: Value(note),
        mandatory: Value(mandatory),
      ),
    );
    if (n == 0) throw TdbError('unknown glossary term $id');
  }

  /// Supprime un terme. Lève [TdbError] si l'id est inconnu.
  Future<void> delete(int id) async {
    final n = await (db.delete(db.glossaryTerms)
          ..where((t) => t.id.equals(id) & t.locale.equals(locale)))
        .go();
    if (n == 0) throw TdbError('unknown glossary term $id');
  }

  /// Termes dont le terme source figure dans [sourceText] (sensible à la
  /// casse), pour le panneau de l'éditeur.
  Future<List<GlossaryTermRow>> termsFoundIn(String sourceText) async => [
        for (final t in await all())
          if (sourceText.contains(t.sourceTerm)) t,
      ];

  void _validate(String source, String target) {
    if (source.trim().isEmpty || target.trim().isEmpty) {
      throw const TdbError('empty glossary term');
    }
  }
}
