// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PrefsTable extends Prefs with TableInfo<$PrefsTable, Pref> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prefs';
  @override
  VerificationContext validateIntegrity(Insertable<Pref> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pref map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pref(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $PrefsTable createAlias(String alias) {
    return $PrefsTable(attachedDatabase, alias);
  }
}

class Pref extends DataClass implements Insertable<Pref> {
  final String id;
  final String hlc;
  final bool deleted;
  final String value;
  const Pref({required this.id, required this.hlc, required this.deleted, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['value'] = Variable<String>(value);
    return map;
  }

  PrefsCompanion toCompanion(bool nullToAbsent) {
    return PrefsCompanion(id: Value(id), hlc: Value(hlc), deleted: Value(deleted), value: Value(value));
  }

  factory Pref.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pref(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'value': serializer.toJson<String>(value),
    };
  }

  Pref copyWith({String? id, String? hlc, bool? deleted, String? value}) => Pref(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    value: value ?? this.value,
  );
  Pref copyWithCompanion(PrefsCompanion data) {
    return Pref(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pref(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pref &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.value == this.value);
}

class PrefsCompanion extends UpdateCompanion<Pref> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> value;
  final Value<int> rowid;
  const PrefsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrefsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String value,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       value = Value(value);
  static Insertable<Pref> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrefsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PrefsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrefsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, rowId, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxItem> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(_entityMeta, entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(_rowIdMeta, rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta));
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, rowId};
  @override
  OutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItem(
      entity: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      rowId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}row_id'])!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq']),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxItem extends DataClass implements Insertable<OutboxItem> {
  final String entity;
  final String rowId;
  final int? seq;
  const OutboxItem({required this.entity, required this.rowId, this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['row_id'] = Variable<String>(rowId);
    if (!nullToAbsent || seq != null) {
      map['seq'] = Variable<int>(seq);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      entity: Value(entity),
      rowId: Value(rowId),
      seq: seq == null && nullToAbsent ? const Value.absent() : Value(seq),
    );
  }

  factory OutboxItem.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxItem(
      entity: serializer.fromJson<String>(json['entity']),
      rowId: serializer.fromJson<String>(json['rowId']),
      seq: serializer.fromJson<int?>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'rowId': serializer.toJson<String>(rowId),
      'seq': serializer.toJson<int?>(seq),
    };
  }

  OutboxItem copyWith({String? entity, String? rowId, Value<int?> seq = const Value.absent()}) => OutboxItem(
    entity: entity ?? this.entity,
    rowId: rowId ?? this.rowId,
    seq: seq.present ? seq.value : this.seq,
  );
  OutboxItem copyWithCompanion(OutboxCompanion data) {
    return OutboxItem(
      entity: data.entity.present ? data.entity.value : this.entity,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItem(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, rowId, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxItem &&
          other.entity == this.entity &&
          other.rowId == this.rowId &&
          other.seq == this.seq);
}

class OutboxCompanion extends UpdateCompanion<OutboxItem> {
  final Value<String> entity;
  final Value<String> rowId;
  final Value<int?> seq;
  final Value<int> rowid;
  const OutboxCompanion({
    this.entity = const Value.absent(),
    this.rowId = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String entity,
    required String rowId,
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       rowId = Value(rowId);
  static Insertable<OutboxItem> custom({
    Expression<String>? entity,
    Expression<String>? rowId,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (rowId != null) 'row_id': rowId,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? entity,
    Value<String>? rowId,
    Value<int?>? seq,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      entity: entity ?? this.entity,
      rowId: rowId ?? this.rowId,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [deviceId, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<SyncCursor> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta, deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      deviceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String deviceId;
  final int seq;
  const SyncCursor({required this.deviceId, required this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['seq'] = Variable<int>(seq);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(deviceId: Value(deviceId), seq: Value(seq));
  }

  factory SyncCursor.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'seq': serializer.toJson<int>(seq),
    };
  }

  SyncCursor copyWith({String? deviceId, int? seq}) =>
      SyncCursor(deviceId: deviceId ?? this.deviceId, seq: seq ?? this.seq);
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('deviceId: $deviceId, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor && other.deviceId == this.deviceId && other.seq == this.seq);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> deviceId;
  final Value<int> seq;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.deviceId = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({required String deviceId, required int seq, this.rowid = const Value.absent()})
    : deviceId = Value(deviceId),
      seq = Value(seq);
  static Insertable<SyncCursor> custom({
    Expression<String>? deviceId,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({Value<String>? deviceId, Value<int>? seq, Value<int>? rowid}) {
    return SyncCursorsCompanion(
      deviceId: deviceId ?? this.deviceId,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSettingsTable extends LocalSettings with TableInfo<$LocalSettingsTable, LocalSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_settings';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSetting> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetting(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $LocalSettingsTable createAlias(String alias) {
    return $LocalSettingsTable(attachedDatabase, alias);
  }
}

class LocalSetting extends DataClass implements Insertable<LocalSetting> {
  final String key;
  final String value;
  const LocalSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory LocalSetting.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalSetting copyWith({String? key, String? value}) =>
      LocalSetting(key: key ?? this.key, value: value ?? this.value);
  LocalSetting copyWithCompanion(LocalSettingsCompanion data) {
    return LocalSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LocalSetting && other.key == this.key && other.value == this.value);
}

class LocalSettingsCompanion extends UpdateCompanion<LocalSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSettingsCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return LocalSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PrefsTable prefs = $PrefsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [prefs, outbox, syncCursors, localSettings];
}

typedef $$PrefsTableCreateCompanionBuilder = PrefsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String value,
  Value<int> rowid,
});
typedef $$PrefsTableUpdateCompanionBuilder = PrefsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> value,
  Value<int> rowid,
});

class $$PrefsTableFilterComposer extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$PrefsTableOrderingComposer extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$PrefsTableAnnotationComposer extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrefsTable,
          Pref,
          $$PrefsTableFilterComposer,
          $$PrefsTableOrderingComposer,
          $$PrefsTableAnnotationComposer,
          $$PrefsTableCreateCompanionBuilder,
          $$PrefsTableUpdateCompanionBuilder,
          (Pref, BaseReferences<_$AppDatabase, $PrefsTable, Pref>),
          Pref,
          PrefetchHooks Function()
        > {
  $$PrefsTableTableManager(_$AppDatabase db, $PrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$PrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> hlc = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PrefsCompanion(id: id, hlc: hlc, deleted: deleted, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            Value<String> hlc = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => PrefsCompanion.insert(id: id, hlc: hlc, deleted: deleted, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PrefsTable, Pref>(table),
                  BaseReferences<_$AppDatabase, $PrefsTable, Pref>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrefsTable,
      Pref,
      $$PrefsTableFilterComposer,
      $$PrefsTableOrderingComposer,
      $$PrefsTableAnnotationComposer,
      $$PrefsTableCreateCompanionBuilder,
      $$PrefsTableUpdateCompanionBuilder,
      (Pref, BaseReferences<_$AppDatabase, $PrefsTable, Pref>),
      Pref,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String entity,
  required String rowId,
  Value<int?> seq,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> entity,
  Value<String> rowId,
  Value<int?> seq,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get rowId => $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxItem,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxItem, BaseReferences<_$AppDatabase, $OutboxTable, OutboxItem>),
          OutboxItem,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entity = const Value.absent(),
            Value<String> rowId = const Value.absent(),
            Value<int?> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => OutboxCompanion(entity: entity, rowId: rowId, seq: seq, rowid: rowid),
          createCompanionCallback: ({
            required String entity,
            required String rowId,
            Value<int?> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => OutboxCompanion.insert(entity: entity, rowId: rowId, seq: seq, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxItem>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxItem>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxItem,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxItem, BaseReferences<_$AppDatabase, $OutboxTable, OutboxItem>),
      OutboxItem,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder = SyncCursorsCompanion Function({
  required String deviceId,
  required int seq,
  Value<int> rowid,
});
typedef $$SyncCursorsTableUpdateCompanionBuilder = SyncCursorsCompanion Function({
  Value<String> deviceId,
  Value<int> seq,
  Value<int> rowid,
});

class $$SyncCursorsTableFilterComposer extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $$SyncCursorsTableOrderingComposer extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $$SyncCursorsTableAnnotationComposer extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<int> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncCursorsCompanion(deviceId: deviceId, seq: seq, rowid: rowid),
          createCompanionCallback: ({
            required String deviceId,
            required int seq,
            Value<int> rowid = const Value.absent(),
          }) => SyncCursorsCompanion.insert(deviceId: deviceId, seq: seq, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$LocalSettingsTableCreateCompanionBuilder = LocalSettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$LocalSettingsTableUpdateCompanionBuilder = LocalSettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$LocalSettingsTableFilterComposer extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$LocalSettingsTableOrderingComposer extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$LocalSettingsTableAnnotationComposer extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSettingsTable,
          LocalSetting,
          $$LocalSettingsTableFilterComposer,
          $$LocalSettingsTableOrderingComposer,
          $$LocalSettingsTableAnnotationComposer,
          $$LocalSettingsTableCreateCompanionBuilder,
          $$LocalSettingsTableUpdateCompanionBuilder,
          (LocalSetting, BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>),
          LocalSetting,
          PrefetchHooks Function()
        > {
  $$LocalSettingsTableTableManager(_$AppDatabase db, $LocalSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => LocalSettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSettingsTable, LocalSetting>(table),
                  BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSettingsTable,
      LocalSetting,
      $$LocalSettingsTableFilterComposer,
      $$LocalSettingsTableOrderingComposer,
      $$LocalSettingsTableAnnotationComposer,
      $$LocalSettingsTableCreateCompanionBuilder,
      $$LocalSettingsTableUpdateCompanionBuilder,
      (LocalSetting, BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>),
      LocalSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PrefsTableTableManager get prefs => $$PrefsTableTableManager(_db, _db.prefs);
  $$OutboxTableTableManager get outbox => $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncCursorsTableTableManager get syncCursors => $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
}
