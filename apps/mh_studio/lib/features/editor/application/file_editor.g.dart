// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_editor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Éditeur d'un fichier : brouillons, enregistrement avec concurrence
/// optimiste, jauge d'octets en direct.

@ProviderFor(FileEditor)
final fileEditorProvider = FileEditorFamily._();

/// Éditeur d'un fichier : brouillons, enregistrement avec concurrence
/// optimiste, jauge d'octets en direct.
final class FileEditorProvider
    extends $AsyncNotifierProvider<FileEditor, FileEditorState> {
  /// Éditeur d'un fichier : brouillons, enregistrement avec concurrence
  /// optimiste, jauge d'octets en direct.
  FileEditorProvider._({
    required FileEditorFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'fileEditorProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fileEditorHash();

  @override
  String toString() {
    return r'fileEditorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FileEditor create() => FileEditor();

  @override
  bool operator ==(Object other) {
    return other is FileEditorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fileEditorHash() => r'22096fd84969d1af6706b30b7f215a190614d242';

/// Éditeur d'un fichier : brouillons, enregistrement avec concurrence
/// optimiste, jauge d'octets en direct.

final class FileEditorFamily extends $Family
    with
        $ClassFamilyOverride<
          FileEditor,
          AsyncValue<FileEditorState>,
          FileEditorState,
          FutureOr<FileEditorState>,
          int
        > {
  FileEditorFamily._()
    : super(
        retry: null,
        name: r'fileEditorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Éditeur d'un fichier : brouillons, enregistrement avec concurrence
  /// optimiste, jauge d'octets en direct.

  FileEditorProvider call(int fileId) =>
      FileEditorProvider._(argument: fileId, from: this);

  @override
  String toString() => r'fileEditorProvider';
}

/// Éditeur d'un fichier : brouillons, enregistrement avec concurrence
/// optimiste, jauge d'octets en direct.

abstract class _$FileEditor extends $AsyncNotifier<FileEditorState> {
  late final _$args = ref.$arg as int;
  int get fileId => _$args;

  FutureOr<FileEditorState> build(int fileId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FileEditorState>, FileEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FileEditorState>, FileEditorState>,
              AsyncValue<FileEditorState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
