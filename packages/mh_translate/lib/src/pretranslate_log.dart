// Journal d'une pré-traduction (JSON Lines), pour comprendre pourquoi des
// chaînes ne sont pas traduites (docs/DECISIONS/0006-pretraduction-ia.md).
//
// Par défaut le journal ne contient **aucun texte du jeu** : seulement des
// identifiants (fichier, table, slot), des motifs de refus, des tailles en
// octets et des compteurs. Avec `includeText` il ajoute le japonais source et
// la proposition refusée du modèle : ce fichier reste **local** (dossier du
// projet, ignoré par git) et ne doit pas être publié.

import 'dart:convert';
import 'dart:io';

/// Destinataire des événements d'une exécution.
abstract interface class PreTranslateLog {
  /// Ajoute le texte du jeu (source et proposition refusée) aux événements.
  bool get includeText;

  /// Enregistre un événement (objet JSON : `t`, `type`, champs propres).
  void add(Map<String, Object?> event);
}

/// Journal en mémoire (tests).
final class MemoryLog implements PreTranslateLog {
  /// Voir les champs.
  MemoryLog({this.includeText = false});

  @override
  final bool includeText;

  /// Événements reçus, dans l'ordre.
  final List<Map<String, Object?>> events = [];

  @override
  void add(Map<String, Object?> event) => events.add(event);

  /// Événements d'un [type].
  List<Map<String, Object?>> ofType(String type) => [
        for (final e in events)
          if (e['type'] == type) e,
      ];
}

/// Journal JSON Lines : une ligne par événement, ajoutée au fichier [path]
/// (dossier créé au besoin).
final class JsonlFileLog implements PreTranslateLog {
  /// Voir les champs.
  JsonlFileLog(this.path, {this.includeText = false}) {
    File(path).parent.createSync(recursive: true);
  }

  /// Fichier du journal.
  final String path;

  @override
  final bool includeText;

  @override
  void add(Map<String, Object?> event) {
    File(path).writeAsStringSync(
      '${jsonEncode(event)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

/// Chemin par défaut : `<projet>/logs/pretranslate-<fichier>-<horodatage>.jsonl`.
String defaultLogPath(String projectDir, int fileId, [DateTime? now]) {
  final n = (now ?? DateTime.now()).toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp = '${n.year}${two(n.month)}${two(n.day)}-'
      '${two(n.hour)}${two(n.minute)}${two(n.second)}';
  return '$projectDir/logs/pretranslate-$fileId-$stamp.jsonl';
}
