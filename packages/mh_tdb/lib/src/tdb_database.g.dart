// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tdb_database.dart';

// ignore_for_file: type=lint
class $GameFilesTable extends GameFiles
    with TableInfo<$GameFilesTable, GameFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _versionIdMeta =
      const VerificationMeta('versionId');
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
      'version_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _codecMeta = const VerificationMeta('codec');
  @override
  late final GeneratedColumn<String> codec = GeneratedColumn<String>(
      'codec', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lbaMeta = const VerificationMeta('lba');
  @override
  late final GeneratedColumn<int> lba = GeneratedColumn<int>(
      'lba', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _slotBytesMeta =
      const VerificationMeta('slotBytes');
  @override
  late final GeneratedColumn<int> slotBytes = GeneratedColumn<int>(
      'slot_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _origBytesMeta =
      const VerificationMeta('origBytes');
  @override
  late final GeneratedColumn<int> origBytes = GeneratedColumn<int>(
      'orig_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _contextProfileMeta =
      const VerificationMeta('contextProfile');
  @override
  late final GeneratedColumn<String> contextProfile = GeneratedColumn<String>(
      'context_profile', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, versionId, codec, lba, slotBytes, origBytes, label, contextProfile];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_file';
  @override
  VerificationContext validateIntegrity(Insertable<GameFileRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('version_id')) {
      context.handle(_versionIdMeta,
          versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta));
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('codec')) {
      context.handle(
          _codecMeta, codec.isAcceptableOrUnknown(data['codec']!, _codecMeta));
    } else if (isInserting) {
      context.missing(_codecMeta);
    }
    if (data.containsKey('lba')) {
      context.handle(
          _lbaMeta, lba.isAcceptableOrUnknown(data['lba']!, _lbaMeta));
    } else if (isInserting) {
      context.missing(_lbaMeta);
    }
    if (data.containsKey('slot_bytes')) {
      context.handle(_slotBytesMeta,
          slotBytes.isAcceptableOrUnknown(data['slot_bytes']!, _slotBytesMeta));
    } else if (isInserting) {
      context.missing(_slotBytesMeta);
    }
    if (data.containsKey('orig_bytes')) {
      context.handle(_origBytesMeta,
          origBytes.isAcceptableOrUnknown(data['orig_bytes']!, _origBytesMeta));
    } else if (isInserting) {
      context.missing(_origBytesMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    if (data.containsKey('context_profile')) {
      context.handle(
          _contextProfileMeta,
          contextProfile.isAcceptableOrUnknown(
              data['context_profile']!, _contextProfileMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameFileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      versionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version_id'])!,
      codec: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}codec'])!,
      lba: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lba'])!,
      slotBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}slot_bytes'])!,
      origBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}orig_bytes'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label']),
      contextProfile: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_profile']),
    );
  }

  @override
  $GameFilesTable createAlias(String alias) {
    return $GameFilesTable(attachedDatabase, alias);
  }
}

class GameFileRow extends DataClass implements Insertable<GameFileRow> {
  /// ID DATA.BIN (base 1).
  final int id;

  /// ULJM05800 / NPJB40001_HD.
  final String versionId;
  final String codec;
  final int lba;
  final int slotBytes;
  final int origBytes;
  final String? label;

  /// Profil de longueur par défaut.
  final String? contextProfile;
  const GameFileRow(
      {required this.id,
      required this.versionId,
      required this.codec,
      required this.lba,
      required this.slotBytes,
      required this.origBytes,
      this.label,
      this.contextProfile});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['version_id'] = Variable<String>(versionId);
    map['codec'] = Variable<String>(codec);
    map['lba'] = Variable<int>(lba);
    map['slot_bytes'] = Variable<int>(slotBytes);
    map['orig_bytes'] = Variable<int>(origBytes);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || contextProfile != null) {
      map['context_profile'] = Variable<String>(contextProfile);
    }
    return map;
  }

  GameFilesCompanion toCompanion(bool nullToAbsent) {
    return GameFilesCompanion(
      id: Value(id),
      versionId: Value(versionId),
      codec: Value(codec),
      lba: Value(lba),
      slotBytes: Value(slotBytes),
      origBytes: Value(origBytes),
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
      contextProfile: contextProfile == null && nullToAbsent
          ? const Value.absent()
          : Value(contextProfile),
    );
  }

  factory GameFileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameFileRow(
      id: serializer.fromJson<int>(json['id']),
      versionId: serializer.fromJson<String>(json['versionId']),
      codec: serializer.fromJson<String>(json['codec']),
      lba: serializer.fromJson<int>(json['lba']),
      slotBytes: serializer.fromJson<int>(json['slotBytes']),
      origBytes: serializer.fromJson<int>(json['origBytes']),
      label: serializer.fromJson<String?>(json['label']),
      contextProfile: serializer.fromJson<String?>(json['contextProfile']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'versionId': serializer.toJson<String>(versionId),
      'codec': serializer.toJson<String>(codec),
      'lba': serializer.toJson<int>(lba),
      'slotBytes': serializer.toJson<int>(slotBytes),
      'origBytes': serializer.toJson<int>(origBytes),
      'label': serializer.toJson<String?>(label),
      'contextProfile': serializer.toJson<String?>(contextProfile),
    };
  }

  GameFileRow copyWith(
          {int? id,
          String? versionId,
          String? codec,
          int? lba,
          int? slotBytes,
          int? origBytes,
          Value<String?> label = const Value.absent(),
          Value<String?> contextProfile = const Value.absent()}) =>
      GameFileRow(
        id: id ?? this.id,
        versionId: versionId ?? this.versionId,
        codec: codec ?? this.codec,
        lba: lba ?? this.lba,
        slotBytes: slotBytes ?? this.slotBytes,
        origBytes: origBytes ?? this.origBytes,
        label: label.present ? label.value : this.label,
        contextProfile:
            contextProfile.present ? contextProfile.value : this.contextProfile,
      );
  GameFileRow copyWithCompanion(GameFilesCompanion data) {
    return GameFileRow(
      id: data.id.present ? data.id.value : this.id,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      codec: data.codec.present ? data.codec.value : this.codec,
      lba: data.lba.present ? data.lba.value : this.lba,
      slotBytes: data.slotBytes.present ? data.slotBytes.value : this.slotBytes,
      origBytes: data.origBytes.present ? data.origBytes.value : this.origBytes,
      label: data.label.present ? data.label.value : this.label,
      contextProfile: data.contextProfile.present
          ? data.contextProfile.value
          : this.contextProfile,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameFileRow(')
          ..write('id: $id, ')
          ..write('versionId: $versionId, ')
          ..write('codec: $codec, ')
          ..write('lba: $lba, ')
          ..write('slotBytes: $slotBytes, ')
          ..write('origBytes: $origBytes, ')
          ..write('label: $label, ')
          ..write('contextProfile: $contextProfile')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, versionId, codec, lba, slotBytes, origBytes, label, contextProfile);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameFileRow &&
          other.id == this.id &&
          other.versionId == this.versionId &&
          other.codec == this.codec &&
          other.lba == this.lba &&
          other.slotBytes == this.slotBytes &&
          other.origBytes == this.origBytes &&
          other.label == this.label &&
          other.contextProfile == this.contextProfile);
}

