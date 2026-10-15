// Budget d'un fichier pendant l'édition : brouillons non enregistrés.
//
// Sources : docs/ARCHITECTURE.md §8.3 (mise à jour incrémentale). La taille
// reconstruite varie de l'écart de longueur UTF-8 de chaque chaîne modifiée ;
// on part du budget enregistré ([FileBudget]) sans relire l'ISO.

import 'file_budgets.dart';

/// [FileBudget] enregistré plus l'effet des brouillons en cours.
final class LiveFileBudget {
  /// Part de [saved], sans brouillon.
  LiveFileBudget(this.saved);

  /// Budget des traductions enregistrées.
  final FileBudget saved;

  final Map<int, int> _deltas = {};

  /// Déclare le brouillon de la chaîne [key] : [savedLen] octets UTF-8 dans
  /// l'état enregistré, [draftLen] dans le brouillon. Un écart nul retire le
  /// brouillon.
  void setDraft(int key, {required int savedLen, required int draftLen}) {
    final delta = draftLen - savedLen;
    if (delta == 0) {
      _deltas.remove(key);
    } else {
      _deltas[key] = delta;
    }
  }

  /// Retire le brouillon de [key].
  void clearDraft(int key) => _deltas.remove(key);

  /// Nombre de brouillons qui changent la taille.
  int get draftCount => _deltas.length;

  /// Budget avec les brouillons appliqués.
  FileBudget get current => FileBudget(
        fileId: saved.fileId,
        origBytes: saved.origBytes,
        slotBytes: saved.slotBytes,
        rebuiltBytes:
            saved.rebuiltBytes + _deltas.values.fold<int>(0, (a, b) => a + b),
      );

  /// Nouveau départ après l'enregistrement de la chaîne [key] : son brouillon
  /// devient l'état enregistré ; les autres brouillons sont conservés.
  LiveFileBudget afterSave(int key) {
    final delta = _deltas[key] ?? 0;
    final next = LiveFileBudget(
      FileBudget(
        fileId: saved.fileId,
        origBytes: saved.origBytes,
        slotBytes: saved.slotBytes,
        rebuiltBytes: saved.rebuiltBytes + delta,
      ),
    );
    for (final e in _deltas.entries) {
      if (e.key != key) next._deltas[e.key] = e.value;
    }
    return next;
  }
}
