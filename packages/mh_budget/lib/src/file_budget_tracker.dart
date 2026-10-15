// Mesure incrémentale de la taille reconstruite d'un fichier (ARCHITECTURE.md
// §8.3 : « modifier une chaîne met à jour la somme en O(1) »).

import 'dart:convert';
import 'dart:typed_data';

import 'package:mh_binary/mh_binary.dart';
import 'package:mh_formats/mh_formats.dart';

import 'file_budget.dart';

/// Taille reconstruite d'un `string_table_a` suivie chaîne par chaîne.
///
/// Invariant : [rebuiltBytes] égale `measureStringTableA(f)` pour le modèle
/// `f` dont les slots portent les textes courants (donc `encode(f).length`).
/// La taille inclut `endData` (voir `mh_build` : tables + endData, zéros de
/// remplissage exclus).
final class FileBudgetTracker {
  /// Démarre avec les textes de [file] ; [fileId] sert aux messages d'erreur.
  FileBudgetTracker(StringTableFile file, {this.fileId})
      : _aliases = [
          for (final t in file.tables)
            t == null ? null : [for (final s in t.slots) s.aliasOf != null],
        ],
        _lengths = [
          for (final t in file.tables)
            t == null ? null : [for (final s in t.slots) s.raw.length],
        ],
        _rebuilt = measureStringTableA(file, fileId: fileId);

  /// ID DATA.BIN, pour les messages.
  final int? fileId;

  final List<List<bool>?> _aliases;
  final List<List<int>?> _lengths;
  int _rebuilt;

  /// Taille reconstruite courante, en octets.
  int get rebuiltBytes => _rebuilt;

  /// Longueur courante en octets de la chaîne ([table], [slot]).
  int lengthOf(int table, int slot) {
    _check(table, slot);
    return _lengths[table]![slot];
  }

  /// Remplace la chaîne ([table], [slot]) par [raw] (UTF-8, sans `\0`) et
  /// retourne la nouvelle taille reconstruite.
  ///
  /// Lève [FormatError] si la table est nulle, le slot hors bornes, si c'est
  /// un alias (sa taille est celle de sa cible) ou si [raw] contient un NUL.
  int setBytes(int table, int slot, Uint8List raw) {
    _check(table, slot);
    if (raw.contains(0)) {
      throw FormatError(
        'string contains NUL (table $table slot $slot)',
        fileId: fileId,
      );
    }
    final lengths = _lengths[table]!;
    _rebuilt += raw.length - lengths[slot];
    lengths[slot] = raw.length;
    return _rebuilt;
  }

  /// Comme [setBytes] avec un texte encodé en UTF-8.
  int setText(int table, int slot, String text) =>
      setBytes(table, slot, Uint8List.fromList(utf8.encode(text)));

  /// Verdict des niveaux 1 et 2 pour la taille courante.
  BudgetReport report({
    required int origBytes,
    required int slotBytes,
    BudgetPolicy policy = BudgetPolicy.strict,
    Set<int> slotAllowedFileIds = const {},
  }) =>
      evaluateFileBudget(
        fileId: fileId ?? 0,
        origBytes: origBytes,
        rebuiltBytes: _rebuilt,
        slotBytes: slotBytes,
        policy: policy,
        slotAllowedFileIds: slotAllowedFileIds,
      );

  /// Octets restants avant la limite de la politique (négatif si dépassé).
  ///
  /// Limite : [origBytes] en `strict`, [slotBytes] en `slot` (niveau 2 ; le
  /// niveau 1 aligné sur le secteur reste vérifié par [report]).
  int marginBytes({
    required int origBytes,
    required int slotBytes,
    BudgetPolicy policy = BudgetPolicy.strict,
  }) =>
      (policy == BudgetPolicy.strict ? origBytes : slotBytes) - _rebuilt;

  void _check(int table, int slot) {
    final aliases =
        table >= 0 && table < _aliases.length ? _aliases[table] : null;
    if (aliases == null) {
      throw FormatError('no such table $table', fileId: fileId);
    }
    if (slot < 0 || slot >= aliases.length) {
      throw FormatError('no such slot $slot in table $table', fileId: fileId);
    }
    if (aliases[slot]) {
      throw FormatError(
        'slot $slot of table $table is an alias: edit its target',
        fileId: fileId,
      );
    }
  }
}