class GameFilesCompanion extends UpdateCompanion<GameFileRow> {
  final Value<int> id;
  final Value<String> versionId;
  final Value<String> codec;
  final Value<int> lba;
  final Value<int> slotBytes;
  final Value<int> origBytes;
  final Value<String?> label;
  final Value<String?> contextProfile;
  const GameFilesCompanion({
    this.id = const Value.absent(),
    this.versionId = const Value.absent(),
    this.codec = const Value.absent(),
    this.lba = const Value.absent(),
    this.slotBytes = const Value.absent(),
    this.origBytes = const Value.absent(),
    this.label = const Value.absent(),
    this.contextProfile = const Value.absent(),
  });
  GameFilesCompanion.insert({
    this.id = const Value.absent(),
    required String versionId,
    required String codec,
    required int lba,
    required int slotBytes,
    required int origBytes,
    this.label = const Value.absent(),
    this.contextProfile = const Value.absent(),
  })  : versionId = Value(versionId),
        codec = Value(codec),
        lba = Value(lba),
        slotBytes = Value(slotBytes),
        origBytes = Value(origBytes);
  static Insertable<GameFileRow> custom({
    Expression<int>? id,
    Expression<String>? versionId,
    Expression<String>? codec,
    Expression<int>? lba,
    Expression<int>? slotBytes,
    Expression<int>? origBytes,
    Expression<String>? label,
    Expression<String>? contextProfile,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versionId != null) 'version_id': versionId,
      if (codec != null) 'codec': codec,
      if (lba != null) 'lba': lba,
      if (slotBytes != null) 'slot_bytes': slotBytes,
      if (origBytes != null) 'orig_bytes': origBytes,
      if (label != null) 'label': label,
      if (contextProfile != null) 'context_profile': contextProfile,
    });
  }

  GameFilesCompanion copyWith(
      {Value<int>? id,
      Value<String>? versionId,
      Value<String>? codec,
      Value<int>? lba,
      Value<int>? slotBytes,
      Value<int>? origBytes,
      Value<String?>? label,
      Value<String?>? contextProfile}) {
    return GameFilesCompanion(
      id: id ?? this.id,
      versionId: versionId ?? this.versionId,
      codec: codec ?? this.codec,
      lba: lba ?? this.lba,
      slotBytes: slotBytes ?? this.slotBytes,
      origBytes: origBytes ?? this.origBytes,
      label: label ?? this.label,
      contextProfile: contextProfile ?? this.contextProfile,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (codec.present) {
      map['codec'] = Variable<String>(codec.value);
    }
    if (lba.present) {
      map['lba'] = Variable<int>(lba.value);
    }
    if (slotBytes.present) {
      map['slot_bytes'] = Variable<int>(slotBytes.value);
    }
    if (origBytes.present) {
      map['orig_bytes'] = Variable<int>(origBytes.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (contextProfile.present) {
      map['context_profile'] = Variable<String>(contextProfile.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameFilesCompanion(')
          ..write('id: $id, ')
          ..write('versionId: $versionId, ')
          ..write('codec: $codec, ')
          ..write('lba: $lba, ')
          ..write('slotBytes: $slotBytes, ')
          ..write('origBytes: $origBytes, ')
          ..write('label: $label, ')
          ..write('contextProfile: $contextProfile')
          ..write(')'))
        .toString();
  }
}

class $SourceStringsTable extends SourceStrings
    with TableInfo<$SourceStringsTable, SourceStringRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceStringsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<int> fileId = GeneratedColumn<int>(
      'file_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES game_file (id)');
  static const VerificationMeta _tableIdxMeta =
      const VerificationMeta('tableIdx');
  @override
  late final GeneratedColumn<int> tableIdx = GeneratedColumn<int>(
      'table_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _slotIdxMeta =
      const VerificationMeta('slotIdx');
  @override
  late final GeneratedColumn<int> slotIdx = GeneratedColumn<int>(
      'slot_idx', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sourceHashMeta =
      const VerificationMeta('sourceHash');
  @override
  late final GeneratedColumn<String> sourceHash = GeneratedColumn<String>(
      'source_hash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceTextMeta =
      const VerificationMeta('sourceText');
  @override
  late final GeneratedColumn<String> sourceText = GeneratedColumn<String>(
      'source_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aliasOfMeta =
      const VerificationMeta('aliasOf');
  @override
  late final GeneratedColumn<int> aliasOf = GeneratedColumn<int>(
      'alias_of', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'REFERENCES source_string (id)');
  static const VerificationMeta _contextProfileMeta =
      const VerificationMeta('contextProfile');
  @override
  late final GeneratedColumn<String> contextProfile = GeneratedColumn<String>(
      'context_profile', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        fileId,
        tableIdx,
        slotIdx,
        sourceHash,
        sourceText,
        aliasOf,
        contextProfile
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_string';
  @override
  VerificationContext validateIntegrity(Insertable<SourceStringRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_id')) {
      context.handle(_fileIdMeta,
          fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta));
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('table_idx')) {
      context.handle(_tableIdxMeta,
          tableIdx.isAcceptableOrUnknown(data['table_idx']!, _tableIdxMeta));
    } else if (isInserting) {
      context.missing(_tableIdxMeta);
    }
    if (data.containsKey('slot_idx')) {
      context.handle(_slotIdxMeta,
          slotIdx.isAcceptableOrUnknown(data['slot_idx']!, _slotIdxMeta));
    } else if (isInserting) {
      context.missing(_slotIdxMeta);
    }
    if (data.containsKey('source_hash')) {
      context.handle(
          _sourceHashMeta,
          sourceHash.isAcceptableOrUnknown(
              data['source_hash']!, _sourceHashMeta));
    } else if (isInserting) {
      context.missing(_sourceHashMeta);
    }
    if (data.containsKey('source_text')) {
      context.handle(
          _sourceTextMeta,
          sourceText.isAcceptableOrUnknown(
              data['source_text']!, _sourceTextMeta));
    } else if (isInserting) {
      context.missing(_sourceTextMeta);
    }
    if (data.containsKey('alias_of')) {
      context.handle(_aliasOfMeta,
          aliasOf.isAcceptableOrUnknown(data['alias_of']!, _aliasOfMeta));
    }
    if (data.containsKey('context_profile')) {
      context.handle(
          _contextProfileMeta,
          contextProfile.isAcceptableOrUnknown(
              data['context_profile']!, _contextProfileMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {fileId, tableIdx, slotIdx},
      ];
  @override
  SourceStringRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceStringRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fileId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_id'])!,
      tableIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}table_idx'])!,
      slotIdx: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}slot_idx'])!,
      sourceHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_hash'])!,
      sourceText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_text'])!,
      aliasOf: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}alias_of']),
      contextProfile: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_profile']),
    );
  }

  @override
  $SourceStringsTable createAlias(String alias) {
    return $SourceStringsTable(attachedDatabase, alias);
  }
}

class SourceStringRow extends DataClass implements Insertable<SourceStringRow> {
  final int id;
  final int fileId;
  final int tableIdx;
  final int slotIdx;

  /// SHA-1 hexadécimal des octets d'origine.
  final String sourceHash;

  /// Texte UTF-8 avec `\n` réel (rendu des jetons) ; base privée uniquement.
  final String sourceText;

  /// Chaîne dont celle-ci est un alias (même offset dans le binaire).
  final int? aliasOf;
  final String? contextProfile;
  const SourceStringRow(
      {required this.id,
      required this.fileId,
      required this.tableIdx,
      required this.slotIdx,
      required this.sourceHash,
      required this.sourceText,
      this.aliasOf,
      this.contextProfile});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_id'] = Variable<int>(fileId);
    map['table_idx'] = Variable<int>(tableIdx);
    map['slot_idx'] = Variable<int>(slotIdx);
    map['source_hash'] = Variable<String>(sourceHash);
    map['source_text'] = Variable<String>(sourceText);
    if (!nullToAbsent || aliasOf != null) {
      map['alias_of'] = Variable<int>(aliasOf);
    }
    if (!nullToAbsent || contextProfile != null) {
      map['context_profile'] = Variable<String>(contextProfile);
    }
    return map;
  }

  SourceStringsCompanion toCompanion(bool nullToAbsent) {
    return SourceStringsCompanion(
      id: Value(id),
      fileId: Value(fileId),
      tableIdx: Value(tableIdx),
      slotIdx: Value(slotIdx),
      sourceHash: Value(sourceHash),
      sourceText: Value(sourceText),
      aliasOf: aliasOf == null && nullToAbsent
          ? const Value.absent()
          : Value(aliasOf),
      contextProfile: contextProfile == null && nullToAbsent
          ? const Value.absent()
          : Value(contextProfile),
    );
  }

  factory SourceStringRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceStringRow(
      id: serializer.fromJson<int>(json['id']),
      fileId: serializer.fromJson<int>(json['fileId']),
      tableIdx: serializer.fromJson<int>(json['tableIdx']),
      slotIdx: serializer.fromJson<int>(json['slotIdx']),
      sourceHash: serializer.fromJson<String>(json['sourceHash']),
      sourceText: serializer.fromJson<String>(json['sourceText']),
      aliasOf: serializer.fromJson<int?>(json['aliasOf']),
      contextProfile: serializer.fromJson<String?>(json['contextProfile']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileId': serializer.toJson<int>(fileId),
      'tableIdx': serializer.toJson<int>(tableIdx),
      'slotIdx': serializer.toJson<int>(slotIdx),
      'sourceHash': serializer.toJson<String>(sourceHash),
      'sourceText': serializer.toJson<String>(sourceText),
      'aliasOf': serializer.toJson<int?>(aliasOf),
      'contextProfile': serializer.toJson<String?>(contextProfile),
    };
  }

  SourceStringRow copyWith(
          {int? id,
          int? fileId,
          int? tableIdx,
          int? slotIdx,
          String? sourceHash,
          String? sourceText,
          Value<int?> aliasOf = const Value.absent(),
          Value<String?> contextProfile = const Value.absent()}) =>
      SourceStringRow(
        id: id ?? this.id,
        fileId: fileId ?? this.fileId,
        tableIdx: tableIdx ?? this.tableIdx,
        slotIdx: slotIdx ?? this.slotIdx,
        sourceHash: sourceHash ?? this.sourceHash,
        sourceText: sourceText ?? this.sourceText,
        aliasOf: aliasOf.present ? aliasOf.value : this.aliasOf,
        contextProfile:
            contextProfile.present ? contextProfile.value : this.contextProfile,
      );
  SourceStringRow copyWithCompanion(SourceStringsCompanion data) {
    return SourceStringRow(
      id: data.id.present ? data.id.value : this.id,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      tableIdx: data.tableIdx.present ? data.tableIdx.value : this.tableIdx,
      slotIdx: data.slotIdx.present ? data.slotIdx.value : this.slotIdx,
      sourceHash:
          data.sourceHash.present ? data.sourceHash.value : this.sourceHash,
      sourceText:
          data.sourceText.present ? data.sourceText.value : this.sourceText,
      aliasOf: data.aliasOf.present ? data.aliasOf.value : this.aliasOf,
      contextProfile: data.contextProfile.present
          ? data.contextProfile.value
          : this.contextProfile,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceStringRow(')
          ..write('id: $id, ')
          ..write('fileId: $fileId, ')
          ..write('tableIdx: $tableIdx, ')
          ..write('slotIdx: $slotIdx, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('sourceText: $sourceText, ')
          ..write('aliasOf: $aliasOf, ')
          ..write('contextProfile: $contextProfile')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fileId, tableIdx, slotIdx, sourceHash,
      sourceText, aliasOf, contextProfile);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceStringRow &&
          other.id == this.id &&
          other.fileId == this.fileId &&
          other.tableIdx == this.tableIdx &&
          other.slotIdx == this.slotIdx &&
          other.sourceHash == this.sourceHash &&
          other.sourceText == this.sourceText &&
          other.aliasOf == this.aliasOf &&
          other.contextProfile == this.contextProfile);
}

class SourceStringsCompanion extends UpdateCompanion<SourceStringRow> {
  final Value<int> id;
  final Value<int> fileId;
  final Value<int> tableIdx;
  final Value<int> slotIdx;
  final Value<String> sourceHash;
  final Value<String> sourceText;
  final Value<int?> aliasOf;
  final Value<String?> contextProfile;
  const SourceStringsCompanion({
    this.id = const Value.absent(),
    this.fileId = const Value.absent(),
    this.tableIdx = const Value.absent(),
    this.slotIdx = const Value.absent(),
    this.sourceHash = const Value.absent(),
    this.sourceText = const Value.absent(),
    this.aliasOf = const Value.absent(),
    this.contextProfile = const Value.absent(),
  });
  SourceStringsCompanion.insert({
    this.id = const Value.absent(),
    required int fileId,
    required int tableIdx,
    required int slotIdx,
    required String sourceHash,
    required String sourceText,
    this.aliasOf = const Value.absent(),
    this.contextProfile = const Value.absent(),
  })  : fileId = Value(fileId),
        tableIdx = Value(tableIdx),
        slotIdx = Value(slotIdx),
        sourceHash = Value(sourceHash),
        sourceText = Value(sourceText);
  static Insertable<SourceStringRow> custom({
    Expression<int>? id,
    Expression<int>? fileId,
    Expression<int>? tableIdx,
    Expression<int>? slotIdx,
    Expression<String>? sourceHash,
    Expression<String>? sourceText,
    Expression<int>? aliasOf,
    Expression<String>? contextProfile,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileId != null) 'file_id': fileId,
      if (tableIdx != null) 'table_idx': tableIdx,
      if (slotIdx != null) 'slot_idx': slotIdx,
      if (sourceHash != null) 'source_hash': sourceHash,
      if (sourceText != null) 'source_text': sourceText,
      if (aliasOf != null) 'alias_of': aliasOf,
      if (contextProfile != null) 'context_profile': contextProfile,
    });
  }

  SourceStringsCompanion copyWith(
      {Value<int>? id,
      Value<int>? fileId,
      Value<int>? tableIdx,
      Value<int>? slotIdx,
      Value<String>? sourceHash,
      Value<String>? sourceText,
      Value<int?>? aliasOf,
      Value<String?>? contextProfile}) {
    return SourceStringsCompanion(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      tableIdx: tableIdx ?? this.tableIdx,
      slotIdx: slotIdx ?? this.slotIdx,
      sourceHash: sourceHash ?? this.sourceHash,
      sourceText: sourceText ?? this.sourceText,
      aliasOf: aliasOf ?? this.aliasOf,
      contextProfile: contextProfile ?? this.contextProfile,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<int>(fileId.value);
    }
    if (tableIdx.present) {
      map['table_idx'] = Variable<int>(tableIdx.value);
    }
    if (slotIdx.present) {
      map['slot_idx'] = Variable<int>(slotIdx.value);
    }
    if (sourceHash.present) {
      map['source_hash'] = Variable<String>(sourceHash.value);
    }
    if (sourceText.present) {
      map['source_text'] = Variable<String>(sourceText.value);
    }
    if (aliasOf.present) {
      map['alias_of'] = Variable<int>(aliasOf.value);
    }
    if (contextProfile.present) {
      map['context_profile'] = Variable<String>(contextProfile.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceStringsCompanion(')
          ..write('id: $id, ')
          ..write('fileId: $fileId, ')
          ..write('tableIdx: $tableIdx, ')
          ..write('slotIdx: $slotIdx, ')
          ..write('sourceHash: $sourceHash, ')
          ..write('sourceText: $sourceText, ')
          ..write('aliasOf: $aliasOf, ')
          ..write('contextProfile: $contextProfile')
          ..write(')'))
        .toString();
  }
}

class $TranslationsTable extends Translations
    with TableInfo<$TranslationsTable, TranslationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
      'source_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES source_string (id)');
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
      'locale', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _text_Meta = const VerificationMeta('text_');
  @override
  late final GeneratedColumn<String> text_ = GeneratedColumn<String>(
      'text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      check: () => status.isIn(translationStatuses),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _authorIdMeta =
      const VerificationMeta('authorId');
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
      'author_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _budgetBytesMeta =
      const VerificationMeta('budgetBytes');
  @override
  late final GeneratedColumn<int> budgetBytes = GeneratedColumn<int>(
      'budget_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _budgetPxMaxMeta =
      const VerificationMeta('budgetPxMax');
  @override
  late final GeneratedColumn<int> budgetPxMax = GeneratedColumn<int>(
      'budget_px_max', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sourceId,
        locale,
        text_,
        status,
        revision,
        authorId,
        updatedAt,
        budgetBytes,
        budgetPxMax
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translation';
  @override
  VerificationContext validateIntegrity(Insertable<TranslationRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('locale')) {
      context.handle(_localeMeta,
          locale.isAcceptableOrUnknown(data['locale']!, _localeMeta));
    } else if (isInserting) {
      context.missing(_localeMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
          _text_Meta, text_.isAcceptableOrUnknown(data['text']!, _text_Meta));
    } else if (isInserting) {
      context.missing(_text_Meta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    }
    if (data.containsKey('author_id')) {
      context.handle(_authorIdMeta,
          authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('budget_bytes')) {
      context.handle(
          _budgetBytesMeta,
          budgetBytes.isAcceptableOrUnknown(
              data['budget_bytes']!, _budgetBytesMeta));
    }
    if (data.containsKey('budget_px_max')) {
      context.handle(
          _budgetPxMaxMeta,
          budgetPxMax.isAcceptableOrUnknown(
              data['budget_px_max']!, _budgetPxMaxMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {sourceId, locale},
      ];
  @override
  TranslationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranslationRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}source_id'])!,
      locale: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}locale'])!,
      text_: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      authorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_id']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      budgetBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}budget_bytes']),
      budgetPxMax: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}budget_px_max']),
    );
  }

  @override
  $TranslationsTable createAlias(String alias) {
    return $TranslationsTable(attachedDatabase, alias);
  }
}

class TranslationRow extends DataClass implements Insertable<TranslationRow> {
  final int id;
  final int sourceId;

  /// 'fr', 'en', ...
  final String locale;
  final String text_;
  final String status;
  final int revision;

  /// Identifiant d'auteur (UUID en texte), absent en mode local.
  final String? authorId;
  final DateTime updatedAt;

  /// Cache de `mh_budget`.
  final int? budgetBytes;
  final int? budgetPxMax;
  const TranslationRow(
      {required this.id,
      required this.sourceId,
      required this.locale,
      required this.text_,
      required this.status,
      required this.revision,
      this.authorId,
      required this.updatedAt,
      this.budgetBytes,
      this.budgetPxMax});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<int>(sourceId);
    map['locale'] = Variable<String>(locale);
    map['text'] = Variable<String>(text_);
    map['status'] = Variable<String>(status);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || authorId != null) {
      map['author_id'] = Variable<String>(authorId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || budgetBytes != null) {
      map['budget_bytes'] = Variable<int>(budgetBytes);
    }
    if (!nullToAbsent || budgetPxMax != null) {
      map['budget_px_max'] = Variable<int>(budgetPxMax);
    }
    return map;
  }

  TranslationsCompanion toCompanion(bool nullToAbsent) {
    return TranslationsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      locale: Value(locale),
      text_: Value(text_),
      status: Value(status),
      revision: Value(revision),
      authorId: authorId == null && nullToAbsent
          ? const Value.absent()
          : Value(authorId),
      updatedAt: Value(updatedAt),
      budgetBytes: budgetBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetBytes),
      budgetPxMax: budgetPxMax == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetPxMax),
    );
  }

  factory TranslationRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranslationRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      locale: serializer.fromJson<String>(json['locale']),
      text_: serializer.fromJson<String>(json['text_']),
      status: serializer.fromJson<String>(json['status']),
      revision: serializer.fromJson<int>(json['revision']),
      authorId: serializer.fromJson<String?>(json['authorId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      budgetBytes: serializer.fromJson<int?>(json['budgetBytes']),
      budgetPxMax: serializer.fromJson<int?>(json['budgetPxMax']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<int>(sourceId),
      'locale': serializer.toJson<String>(locale),
      'text_': serializer.toJson<String>(text_),
      'status': serializer.toJson<String>(status),
      'revision': serializer.toJson<int>(revision),
      'authorId': serializer.toJson<String?>(authorId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'budgetBytes': serializer.toJson<int?>(budgetBytes),
      'budgetPxMax': serializer.toJson<int?>(budgetPxMax),
    };
  }

  TranslationRow copyWith(
          {int? id,
          int? sourceId,
          String? locale,
          String? text_,
          String? status,
          int? revision,
          Value<String?> authorId = const Value.absent(),
          DateTime? updatedAt,
          Value<int?> budgetBytes = const Value.absent(),
          Value<int?> budgetPxMax = const Value.absent()}) =>
      TranslationRow(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        locale: locale ?? this.locale,
        text_: text_ ?? this.text_,
        status: status ?? this.status,
        revision: revision ?? this.revision,
        authorId: authorId.present ? authorId.value : this.authorId,
        updatedAt: updatedAt ?? this.updatedAt,
        budgetBytes: budgetBytes.present ? budgetBytes.value : this.budgetBytes,
        budgetPxMax: budgetPxMax.present ? budgetPxMax.value : this.budgetPxMax,
      );
  TranslationRow copyWithCompanion(TranslationsCompanion data) {
    return TranslationRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      locale: data.locale.present ? data.locale.value : this.locale,
      text_: data.text_.present ? data.text_.value : this.text_,
      status: data.status.present ? data.status.value : this.status,
      revision: data.revision.present ? data.revision.value : this.revision,
      authorId: data.authorId.present ? data.authorId.value : this.authorId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      budgetBytes:
          data.budgetBytes.present ? data.budgetBytes.value : this.budgetBytes,
      budgetPxMax:
          data.budgetPxMax.present ? data.budgetPxMax.value : this.budgetPxMax,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranslationRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('locale: $locale, ')
          ..write('text_: $text_, ')
          ..write('status: $status, ')
          ..write('revision: $revision, ')
          ..write('authorId: $authorId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('budgetBytes: $budgetBytes, ')
          ..write('budgetPxMax: $budgetPxMax')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sourceId, locale, text_, status, revision,
      authorId, updatedAt, budgetBytes, budgetPxMax);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.locale == this.locale &&
          other.text_ == this.text_ &&
          other.status == this.status &&
          other.revision == this.revision &&
          other.authorId == this.authorId &&
          other.updatedAt == this.updatedAt &&
          other.budgetBytes == this.budgetBytes &&
          other.budgetPxMax == this.budgetPxMax);
}

class TranslationsCompanion extends UpdateCompanion<TranslationRow> {
  final Value<int> id;
  final Value<int> sourceId;
  final Value<String> locale;
  final Value<String> text_;
  final Value<String> status;
  final Value<int> revision;
  final Value<String?> authorId;
  final Value<DateTime> updatedAt;
  final Value<int?> budgetBytes;
  final Value<int?> budgetPxMax;
  const TranslationsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.locale = const Value.absent(),
    this.text_ = const Value.absent(),
    this.status = const Value.absent(),
    this.revision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.budgetBytes = const Value.absent(),
    this.budgetPxMax = const Value.absent(),
  });
  TranslationsCompanion.insert({
    this.id = const Value.absent(),
    required int sourceId,
    required String locale,
    required String text_,
    required String status,
    this.revision = const Value.absent(),
    this.authorId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.budgetBytes = const Value.absent(),
    this.budgetPxMax = const Value.absent(),
  })  : sourceId = Value(sourceId),
        locale = Value(locale),
        text_ = Value(text_),
        status = Value(status);
  static Insertable<TranslationRow> custom({
    Expression<int>? id,
    Expression<int>? sourceId,
    Expression<String>? locale,
    Expression<String>? text_,
    Expression<String>? status,
    Expression<int>? revision,
    Expression<String>? authorId,
    Expression<DateTime>? updatedAt,
    Expression<int>? budgetBytes,
    Expression<int>? budgetPxMax,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (locale != null) 'locale': locale,
      if (text_ != null) 'text': text_,
      if (status != null) 'status': status,
      if (revision != null) 'revision': revision,
      if (authorId != null) 'author_id': authorId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (budgetBytes != null) 'budget_bytes': budgetBytes,
      if (budgetPxMax != null) 'budget_px_max': budgetPxMax,
    });
  }

  TranslationsCompanion copyWith(
      {Value<int>? id,
      Value<int>? sourceId,
      Value<String>? locale,
      Value<String>? text_,
      Value<String>? status,
      Value<int>? revision,
      Value<String?>? authorId,
      Value<DateTime>? updatedAt,
      Value<int?>? budgetBytes,
      Value<int?>? budgetPxMax}) {
    return TranslationsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      locale: locale ?? this.locale,
      text_: text_ ?? this.text_,
      status: status ?? this.status,
      revision: revision ?? this.revision,
      authorId: authorId ?? this.authorId,
      updatedAt: updatedAt ?? this.updatedAt,
      budgetBytes: budgetBytes ?? this.budgetBytes,
      budgetPxMax: budgetPxMax ?? this.budgetPxMax,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (text_.present) {
      map['text'] = Variable<String>(text_.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (budgetBytes.present) {
      map['budget_bytes'] = Variable<int>(budgetBytes.value);
    }
    if (budgetPxMax.present) {
      map['budget_px_max'] = Variable<int>(budgetPxMax.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('locale: $locale, ')
          ..write('text_: $text_, ')
          ..write('status: $status, ')
          ..write('revision: $revision, ')
          ..write('authorId: $authorId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('budgetBytes: $budgetBytes, ')
          ..write('budgetPxMax: $budgetPxMax')
          ..write(')'))
        .toString();
  }
}

class $BuildsTable extends Builds with TableInfo<$BuildsTable, BuildRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BuildsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _isoMd5Meta = const VerificationMeta('isoMd5');
  @override
  late final GeneratedColumn<String> isoMd5 = GeneratedColumn<String>(
      'iso_md5', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tdbRevisionMeta =
      const VerificationMeta('tdbRevision');
  @override
  late final GeneratedColumn<int> tdbRevision = GeneratedColumn<int>(
      'tdb_revision', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _toolkitVersionMeta =
      const VerificationMeta('toolkitVersion');
  @override
  late final GeneratedColumn<String> toolkitVersion = GeneratedColumn<String>(
      'toolkit_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _profileMeta =
      const VerificationMeta('profile');
  @override
  late final GeneratedColumn<String> profile = GeneratedColumn<String>(
      'profile', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reportJsonMeta =
      const VerificationMeta('reportJson');
  @override
  late final GeneratedColumn<String> reportJson = GeneratedColumn<String>(
      'report_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        isoMd5,
        tdbRevision,
        toolkitVersion,
        profile,
        status,
        reportJson,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'build';
  @override
  VerificationContext validateIntegrity(Insertable<BuildRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('iso_md5')) {
      context.handle(_isoMd5Meta,
          isoMd5.isAcceptableOrUnknown(data['iso_md5']!, _isoMd5Meta));
    } else if (isInserting) {
      context.missing(_isoMd5Meta);
    }
    if (data.containsKey('tdb_revision')) {
      context.handle(
          _tdbRevisionMeta,
          tdbRevision.isAcceptableOrUnknown(
              data['tdb_revision']!, _tdbRevisionMeta));
    } else if (isInserting) {
      context.missing(_tdbRevisionMeta);
    }
    if (data.containsKey('toolkit_version')) {
      context.handle(
          _toolkitVersionMeta,
          toolkitVersion.isAcceptableOrUnknown(
              data['toolkit_version']!, _toolkitVersionMeta));
    } else if (isInserting) {
      context.missing(_toolkitVersionMeta);
    }
    if (data.containsKey('profile')) {
      context.handle(_profileMeta,
          profile.isAcceptableOrUnknown(data['profile']!, _profileMeta));
    } else if (isInserting) {
      context.missing(_profileMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('report_json')) {
      context.handle(
          _reportJsonMeta,
          reportJson.isAcceptableOrUnknown(
              data['report_json']!, _reportJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BuildRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BuildRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      isoMd5: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}iso_md5'])!,
      tdbRevision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tdb_revision'])!,
      toolkitVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}toolkit_version'])!,
      profile: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}profile'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      reportJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}report_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $BuildsTable createAlias(String alias) {
    return $BuildsTable(attachedDatabase, alias);
  }
}

class BuildRow extends DataClass implements Insertable<BuildRow> {
  final int id;
  final String isoMd5;
  final int tdbRevision;
  final String toolkitVersion;
  final String profile;
  final String status;

  /// Rapport JSON sérialisé (docs/ARCHITECTURE.md §8.6).
  final String? reportJson;
  final DateTime createdAt;
  const BuildRow(
      {required this.id,
      required this.isoMd5,
      required this.tdbRevision,
      required this.toolkitVersion,
      required this.profile,
      required this.status,
      this.reportJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['iso_md5'] = Variable<String>(isoMd5);
    map['tdb_revision'] = Variable<int>(tdbRevision);
    map['toolkit_version'] = Variable<String>(toolkitVersion);
    map['profile'] = Variable<String>(profile);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || reportJson != null) {
      map['report_json'] = Variable<String>(reportJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BuildsCompanion toCompanion(bool nullToAbsent) {
    return BuildsCompanion(
      id: Value(id),
      isoMd5: Value(isoMd5),
      tdbRevision: Value(tdbRevision),
      toolkitVersion: Value(toolkitVersion),
      profile: Value(profile),
      status: Value(status),
      reportJson: reportJson == null && nullToAbsent
          ? const Value.absent()
          : Value(reportJson),
      createdAt: Value(createdAt),
    );
  }

  factory BuildRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BuildRow(
      id: serializer.fromJson<int>(json['id']),
      isoMd5: serializer.fromJson<String>(json['isoMd5']),
      tdbRevision: serializer.fromJson<int>(json['tdbRevision']),
      toolkitVersion: serializer.fromJson<String>(json['toolkitVersion']),
      profile: serializer.fromJson<String>(json['profile']),
      status: serializer.fromJson<String>(json['status']),
      reportJson: serializer.fromJson<String?>(json['reportJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'isoMd5': serializer.toJson<String>(isoMd5),
      'tdbRevision': serializer.toJson<int>(tdbRevision),
      'toolkitVersion': serializer.toJson<String>(toolkitVersion),
      'profile': serializer.toJson<String>(profile),
      'status': serializer.toJson<String>(status),
      'reportJson': serializer.toJson<String?>(reportJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BuildRow copyWith(
          {int? id,
          String? isoMd5,
          int? tdbRevision,
          String? toolkitVersion,
          String? profile,
          String? status,
          Value<String?> reportJson = const Value.absent(),
          DateTime? createdAt}) =>
      BuildRow(
        id: id ?? this.id,
        isoMd5: isoMd5 ?? this.isoMd5,
        tdbRevision: tdbRevision ?? this.tdbRevision,
        toolkitVersion: toolkitVersion ?? this.toolkitVersion,
        profile: profile ?? this.profile,
        status: status ?? this.status,
        reportJson: reportJson.present ? reportJson.value : this.reportJson,
        createdAt: createdAt ?? this.createdAt,
      );
  BuildRow copyWithCompanion(BuildsCompanion data) {
    return BuildRow(
      id: data.id.present ? data.id.value : this.id,
      isoMd5: data.isoMd5.present ? data.isoMd5.value : this.isoMd5,
      tdbRevision:
          data.tdbRevision.present ? data.tdbRevision.value : this.tdbRevision,
      toolkitVersion: data.toolkitVersion.present
          ? data.toolkitVersion.value
          : this.toolkitVersion,
      profile: data.profile.present ? data.profile.value : this.profile,
      status: data.status.present ? data.status.value : this.status,
      reportJson:
          data.reportJson.present ? data.reportJson.value : this.reportJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BuildRow(')
          ..write('id: $id, ')
          ..write('isoMd5: $isoMd5, ')
          ..write('tdbRevision: $tdbRevision, ')
          ..write('toolkitVersion: $toolkitVersion, ')
          ..write('profile: $profile, ')
          ..write('status: $status, ')
          ..write('reportJson: $reportJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, isoMd5, tdbRevision, toolkitVersion,
      profile, status, reportJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BuildRow &&
          other.id == this.id &&
          other.isoMd5 == this.isoMd5 &&
          other.tdbRevision == this.tdbRevision &&
          other.toolkitVersion == this.toolkitVersion &&
          other.profile == this.profile &&
          other.status == this.status &&
          other.reportJson == this.reportJson &&
          other.createdAt == this.createdAt);
}

class BuildsCompanion extends UpdateCompanion<BuildRow> {
  final Value<int> id;
  final Value<String> isoMd5;
  final Value<int> tdbRevision;
  final Value<String> toolkitVersion;
  final Value<String> profile;
  final Value<String> status;
  final Value<String?> reportJson;
  final Value<DateTime> createdAt;
  const BuildsCompanion({
    this.id = const Value.absent(),
    this.isoMd5 = const Value.absent(),
    this.tdbRevision = const Value.absent(),
    this.toolkitVersion = const Value.absent(),
    this.profile = const Value.absent(),
    this.status = const Value.absent(),
    this.reportJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BuildsCompanion.insert({
    this.id = const Value.absent(),
    required String isoMd5,
    required int tdbRevision,
    required String toolkitVersion,
    required String profile,
    required String status,
    this.reportJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : isoMd5 = Value(isoMd5),
        tdbRevision = Value(tdbRevision),
        toolkitVersion = Value(toolkitVersion),
        profile = Value(profile),
        status = Value(status);
  static Insertable<BuildRow> custom({
    Expression<int>? id,
    Expression<String>? isoMd5,
    Expression<int>? tdbRevision,
    Expression<String>? toolkitVersion,
    Expression<String>? profile,
    Expression<String>? status,
    Expression<String>? reportJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isoMd5 != null) 'iso_md5': isoMd5,
      if (tdbRevision != null) 'tdb_revision': tdbRevision,
      if (toolkitVersion != null) 'toolkit_version': toolkitVersion,
      if (profile != null) 'profile': profile,
      if (status != null) 'status': status,
      if (reportJson != null) 'report_json': reportJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BuildsCompanion copyWith(
      {Value<int>? id,
      Value<String>? isoMd5,
      Value<int>? tdbRevision,
      Value<String>? toolkitVersion,
      Value<String>? profile,
      Value<String>? status,
      Value<String?>? reportJson,
      Value<DateTime>? createdAt}) {
    return BuildsCompanion(
      id: id ?? this.id,
      isoMd5: isoMd5 ?? this.isoMd5,
      tdbRevision: tdbRevision ?? this.tdbRevision,
      toolkitVersion: toolkitVersion ?? this.toolkitVersion,
      profile: profile ?? this.profile,
      status: status ?? this.status,
      reportJson: reportJson ?? this.reportJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (isoMd5.present) {
      map['iso_md5'] = Variable<String>(isoMd5.value);
    }
    if (tdbRevision.present) {
      map['tdb_revision'] = Variable<int>(tdbRevision.value);
    }
    if (toolkitVersion.present) {
      map['toolkit_version'] = Variable<String>(toolkitVersion.value);
    }
    if (profile.present) {
      map['profile'] = Variable<String>(profile.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (reportJson.present) {
      map['report_json'] = Variable<String>(reportJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BuildsCompanion(')
          ..write('id: $id, ')
          ..write('isoMd5: $isoMd5, ')
          ..write('tdbRevision: $tdbRevision, ')
          ..write('toolkitVersion: $toolkitVersion, ')
          ..write('profile: $profile, ')
          ..write('status: $status, ')
          ..write('reportJson: $reportJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$TdbDatabase extends GeneratedDatabase {
  _$TdbDatabase(QueryExecutor e) : super(e);
  $TdbDatabaseManager get managers => $TdbDatabaseManager(this);
  late final $GameFilesTable gameFiles = $GameFilesTable(this);
  late final $SourceStringsTable sourceStrings = $SourceStringsTable(this);
  late final $TranslationsTable translations = $TranslationsTable(this);
  late final $BuildsTable builds = $BuildsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [gameFiles, sourceStrings, translations, builds];
}

typedef $$GameFilesTableCreateCompanionBuilder = GameFilesCompanion Function({
  Value<int> id,
  required String versionId,
  required String codec,
  required int lba,
  required int slotBytes,
  required int origBytes,
  Value<String?> label,
  Value<String?> contextProfile,
});
typedef $$GameFilesTableUpdateCompanionBuilder = GameFilesCompanion Function({
  Value<int> id,
  Value<String> versionId,
  Value<String> codec,
  Value<int> lba,
  Value<int> slotBytes,
  Value<int> origBytes,
  Value<String?> label,
  Value<String?> contextProfile,
});

final class $$GameFilesTableReferences
    extends BaseReferences<_$TdbDatabase, $GameFilesTable, GameFileRow> {
  $$GameFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SourceStringsTable, List<SourceStringRow>>
      _sourceStringsRefsTable(_$TdbDatabase db) =>
          MultiTypedResultKey.fromTable(db.sourceStrings,
              aliasName: $_aliasNameGenerator(
                  db.gameFiles.id, db.sourceStrings.fileId));

  $$SourceStringsTableProcessedTableManager get sourceStringsRefs {
    final manager = $$SourceStringsTableTableManager($_db, $_db.sourceStrings)
        .filter((f) => f.fileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourceStringsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$GameFilesTableFilterComposer
    extends Composer<_$TdbDatabase, $GameFilesTable> {
  $$GameFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionId => $composableBuilder(
      column: $table.versionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get codec => $composableBuilder(
      column: $table.codec, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lba => $composableBuilder(
      column: $table.lba, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get slotBytes => $composableBuilder(
      column: $table.slotBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get origBytes => $composableBuilder(
      column: $table.origBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextProfile => $composableBuilder(
      column: $table.contextProfile,
      builder: (column) => ColumnFilters(column));

  Expression<bool> sourceStringsRefs(
      Expression<bool> Function($$SourceStringsTableFilterComposer f) f) {
    final $$SourceStringsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sourceStrings,
        getReferencedColumn: (t) => t.fileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SourceStringsTableFilterComposer(
              $db: $db,
              $table: $db.sourceStrings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$GameFilesTableOrderingComposer
    extends Composer<_$TdbDatabase, $GameFilesTable> {
  $$GameFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionId => $composableBuilder(
      column: $table.versionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get codec => $composableBuilder(
      column: $table.codec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lba => $composableBuilder(
      column: $table.lba, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get slotBytes => $composableBuilder(
      column: $table.slotBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get origBytes => $composableBuilder(
      column: $table.origBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextProfile => $composableBuilder(
      column: $table.contextProfile,
      builder: (column) => ColumnOrderings(column));
}

class $$GameFilesTableAnnotationComposer
    extends Composer<_$TdbDatabase, $GameFilesTable> {
  $$GameFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get codec =>
      $composableBuilder(column: $table.codec, builder: (column) => column);

  GeneratedColumn<int> get lba =>
      $composableBuilder(column: $table.lba, builder: (column) => column);

  GeneratedColumn<int> get slotBytes =>
      $composableBuilder(column: $table.slotBytes, builder: (column) => column);

  GeneratedColumn<int> get origBytes =>
      $composableBuilder(column: $table.origBytes, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get contextProfile => $composableBuilder(
      column: $table.contextProfile, builder: (column) => column);

  Expression<T> sourceStringsRefs<T extends Object>(
      Expression<T> Function($$SourceStringsTableAnnotationComposer a) f) {
    final $$SourceStringsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sourceStrings,
        getReferencedColumn: (t) => t.fileId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SourceStringsTableAnnotationComposer(
              $db: $db,
              $table: $db.sourceStrings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$GameFilesTableTableManager extends RootTableManager<
    _$TdbDatabase,
    $GameFilesTable,
    GameFileRow,
    $$GameFilesTableFilterComposer,
    $$GameFilesTableOrderingComposer,
    $$GameFilesTableAnnotationComposer,
    $$GameFilesTableCreateCompanionBuilder,
    $$GameFilesTableUpdateCompanionBuilder,
    (GameFileRow, $$GameFilesTableReferences),
    GameFileRow,
    PrefetchHooks Function({bool sourceStringsRefs})> {
  $$GameFilesTableTableManager(_$TdbDatabase db, $GameFilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> versionId = const Value.absent(),
            Value<String> codec = const Value.absent(),
            Value<int> lba = const Value.absent(),
            Value<int> slotBytes = const Value.absent(),
            Value<int> origBytes = const Value.absent(),
            Value<String?> label = const Value.absent(),
            Value<String?> contextProfile = const Value.absent(),
          }) =>
              GameFilesCompanion(
            id: id,
            versionId: versionId,
            codec: codec,
            lba: lba,
            slotBytes: slotBytes,
            origBytes: origBytes,
            label: label,
            contextProfile: contextProfile,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String versionId,
            required String codec,
            required int lba,
            required int slotBytes,
            required int origBytes,
            Value<String?> label = const Value.absent(),
            Value<String?> contextProfile = const Value.absent(),
          }) =>
              GameFilesCompanion.insert(
            id: id,
            versionId: versionId,
            codec: codec,
            lba: lba,
            slotBytes: slotBytes,
            origBytes: origBytes,
            label: label,
            contextProfile: contextProfile,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$GameFilesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sourceStringsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sourceStringsRefs) db.sourceStrings
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sourceStringsRefs)
                    await $_getPrefetchedData<GameFileRow, $GameFilesTable,
                            SourceStringRow>(
                        currentTable: table,
                        referencedTable: $$GameFilesTableReferences
                            ._sourceStringsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$GameFilesTableReferences(db, table, p0)
                                .sourceStringsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.fileId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$GameFilesTableProcessedTableManager = ProcessedTableManager<
    _$TdbDatabase,
    $GameFilesTable,
    GameFileRow,
    $$GameFilesTableFilterComposer,
    $$GameFilesTableOrderingComposer,
    $$GameFilesTableAnnotationComposer,
    $$GameFilesTableCreateCompanionBuilder,
    $$GameFilesTableUpdateCompanionBuilder,
    (GameFileRow, $$GameFilesTableReferences),
    GameFileRow,
    PrefetchHooks Function({bool sourceStringsRefs})>;
typedef $$SourceStringsTableCreateCompanionBuilder = SourceStringsCompanion
    Function({
  Value<int> id,
  required int fileId,
  required int tableIdx,
  required int slotIdx,
  required String sourceHash,
  required String sourceText,
  Value<int?> aliasOf,
  Value<String?> contextProfile,
});
typedef $$SourceStringsTableUpdateCompanionBuilder = SourceStringsCompanion
    Function({
  Value<int> id,
  Value<int> fileId,
  Value<int> tableIdx,
  Value<int> slotIdx,
  Value<String> sourceHash,
  Value<String> sourceText,
  Value<int?> aliasOf,
  Value<String?> contextProfile,
});

final class $$SourceStringsTableReferences extends BaseReferences<_$TdbDatabase,
    $SourceStringsTable, SourceStringRow> {
  $$SourceStringsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $GameFilesTable _fileIdTable(_$TdbDatabase db) =>
      db.gameFiles.createAlias(
          $_aliasNameGenerator(db.sourceStrings.fileId, db.gameFiles.id));

  $$GameFilesTableProcessedTableManager get fileId {
    final $_column = $_itemColumn<int>('file_id')!;

    final manager = $$GameFilesTableTableManager($_db, $_db.gameFiles)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$TranslationsTable, List<TranslationRow>>
      _translationsRefsTable(_$TdbDatabase db) =>
          MultiTypedResultKey.fromTable(db.translations,
              aliasName: $_aliasNameGenerator(
                  db.sourceStrings.id, db.translations.sourceId));

  $$TranslationsTableProcessedTableManager get translationsRefs {
    final manager = $$TranslationsTableTableManager($_db, $_db.translations)
        .filter((f) => f.sourceId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_translationsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SourceStringsTableFilterComposer
    extends Composer<_$TdbDatabase, $SourceStringsTable> {
  $$SourceStringsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tableIdx => $composableBuilder(
      column: $table.tableIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get slotIdx => $composableBuilder(
      column: $table.slotIdx, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceHash => $composableBuilder(
      column: $table.sourceHash, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceText => $composableBuilder(
      column: $table.sourceText, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get aliasOf => $composableBuilder(
      column: $table.aliasOf, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextProfile => $composableBuilder(
      column: $table.contextProfile,
      builder: (column) => ColumnFilters(column));

  $$GameFilesTableFilterComposer get fileId {
    final $$GameFilesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.fileId,
        referencedTable: $db.gameFiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GameFilesTableFilterComposer(
              $db: $db,
              $table: $db.gameFiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> translationsRefs(
      Expression<bool> Function($$TranslationsTableFilterComposer f) f) {
    final $$TranslationsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.translations,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranslationsTableFilterComposer(
              $db: $db,
              $table: $db.translations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SourceStringsTableOrderingComposer
    extends Composer<_$TdbDatabase, $SourceStringsTable> {
  $$SourceStringsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tableIdx => $composableBuilder(
      column: $table.tableIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get slotIdx => $composableBuilder(
      column: $table.slotIdx, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceHash => $composableBuilder(
      column: $table.sourceHash, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceText => $composableBuilder(
      column: $table.sourceText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get aliasOf => $composableBuilder(
      column: $table.aliasOf, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextProfile => $composableBuilder(
      column: $table.contextProfile,
      builder: (column) => ColumnOrderings(column));

  $$GameFilesTableOrderingComposer get fileId {
    final $$GameFilesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.fileId,
        referencedTable: $db.gameFiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GameFilesTableOrderingComposer(
              $db: $db,
              $table: $db.gameFiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SourceStringsTableAnnotationComposer
    extends Composer<_$TdbDatabase, $SourceStringsTable> {
  $$SourceStringsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get tableIdx =>
      $composableBuilder(column: $table.tableIdx, builder: (column) => column);

  GeneratedColumn<int> get slotIdx =>
      $composableBuilder(column: $table.slotIdx, builder: (column) => column);

  GeneratedColumn<String> get sourceHash => $composableBuilder(
      column: $table.sourceHash, builder: (column) => column);

  GeneratedColumn<String> get sourceText => $composableBuilder(
      column: $table.sourceText, builder: (column) => column);

  GeneratedColumn<int> get aliasOf =>
      $composableBuilder(column: $table.aliasOf, builder: (column) => column);

  GeneratedColumn<String> get contextProfile => $composableBuilder(
      column: $table.contextProfile, builder: (column) => column);

  $$GameFilesTableAnnotationComposer get fileId {
    final $$GameFilesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.fileId,
        referencedTable: $db.gameFiles,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$GameFilesTableAnnotationComposer(
              $db: $db,
              $table: $db.gameFiles,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> translationsRefs<T extends Object>(
      Expression<T> Function($$TranslationsTableAnnotationComposer a) f) {
    final $$TranslationsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.translations,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TranslationsTableAnnotationComposer(
              $db: $db,
              $table: $db.translations,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SourceStringsTableTableManager extends RootTableManager<
    _$TdbDatabase,
    $SourceStringsTable,
    SourceStringRow,
    $$SourceStringsTableFilterComposer,
    $$SourceStringsTableOrderingComposer,
    $$SourceStringsTableAnnotationComposer,
    $$SourceStringsTableCreateCompanionBuilder,
    $$SourceStringsTableUpdateCompanionBuilder,
    (SourceStringRow, $$SourceStringsTableReferences),
    SourceStringRow,
    PrefetchHooks Function({bool fileId, bool translationsRefs})> {
  $$SourceStringsTableTableManager(_$TdbDatabase db, $SourceStringsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceStringsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceStringsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceStringsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> fileId = const Value.absent(),
            Value<int> tableIdx = const Value.absent(),
            Value<int> slotIdx = const Value.absent(),
            Value<String> sourceHash = const Value.absent(),
            Value<String> sourceText = const Value.absent(),
            Value<int?> aliasOf = const Value.absent(),
            Value<String?> contextProfile = const Value.absent(),
          }) =>
              SourceStringsCompanion(
            id: id,
            fileId: fileId,
            tableIdx: tableIdx,
            slotIdx: slotIdx,
            sourceHash: sourceHash,
            sourceText: sourceText,
            aliasOf: aliasOf,
            contextProfile: contextProfile,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int fileId,
            required int tableIdx,
            required int slotIdx,
            required String sourceHash,
            required String sourceText,
            Value<int?> aliasOf = const Value.absent(),
            Value<String?> contextProfile = const Value.absent(),
          }) =>
              SourceStringsCompanion.insert(
            id: id,
            fileId: fileId,
            tableIdx: tableIdx,
            slotIdx: slotIdx,
            sourceHash: sourceHash,
            sourceText: sourceText,
            aliasOf: aliasOf,
            contextProfile: contextProfile,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SourceStringsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({fileId = false, translationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (translationsRefs) db.translations],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (fileId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.fileId,
                    referencedTable:
                        $$SourceStringsTableReferences._fileIdTable(db),
                    referencedColumn:
                        $$SourceStringsTableReferences._fileIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (translationsRefs)
                    await $_getPrefetchedData<SourceStringRow,
                            $SourceStringsTable, TranslationRow>(
                        currentTable: table,
                        referencedTable: $$SourceStringsTableReferences
                            ._translationsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SourceStringsTableReferences(db, table, p0)
                                .translationsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.sourceId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SourceStringsTableProcessedTableManager = ProcessedTableManager<
    _$TdbDatabase,
    $SourceStringsTable,
    SourceStringRow,
    $$SourceStringsTableFilterComposer,
    $$SourceStringsTableOrderingComposer,
    $$SourceStringsTableAnnotationComposer,
    $$SourceStringsTableCreateCompanionBuilder,
    $$SourceStringsTableUpdateCompanionBuilder,
    (SourceStringRow, $$SourceStringsTableReferences),
    SourceStringRow,
    PrefetchHooks Function({bool fileId, bool translationsRefs})>;
typedef $$TranslationsTableCreateCompanionBuilder = TranslationsCompanion
    Function({
  Value<int> id,
  required int sourceId,
  required String locale,
  required String text_,
  required String status,
  Value<int> revision,
  Value<String?> authorId,
  Value<DateTime> updatedAt,
  Value<int?> budgetBytes,
  Value<int?> budgetPxMax,
});
typedef $$TranslationsTableUpdateCompanionBuilder = TranslationsCompanion
    Function({
  Value<int> id,
  Value<int> sourceId,
  Value<String> locale,
  Value<String> text_,
  Value<String> status,
  Value<int> revision,
  Value<String?> authorId,
  Value<DateTime> updatedAt,
  Value<int?> budgetBytes,
  Value<int?> budgetPxMax,
});

final class $$TranslationsTableReferences
    extends BaseReferences<_$TdbDatabase, $TranslationsTable, TranslationRow> {
  $$TranslationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SourceStringsTable _sourceIdTable(_$TdbDatabase db) =>
      db.sourceStrings.createAlias(
          $_aliasNameGenerator(db.translations.sourceId, db.sourceStrings.id));

  $$SourceStringsTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<int>('source_id')!;

    final manager = $$SourceStringsTableTableManager($_db, $_db.sourceStrings)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$TranslationsTableFilterComposer
    extends Composer<_$TdbDatabase, $TranslationsTable> {
  $$TranslationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locale => $composableBuilder(
      column: $table.locale, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get text_ => $composableBuilder(
      column: $table.text_, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorId => $composableBuilder(
      column: $table.authorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get budgetBytes => $composableBuilder(
      column: $table.budgetBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get budgetPxMax => $composableBuilder(
      column: $table.budgetPxMax, builder: (column) => ColumnFilters(column));

  $$SourceStringsTableFilterComposer get sourceId {
    final $$SourceStringsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.sourceStrings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SourceStringsTableFilterComposer(
              $db: $db,
              $table: $db.sourceStrings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranslationsTableOrderingComposer
    extends Composer<_$TdbDatabase, $TranslationsTable> {
  $$TranslationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locale => $composableBuilder(
      column: $table.locale, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get text_ => $composableBuilder(
      column: $table.text_, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorId => $composableBuilder(
      column: $table.authorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get budgetBytes => $composableBuilder(
      column: $table.budgetBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get budgetPxMax => $composableBuilder(
      column: $table.budgetPxMax, builder: (column) => ColumnOrderings(column));

  $$SourceStringsTableOrderingComposer get sourceId {
    final $$SourceStringsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.sourceStrings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SourceStringsTableOrderingComposer(
              $db: $db,
              $table: $db.sourceStrings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranslationsTableAnnotationComposer
    extends Composer<_$TdbDatabase, $TranslationsTable> {
  $$TranslationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  GeneratedColumn<String> get text_ =>
      $composableBuilder(column: $table.text_, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get authorId =>
      $composableBuilder(column: $table.authorId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get budgetBytes => $composableBuilder(
      column: $table.budgetBytes, builder: (column) => column);

  GeneratedColumn<int> get budgetPxMax => $composableBuilder(
      column: $table.budgetPxMax, builder: (column) => column);

  $$SourceStringsTableAnnotationComposer get sourceId {
    final $$SourceStringsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.sourceStrings,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SourceStringsTableAnnotationComposer(
              $db: $db,
              $table: $db.sourceStrings,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$TranslationsTableTableManager extends RootTableManager<
    _$TdbDatabase,
    $TranslationsTable,
    TranslationRow,
    $$TranslationsTableFilterComposer,
    $$TranslationsTableOrderingComposer,
    $$TranslationsTableAnnotationComposer,
    $$TranslationsTableCreateCompanionBuilder,
    $$TranslationsTableUpdateCompanionBuilder,
    (TranslationRow, $$TranslationsTableReferences),
    TranslationRow,
    PrefetchHooks Function({bool sourceId})> {
  $$TranslationsTableTableManager(_$TdbDatabase db, $TranslationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranslationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranslationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sourceId = const Value.absent(),
            Value<String> locale = const Value.absent(),
            Value<String> text_ = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String?> authorId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int?> budgetBytes = const Value.absent(),
            Value<int?> budgetPxMax = const Value.absent(),
          }) =>
              TranslationsCompanion(
            id: id,
            sourceId: sourceId,
            locale: locale,
            text_: text_,
            status: status,
            revision: revision,
            authorId: authorId,
            updatedAt: updatedAt,
            budgetBytes: budgetBytes,
            budgetPxMax: budgetPxMax,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sourceId,
            required String locale,
            required String text_,
            required String status,
            Value<int> revision = const Value.absent(),
            Value<String?> authorId = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int?> budgetBytes = const Value.absent(),
            Value<int?> budgetPxMax = const Value.absent(),
          }) =>
              TranslationsCompanion.insert(
            id: id,
            sourceId: sourceId,
            locale: locale,
            text_: text_,
            status: status,
            revision: revision,
            authorId: authorId,
            updatedAt: updatedAt,
            budgetBytes: budgetBytes,
            budgetPxMax: budgetPxMax,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$TranslationsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sourceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sourceId,
                    referencedTable:
                        $$TranslationsTableReferences._sourceIdTable(db),
                    referencedColumn:
                        $$TranslationsTableReferences._sourceIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$TranslationsTableProcessedTableManager = ProcessedTableManager<
    _$TdbDatabase,
    $TranslationsTable,
    TranslationRow,
    $$TranslationsTableFilterComposer,
    $$TranslationsTableOrderingComposer,
    $$TranslationsTableAnnotationComposer,
    $$TranslationsTableCreateCompanionBuilder,
    $$TranslationsTableUpdateCompanionBuilder,
    (TranslationRow, $$TranslationsTableReferences),
    TranslationRow,
    PrefetchHooks Function({bool sourceId})>;
typedef $$BuildsTableCreateCompanionBuilder = BuildsCompanion Function({
  Value<int> id,
  required String isoMd5,
  required int tdbRevision,
  required String toolkitVersion,
  required String profile,
  required String status,
  Value<String?> reportJson,
  Value<DateTime> createdAt,
});
typedef $$BuildsTableUpdateCompanionBuilder = BuildsCompanion Function({
  Value<int> id,
  Value<String> isoMd5,
  Value<int> tdbRevision,
  Value<String> toolkitVersion,
  Value<String> profile,
  Value<String> status,
  Value<String?> reportJson,
  Value<DateTime> createdAt,
});

class $$BuildsTableFilterComposer
    extends Composer<_$TdbDatabase, $BuildsTable> {
  $$BuildsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get isoMd5 => $composableBuilder(
      column: $table.isoMd5, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tdbRevision => $composableBuilder(
      column: $table.tdbRevision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toolkitVersion => $composableBuilder(
      column: $table.toolkitVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get profile => $composableBuilder(
      column: $table.profile, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reportJson => $composableBuilder(
      column: $table.reportJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$BuildsTableOrderingComposer
    extends Composer<_$TdbDatabase, $BuildsTable> {
  $$BuildsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get isoMd5 => $composableBuilder(
      column: $table.isoMd5, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tdbRevision => $composableBuilder(
      column: $table.tdbRevision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toolkitVersion => $composableBuilder(
      column: $table.toolkitVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get profile => $composableBuilder(
      column: $table.profile, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reportJson => $composableBuilder(
      column: $table.reportJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$BuildsTableAnnotationComposer
    extends Composer<_$TdbDatabase, $BuildsTable> {
  $$BuildsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get isoMd5 =>
      $composableBuilder(column: $table.isoMd5, builder: (column) => column);

  GeneratedColumn<int> get tdbRevision => $composableBuilder(
      column: $table.tdbRevision, builder: (column) => column);

  GeneratedColumn<String> get toolkitVersion => $composableBuilder(
      column: $table.toolkitVersion, builder: (column) => column);

  GeneratedColumn<String> get profile =>
      $composableBuilder(column: $table.profile, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get reportJson => $composableBuilder(
      column: $table.reportJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BuildsTableTableManager extends RootTableManager<
    _$TdbDatabase,
    $BuildsTable,
    BuildRow,
    $$BuildsTableFilterComposer,
    $$BuildsTableOrderingComposer,
    $$BuildsTableAnnotationComposer,
    $$BuildsTableCreateCompanionBuilder,
    $$BuildsTableUpdateCompanionBuilder,
    (BuildRow, BaseReferences<_$TdbDatabase, $BuildsTable, BuildRow>),
    BuildRow,
    PrefetchHooks Function()> {
  $$BuildsTableTableManager(_$TdbDatabase db, $BuildsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BuildsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BuildsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BuildsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> isoMd5 = const Value.absent(),
            Value<int> tdbRevision = const Value.absent(),
            Value<String> toolkitVersion = const Value.absent(),
            Value<String> profile = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> reportJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              BuildsCompanion(
            id: id,
            isoMd5: isoMd5,
            tdbRevision: tdbRevision,
            toolkitVersion: toolkitVersion,
            profile: profile,
            status: status,
            reportJson: reportJson,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String isoMd5,
            required int tdbRevision,
            required String toolkitVersion,
            required String profile,
            required String status,
            Value<String?> reportJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              BuildsCompanion.insert(
            id: id,
            isoMd5: isoMd5,
            tdbRevision: tdbRevision,
            toolkitVersion: toolkitVersion,
            profile: profile,
            status: status,
            reportJson: reportJson,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BuildsTableProcessedTableManager = ProcessedTableManager<
    _$TdbDatabase,
    $BuildsTable,
    BuildRow,
    $$BuildsTableFilterComposer,
    $$BuildsTableOrderingComposer,
    $$BuildsTableAnnotationComposer,
    $$BuildsTableCreateCompanionBuilder,
    $$BuildsTableUpdateCompanionBuilder,
    (BuildRow, BaseReferences<_$TdbDatabase, $BuildsTable, BuildRow>),
    BuildRow,
    PrefetchHooks Function()>;

class $TdbDatabaseManager {
  final _$TdbDatabase _db;
  $TdbDatabaseManager(this._db);
  $$GameFilesTableTableManager get gameFiles =>
      $$GameFilesTableTableManager(_db, _db.gameFiles);
  $$SourceStringsTableTableManager get sourceStrings =>
      $$SourceStringsTableTableManager(_db, _db.sourceStrings);
  $$TranslationsTableTableManager get translations =>
      $$TranslationsTableTableManager(_db, _db.translations);
  $$BuildsTableTableManager get builds =>
      $$BuildsTableTableManager(_db, _db.builds);
}
