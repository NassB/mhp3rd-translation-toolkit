import 'dart:convert';

import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';

/// Brouillon d'une chaîne (texte et statut choisis, pas encore enregistrés).
final class SlotDraft {
  const SlotDraft({required this.text, required this.status});

  final String text;
  final String status;
}

/// État de l'éditeur d'un fichier.
final class FileEditorState {
  const FileEditorState({
    required this.fileId,
    required this.slots,
    this.drafts = const {},
    this.conflicts = const {},
    this.liveBudget,
    this.budgetError,
    this.savingIds = const {},
  });

  final int fileId;

  /// Toutes les chaînes du fichier, triées par table puis slot.
  final List<SlotView> slots;

  /// Brouillons par `sourceId`.
  final Map<int, SlotDraft> drafts;

  /// Conflits d'enregistrement par `sourceId` : version courante en base
  /// (`null` : la ligne a disparu).
  final Map<int, TranslationInfo?> conflicts;

  /// Budget du fichier avec les brouillons ; `null` tant qu'il est calculé ou
  /// s'il est indisponible ([budgetError]).
  final FileBudget? liveBudget;
  final String? budgetError;

  /// Chaînes en cours d'enregistrement.
  final Set<int> savingIds;

  SlotView slot(int sourceId) =>
      slots.firstWhere((s) => s.sourceId == sourceId);

  /// Vrai si le brouillon de [sourceId] diffère de l'état enregistré.
  bool isDirty(int sourceId) => drafts.containsKey(sourceId);

  FileEditorState copyWith({
    List<SlotView>? slots,
    Map<int, SlotDraft>? drafts,
    Map<int, TranslationInfo?>? conflicts,
    FileBudget? liveBudget,
    bool clearLiveBudget = false,
    bool clearBudgetError = false,
    String? budgetError,
    Set<int>? savingIds,
  }) => FileEditorState(
    fileId: fileId,
    slots: slots ?? this.slots,
    drafts: drafts ?? this.drafts,
    conflicts: conflicts ?? this.conflicts,
    liveBudget: clearLiveBudget ? null : (liveBudget ?? this.liveBudget),
    budgetError: clearBudgetError ? null : (budgetError ?? this.budgetError),
    savingIds: savingIds ?? this.savingIds,
  );
}

/// Longueur UTF-8 d'un texte.
int utf8Length(String s) => utf8.encode(s).length;

/// Octets que la chaîne [slot] occupe dans le fichier reconstruit pour une
/// traduction ([text], [status]) : la source tant qu'il n'y a pas de
/// traduction utile (statut `untranslated`, ou texte vide sans ligne en base).
int effectiveLength(
  SlotView slot, {
  required String text,
  required String status,
}) {
  final noTranslation =
      status == 'untranslated' || (text.isEmpty && slot.translation == null);
  return utf8Length(noTranslation ? slot.sourceText : text);
}

/// Longueur de [slot] dans l'état enregistré.
int savedLength(SlotView slot) {
  final t = slot.translation;
  return t == null
      ? utf8Length(slot.sourceText)
      : effectiveLength(slot, text: t.text, status: t.status);
}
