import 'dart:async';

import 'package:mh_build/mh_build.dart';
import 'package:mh_tdb/mh_tdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../files/application/files_providers.dart';
import 'file_editor_state.dart';

part 'file_editor.g.dart';

/// Délai avant de publier la jauge pendant la saisie (skill studio-ui).
const Duration budgetDebounce = Duration(milliseconds: 150);

/// Éditeur d'un fichier : brouillons, enregistrement avec concurrence
/// optimiste, jauge d'octets en direct.
@riverpod
class FileEditor extends _$FileEditor {
  LiveFileBudget? _live;
  Timer? _debounce;
  AsyncValue<Map<int, FileBudget>>? _budgets;

  @override
  Future<FileEditorState> build(int fileId) async {
    ref.onDispose(() => _debounce?.cancel());
    final repo = ref.watch(translationRepositoryProvider);
    if (repo == null) throw StateError('no project open');
    // Écoute (et garde en vie) le calcul des budgets : l'éditeur s'ouvre sans
    // l'attendre et se met à jour quand il arrive.
    ref.listen(fileBudgetsProvider, (_, next) {
      _budgets = next;
      _applyBudgets();
    }, fireImmediately: true);
    final slots = await repo.slots(
      fileId,
      limit: await repo.countSlots(fileId),
    );
    // L'état initial n'existe qu'après le retour de build.
    unawaited(Future<void>.delayed(Duration.zero, _applyBudgets));
    return FileEditorState(fileId: fileId, slots: slots);
  }

  /// Intègre le budget enregistré dès que l'état et le calcul sont prêts.
  void _applyBudgets() {
    final budgets = _budgets;
    final cur = state.value;
    if (!ref.mounted || budgets == null || cur == null) return;
    if (budgets.hasError) {
      _publish(error: '${budgets.error}');
      return;
    }
    final map = budgets.value;
    if (map == null) return; // calcul en cours
    final base = ref.read(budgetPatchesProvider)[fileId] ?? map[fileId];
    if (base == null) {
      _publish(error: 'budget du fichier introuvable');
      return;
    }
    final live = LiveFileBudget(base);
    for (final e in cur.drafts.entries) {
      final s = cur.slot(e.key);
      live.setDraft(
        e.key,
        savedLen: savedLength(s),
        draftLen: effectiveLength(
          s,
          text: e.value.text,
          status: e.value.status,
        ),
      );
    }
    _live = live;
    _publish();
  }

  void _publish({String? error}) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(
      error != null
          ? cur.copyWith(clearLiveBudget: true, budgetError: error)
          : cur.copyWith(liveBudget: _live?.current, clearBudgetError: true),
    );
  }

  void _scheduleBudget() {
    _debounce?.cancel();
    _debounce = Timer(budgetDebounce, () {
      if (ref.mounted) _publish();
    });
  }

  /// Texte et statut enregistrés de [slot] (`''` / `untranslated` si aucun).
  (String, String) _savedOf(SlotView slot) => (
    slot.translation?.text ?? '',
    slot.translation?.status ?? 'untranslated',
  );

  /// Met à jour le brouillon de [sourceId]. Un brouillon identique à l'état
  /// enregistré est retiré.
  void setDraft(int sourceId, {String? text, String? status}) {
    final cur = state.value;
    if (cur == null) return;
    final slot = cur.slot(sourceId);
    if (slot.isAlias) return; // lecture seule : on traduit la cible
    final old = cur.drafts[sourceId];
    final (savedText, savedStatus) = _savedOf(slot);
    final newText = text ?? old?.text ?? savedText;
    final newStatus =
        status ??
        old?.status ??
        (slot.translation == null ? 'draft' : savedStatus);

    final drafts = {...cur.drafts};
    final unchanged =
        newText == savedText &&
        (slot.translation == null || newStatus == savedStatus);
    if (unchanged) {
      drafts.remove(sourceId);
      _live?.clearDraft(sourceId);
    } else {
      drafts[sourceId] = SlotDraft(text: newText, status: newStatus);
      _live?.setDraft(
        sourceId,
        savedLen: savedLength(slot),
        draftLen: effectiveLength(slot, text: newText, status: newStatus),
      );
    }
    state = AsyncData(cur.copyWith(drafts: drafts));
    _scheduleBudget();
  }

  /// Abandonne le brouillon de [sourceId] (et son éventuel conflit).
  void discard(int sourceId) {
    final cur = state.value;
    if (cur == null) return;
    _live?.clearDraft(sourceId);
    state = AsyncData(
      cur.copyWith(
        drafts: {...cur.drafts}..remove(sourceId),
        conflicts: {...cur.conflicts}..remove(sourceId),
      ),
    );
    _scheduleBudget();
  }

  /// Après un conflit : adopte la version courante de la base et abandonne le
  /// brouillon. Le budget enregistré ne tient pas compte de cette version
  /// distante : il sera recalculé au prochain calcul global.
  void adoptConflict(int sourceId) {
    final cur = state.value;
    if (cur == null || !cur.conflicts.containsKey(sourceId)) return;
    final theirs = cur.conflicts[sourceId];
    final slots = [
      for (final s in cur.slots)
        if (s.sourceId == sourceId) _withTranslation(s, theirs) else s,
    ];
    _live?.clearDraft(sourceId);
    state = AsyncData(
      cur.copyWith(
        slots: slots,
        drafts: {...cur.drafts}..remove(sourceId),
        conflicts: {...cur.conflicts}..remove(sourceId),
      ),
    );
    _scheduleBudget();
  }

  /// Enregistre le brouillon de [sourceId]. Retourne `true` si accepté.
  Future<bool> save(int sourceId, {String? authorId}) async {
    final cur = state.value;
    final draft = cur?.drafts[sourceId];
    final repo = ref.read(translationRepositoryProvider);
    if (cur == null || draft == null || repo == null) return false;
    final slot = cur.slot(sourceId);
    state = AsyncData(cur.copyWith(savingIds: {...cur.savingIds, sourceId}));

    final result = await repo.saveTranslation(
      sourceId: sourceId,
      text: draft.text,
      status: draft.status,
      expectedRevision: slot.translation?.revision,
      authorId: authorId,
    );
    if (!ref.mounted) return false;
    final now = state.value!;
    final saving = {...now.savingIds}..remove(sourceId);
    switch (result) {
      case SaveOk(:final translation):
        final slots = [
          for (final s in now.slots)
            if (s.sourceId == sourceId) _withTranslation(s, translation) else s,
        ];
        final next = _live?.afterSave(sourceId);
        _live = next;
        if (next != null) {
          ref.read(budgetPatchesProvider.notifier).put(next.saved);
        }
        state = AsyncData(
          now.copyWith(
            slots: slots,
            drafts: {...now.drafts}..remove(sourceId),
            conflicts: {...now.conflicts}..remove(sourceId),
            savingIds: saving,
          ),
        );
        ref.invalidate(fileListProvider);
        _publish();
        return true;
      case SaveConflict(:final current):
        state = AsyncData(
          now.copyWith(
            conflicts: {...now.conflicts, sourceId: current},
            savingIds: saving,
          ),
        );
        return false;
    }
  }

  SlotView _withTranslation(SlotView s, TranslationInfo? t) => SlotView(
    sourceId: s.sourceId,
    fileId: s.fileId,
    tableIdx: s.tableIdx,
    slotIdx: s.slotIdx,
    sourceText: s.sourceText,
    aliasOfSlot: s.aliasOfSlot,
    translation: t,
  );
}
