// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TaskListsTable extends TaskLists
    with TableInfo<$TaskListsTable, TaskList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    isBuiltIn,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskList(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TaskListsTable createAlias(String alias) {
    return $TaskListsTable(attachedDatabase, alias);
  }
}

class TaskList extends DataClass implements Insertable<TaskList> {
  /// 客户端生成的 UUID。见 `lib/core/utils/ids.dart`。
  final String id;
  final String name;

  /// ARGB 颜色值。`null` 表示「跟随主题」，不用颜色区分。
  ///
  /// 存 `int` 而不是十六进制字符串：省空间，并且能直接在 Dart 侧
  /// 交给 `Color(...)`，不用来回解析。
  final int? color;

  /// 是否内置清单。内置清单不允许删除，只允许改名和换色。
  final bool isBuiltIn;

  /// 排序权重，小的排前面。允许重复，重复时按名称兜底排序。
  final int sortOrder;
  final int createdAt;
  final int updatedAt;
  const TaskList({
    required this.id,
    required this.name,
    this.color,
    required this.isBuiltIn,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  TaskListsCompanion toCompanion(bool nullToAbsent) {
    return TaskListsCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      isBuiltIn: Value(isBuiltIn),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TaskList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskList(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int?>(json['color']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int?>(color),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  TaskList copyWith({
    String? id,
    String? name,
    Value<int?> color = const Value.absent(),
    bool? isBuiltIn,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
  }) => TaskList(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TaskList copyWithCompanion(TaskListsCompanion data) {
    return TaskList(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskList(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, isBuiltIn, sortOrder, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskList &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.isBuiltIn == this.isBuiltIn &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaskListsCompanion extends UpdateCompanion<TaskList> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> color;
  final Value<bool> isBuiltIn;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const TaskListsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskListsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TaskList> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<bool>? isBuiltIn,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskListsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int?>? color,
    Value<bool>? isBuiltIn,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return TaskListsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskListsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurrenceRulesTable extends RecurrenceRules
    with TableInfo<$RecurrenceRulesTable, RecurrenceRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurrenceRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecurrenceFrequency, int>
  frequency =
      GeneratedColumn<int>(
        'frequency',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<RecurrenceFrequency>(
        $RecurrenceRulesTable.$converterfrequency,
      );
  static const VerificationMeta _intervalMeta = const VerificationMeta(
    'interval',
  );
  @override
  late final GeneratedColumn<int> interval = GeneratedColumn<int>(
    'interval',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _startsOnMeta = const VerificationMeta(
    'startsOn',
  );
  @override
  late final GeneratedColumn<int> startsOn = GeneratedColumn<int>(
    'starts_on',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _byWeekdayMeta = const VerificationMeta(
    'byWeekday',
  );
  @override
  late final GeneratedColumn<String> byWeekday = GeneratedColumn<String>(
    'by_weekday',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _byMonthDayMeta = const VerificationMeta(
    'byMonthDay',
  );
  @override
  late final GeneratedColumn<String> byMonthDay = GeneratedColumn<String>(
    'by_month_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<int> endDate = GeneratedColumn<int>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endCountMeta = const VerificationMeta(
    'endCount',
  );
  @override
  late final GeneratedColumn<int> endCount = GeneratedColumn<int>(
    'end_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    frequency,
    interval,
    startsOn,
    byWeekday,
    byMonthDay,
    endDate,
    endCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurrence_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurrenceRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('interval')) {
      context.handle(
        _intervalMeta,
        interval.isAcceptableOrUnknown(data['interval']!, _intervalMeta),
      );
    }
    if (data.containsKey('starts_on')) {
      context.handle(
        _startsOnMeta,
        startsOn.isAcceptableOrUnknown(data['starts_on']!, _startsOnMeta),
      );
    }
    if (data.containsKey('by_weekday')) {
      context.handle(
        _byWeekdayMeta,
        byWeekday.isAcceptableOrUnknown(data['by_weekday']!, _byWeekdayMeta),
      );
    }
    if (data.containsKey('by_month_day')) {
      context.handle(
        _byMonthDayMeta,
        byMonthDay.isAcceptableOrUnknown(
          data['by_month_day']!,
          _byMonthDayMeta,
        ),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('end_count')) {
      context.handle(
        _endCountMeta,
        endCount.isAcceptableOrUnknown(data['end_count']!, _endCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurrenceRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurrenceRule(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      frequency: $RecurrenceRulesTable.$converterfrequency.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}frequency'],
        )!,
      ),
      interval: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval'],
      )!,
      startsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starts_on'],
      )!,
      byWeekday: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_weekday'],
      ),
      byMonthDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}by_month_day'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_date'],
      ),
      endCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_count'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RecurrenceRulesTable createAlias(String alias) {
    return $RecurrenceRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RecurrenceFrequency, int, int> $converterfrequency =
      const EnumIndexConverter<RecurrenceFrequency>(RecurrenceFrequency.values);
}

class RecurrenceRule extends DataClass implements Insertable<RecurrenceRule> {
  final String id;
  final RecurrenceFrequency frequency;

  /// 间隔倍数。`frequency = weekly` 且 `interval = 2` 表示「每两周」。
  /// 恒 `>= 1`，由应用层保证（`RecurrenceRule.normalized()` 会在写入前收口）。
  final int interval;

  /// 系列的锚点（本地零点，UTC 毫秒）：整个系列的日期都从它推算。
  ///
  /// 存锚点而不是「上一条实例的日期」是刻意的：某一条被单独挪到下周三，
  /// 不该把「每周一」这个系列从此拖成周三。下一条的日期 = 锚点 +
  /// `n × interval`，n 从锚点算起。
  ///
  /// **默认值 0 只是给 SQLite 用的**：给已有的表加一个非空列时它要求
  /// 有默认值，否则整条 `ALTER TABLE` 会被拒。0 换算出来是 1970 年，
  /// 一眼能看出是「没写过」，`RecurrenceRepository` 读到 0 时会退回用
  /// 规则的创建时间兜底。
  final int startsOn;

  /// 每周重复时生效：`1`=周一 … `7`=周日，逗号分隔，如 `"1,3,5"`。
  /// 为空表示「与起始日同一星期几」。
  final String? byWeekday;

  /// 每月重复时生效：`1`…`31`，逗号分隔，如 `"1,15"`。
  /// 指定 29/30/31 而目标月份没有那天时，落到该月最后一天。
  final String? byMonthDay;

  /// 重复的结束日期（本地零点，UTC 毫秒）。`null` = 永不结束。
  ///
  /// 不设默认上界：用户没说要停就一直重复。但 UI 上会提示「无限重复」，
  /// 免得用户以为设完就完事了。
  final int? endDate;

  /// 最多生成几条（**含第 1 条**）。`null` = 不限次数。
  ///
  /// 计数口径是「这个系列现在有几条任务」，所以删掉一条历史实例会让系列
  /// 少算一次、也就是多跑一次。这是刻意的取舍：与其维护一个会跟现实
  /// 走散的计数器，不如每次当场数一遍。
  final int? endCount;
  final int createdAt;
  const RecurrenceRule({
    required this.id,
    required this.frequency,
    required this.interval,
    required this.startsOn,
    this.byWeekday,
    this.byMonthDay,
    this.endDate,
    this.endCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['frequency'] = Variable<int>(
        $RecurrenceRulesTable.$converterfrequency.toSql(frequency),
      );
    }
    map['interval'] = Variable<int>(interval);
    map['starts_on'] = Variable<int>(startsOn);
    if (!nullToAbsent || byWeekday != null) {
      map['by_weekday'] = Variable<String>(byWeekday);
    }
    if (!nullToAbsent || byMonthDay != null) {
      map['by_month_day'] = Variable<String>(byMonthDay);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<int>(endDate);
    }
    if (!nullToAbsent || endCount != null) {
      map['end_count'] = Variable<int>(endCount);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  RecurrenceRulesCompanion toCompanion(bool nullToAbsent) {
    return RecurrenceRulesCompanion(
      id: Value(id),
      frequency: Value(frequency),
      interval: Value(interval),
      startsOn: Value(startsOn),
      byWeekday: byWeekday == null && nullToAbsent
          ? const Value.absent()
          : Value(byWeekday),
      byMonthDay: byMonthDay == null && nullToAbsent
          ? const Value.absent()
          : Value(byMonthDay),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      endCount: endCount == null && nullToAbsent
          ? const Value.absent()
          : Value(endCount),
      createdAt: Value(createdAt),
    );
  }

  factory RecurrenceRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurrenceRule(
      id: serializer.fromJson<String>(json['id']),
      frequency: $RecurrenceRulesTable.$converterfrequency.fromJson(
        serializer.fromJson<int>(json['frequency']),
      ),
      interval: serializer.fromJson<int>(json['interval']),
      startsOn: serializer.fromJson<int>(json['startsOn']),
      byWeekday: serializer.fromJson<String?>(json['byWeekday']),
      byMonthDay: serializer.fromJson<String?>(json['byMonthDay']),
      endDate: serializer.fromJson<int?>(json['endDate']),
      endCount: serializer.fromJson<int?>(json['endCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'frequency': serializer.toJson<int>(
        $RecurrenceRulesTable.$converterfrequency.toJson(frequency),
      ),
      'interval': serializer.toJson<int>(interval),
      'startsOn': serializer.toJson<int>(startsOn),
      'byWeekday': serializer.toJson<String?>(byWeekday),
      'byMonthDay': serializer.toJson<String?>(byMonthDay),
      'endDate': serializer.toJson<int?>(endDate),
      'endCount': serializer.toJson<int?>(endCount),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  RecurrenceRule copyWith({
    String? id,
    RecurrenceFrequency? frequency,
    int? interval,
    int? startsOn,
    Value<String?> byWeekday = const Value.absent(),
    Value<String?> byMonthDay = const Value.absent(),
    Value<int?> endDate = const Value.absent(),
    Value<int?> endCount = const Value.absent(),
    int? createdAt,
  }) => RecurrenceRule(
    id: id ?? this.id,
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    startsOn: startsOn ?? this.startsOn,
    byWeekday: byWeekday.present ? byWeekday.value : this.byWeekday,
    byMonthDay: byMonthDay.present ? byMonthDay.value : this.byMonthDay,
    endDate: endDate.present ? endDate.value : this.endDate,
    endCount: endCount.present ? endCount.value : this.endCount,
    createdAt: createdAt ?? this.createdAt,
  );
  RecurrenceRule copyWithCompanion(RecurrenceRulesCompanion data) {
    return RecurrenceRule(
      id: data.id.present ? data.id.value : this.id,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      interval: data.interval.present ? data.interval.value : this.interval,
      startsOn: data.startsOn.present ? data.startsOn.value : this.startsOn,
      byWeekday: data.byWeekday.present ? data.byWeekday.value : this.byWeekday,
      byMonthDay: data.byMonthDay.present
          ? data.byMonthDay.value
          : this.byMonthDay,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      endCount: data.endCount.present ? data.endCount.value : this.endCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurrenceRule(')
          ..write('id: $id, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('startsOn: $startsOn, ')
          ..write('byWeekday: $byWeekday, ')
          ..write('byMonthDay: $byMonthDay, ')
          ..write('endDate: $endDate, ')
          ..write('endCount: $endCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    frequency,
    interval,
    startsOn,
    byWeekday,
    byMonthDay,
    endDate,
    endCount,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurrenceRule &&
          other.id == this.id &&
          other.frequency == this.frequency &&
          other.interval == this.interval &&
          other.startsOn == this.startsOn &&
          other.byWeekday == this.byWeekday &&
          other.byMonthDay == this.byMonthDay &&
          other.endDate == this.endDate &&
          other.endCount == this.endCount &&
          other.createdAt == this.createdAt);
}

class RecurrenceRulesCompanion extends UpdateCompanion<RecurrenceRule> {
  final Value<String> id;
  final Value<RecurrenceFrequency> frequency;
  final Value<int> interval;
  final Value<int> startsOn;
  final Value<String?> byWeekday;
  final Value<String?> byMonthDay;
  final Value<int?> endDate;
  final Value<int?> endCount;
  final Value<int> createdAt;
  final Value<int> rowid;
  const RecurrenceRulesCompanion({
    this.id = const Value.absent(),
    this.frequency = const Value.absent(),
    this.interval = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.byWeekday = const Value.absent(),
    this.byMonthDay = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurrenceRulesCompanion.insert({
    required String id,
    required RecurrenceFrequency frequency,
    this.interval = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.byWeekday = const Value.absent(),
    this.byMonthDay = const Value.absent(),
    this.endDate = const Value.absent(),
    this.endCount = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       frequency = Value(frequency),
       createdAt = Value(createdAt);
  static Insertable<RecurrenceRule> custom({
    Expression<String>? id,
    Expression<int>? frequency,
    Expression<int>? interval,
    Expression<int>? startsOn,
    Expression<String>? byWeekday,
    Expression<String>? byMonthDay,
    Expression<int>? endDate,
    Expression<int>? endCount,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (frequency != null) 'frequency': frequency,
      if (interval != null) 'interval': interval,
      if (startsOn != null) 'starts_on': startsOn,
      if (byWeekday != null) 'by_weekday': byWeekday,
      if (byMonthDay != null) 'by_month_day': byMonthDay,
      if (endDate != null) 'end_date': endDate,
      if (endCount != null) 'end_count': endCount,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurrenceRulesCompanion copyWith({
    Value<String>? id,
    Value<RecurrenceFrequency>? frequency,
    Value<int>? interval,
    Value<int>? startsOn,
    Value<String?>? byWeekday,
    Value<String?>? byMonthDay,
    Value<int?>? endDate,
    Value<int?>? endCount,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return RecurrenceRulesCompanion(
      id: id ?? this.id,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      startsOn: startsOn ?? this.startsOn,
      byWeekday: byWeekday ?? this.byWeekday,
      byMonthDay: byMonthDay ?? this.byMonthDay,
      endDate: endDate ?? this.endDate,
      endCount: endCount ?? this.endCount,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<int>(
        $RecurrenceRulesTable.$converterfrequency.toSql(frequency.value),
      );
    }
    if (interval.present) {
      map['interval'] = Variable<int>(interval.value);
    }
    if (startsOn.present) {
      map['starts_on'] = Variable<int>(startsOn.value);
    }
    if (byWeekday.present) {
      map['by_weekday'] = Variable<String>(byWeekday.value);
    }
    if (byMonthDay.present) {
      map['by_month_day'] = Variable<String>(byMonthDay.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<int>(endDate.value);
    }
    if (endCount.present) {
      map['end_count'] = Variable<int>(endCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurrenceRulesCompanion(')
          ..write('id: $id, ')
          ..write('frequency: $frequency, ')
          ..write('interval: $interval, ')
          ..write('startsOn: $startsOn, ')
          ..write('byWeekday: $byWeekday, ')
          ..write('byMonthDay: $byMonthDay, ')
          ..write('endDate: $endDate, ')
          ..write('endCount: $endCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 500,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<int> dueDate = GeneratedColumn<int>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDateHasTimeMeta = const VerificationMeta(
    'dueDateHasTime',
  );
  @override
  late final GeneratedColumn<bool> dueDateHasTime = GeneratedColumn<bool>(
    'due_date_has_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("due_date_has_time" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskPriority, int> priority =
      GeneratedColumn<int>(
        'priority',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<TaskPriority>($TasksTable.$converterpriority);
  @override
  late final GeneratedColumnWithTypeConverter<TaskStatus, int> status =
      GeneratedColumn<int>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<TaskStatus>($TasksTable.$converterstatus);
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES task_lists (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _recurrenceRuleIdMeta = const VerificationMeta(
    'recurrenceRuleId',
  );
  @override
  late final GeneratedColumn<String> recurrenceRuleId = GeneratedColumn<String>(
    'recurrence_rule_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recurrence_rules (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estimatedPomodorosMeta =
      const VerificationMeta('estimatedPomodoros');
  @override
  late final GeneratedColumn<int> estimatedPomodoros = GeneratedColumn<int>(
    'estimated_pomodoros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    note,
    dueDate,
    dueDateHasTime,
    priority,
    status,
    listId,
    recurrenceRuleId,
    createdAt,
    updatedAt,
    completedAt,
    estimatedPomodoros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('due_date_has_time')) {
      context.handle(
        _dueDateHasTimeMeta,
        dueDateHasTime.isAcceptableOrUnknown(
          data['due_date_has_time']!,
          _dueDateHasTimeMeta,
        ),
      );
    }
    if (data.containsKey('list_id')) {
      context.handle(
        _listIdMeta,
        listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta),
      );
    }
    if (data.containsKey('recurrence_rule_id')) {
      context.handle(
        _recurrenceRuleIdMeta,
        recurrenceRuleId.isAcceptableOrUnknown(
          data['recurrence_rule_id']!,
          _recurrenceRuleIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('estimated_pomodoros')) {
      context.handle(
        _estimatedPomodorosMeta,
        estimatedPomodoros.isAcceptableOrUnknown(
          data['estimated_pomodoros']!,
          _estimatedPomodorosMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_date'],
      ),
      dueDateHasTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}due_date_has_time'],
      )!,
      priority: $TasksTable.$converterpriority.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}priority'],
        )!,
      ),
      status: $TasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}status'],
        )!,
      ),
      listId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}list_id'],
      ),
      recurrenceRuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence_rule_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      estimatedPomodoros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_pomodoros'],
      ),
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaskPriority, int, int> $converterpriority =
      const EnumIndexConverter<TaskPriority>(TaskPriority.values);
  static JsonTypeConverter2<TaskStatus, int, int> $converterstatus =
      const EnumIndexConverter<TaskStatus>(TaskStatus.values);
}

class Task extends DataClass implements Insertable<Task> {
  final String id;
  final String title;

  /// 备注。允许 Markdown 原文，但首版只按纯文本渲染。
  final String? note;

  /// 截止时间，UTC 毫秒。`null` 表示没有截止日期。
  final int? dueDate;

  /// [dueDate] 是否精确到时刻。
  ///
  /// `false` = 用户只选了「哪一天」，此时 [dueDate] 恒为本地零点。
  /// 这个标记主要服务于导出格式：导入方需要知道该按日期还是按时刻来理解。
  final bool dueDateHasTime;
  final TaskPriority priority;
  final TaskStatus status;

  /// 所属清单。清单删除时置空（`SET NULL`），任务保留。
  final String? listId;

  /// 所属重复规则。`null` 表示一次性任务。
  ///
  /// 重复任务**不是**在数据库里预先展开成无数行，而是「一个规则 + 一个
  /// 当前实例」。完成当前实例时，由应用层按规则算出下一次并重写本行。
  /// 理由见 `docs/ARCHITECTURE.md` §7：预先展开会让「改一次重复设置」
  /// 变成批量改一堆行，且没有自然的上界。
  final String? recurrenceRuleId;
  final int createdAt;
  final int updatedAt;

  /// 完成时刻。`status` 回到 pending 时会被清空。
  final int? completedAt;

  /// 预估要花几个番茄钟。
  ///
  /// **可空**，而且「没估过」与「估了 0 个」是两件事：前者不该在界面上
  /// 显示进度条，后者是一个明确的「这个任务不用专注」。用 0 表示「没估过」
  /// 会把这两个状态压成一个，之后再想分开就得做数据迁移。
  final int? estimatedPomodoros;
  const Task({
    required this.id,
    required this.title,
    this.note,
    this.dueDate,
    required this.dueDateHasTime,
    required this.priority,
    required this.status,
    this.listId,
    this.recurrenceRuleId,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.estimatedPomodoros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<int>(dueDate);
    }
    map['due_date_has_time'] = Variable<bool>(dueDateHasTime);
    {
      map['priority'] = Variable<int>(
        $TasksTable.$converterpriority.toSql(priority),
      );
    }
    {
      map['status'] = Variable<int>($TasksTable.$converterstatus.toSql(status));
    }
    if (!nullToAbsent || listId != null) {
      map['list_id'] = Variable<String>(listId);
    }
    if (!nullToAbsent || recurrenceRuleId != null) {
      map['recurrence_rule_id'] = Variable<String>(recurrenceRuleId);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || estimatedPomodoros != null) {
      map['estimated_pomodoros'] = Variable<int>(estimatedPomodoros);
    }
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      dueDateHasTime: Value(dueDateHasTime),
      priority: Value(priority),
      status: Value(status),
      listId: listId == null && nullToAbsent
          ? const Value.absent()
          : Value(listId),
      recurrenceRuleId: recurrenceRuleId == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrenceRuleId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      estimatedPomodoros: estimatedPomodoros == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedPomodoros),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      dueDate: serializer.fromJson<int?>(json['dueDate']),
      dueDateHasTime: serializer.fromJson<bool>(json['dueDateHasTime']),
      priority: $TasksTable.$converterpriority.fromJson(
        serializer.fromJson<int>(json['priority']),
      ),
      status: $TasksTable.$converterstatus.fromJson(
        serializer.fromJson<int>(json['status']),
      ),
      listId: serializer.fromJson<String?>(json['listId']),
      recurrenceRuleId: serializer.fromJson<String?>(json['recurrenceRuleId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      estimatedPomodoros: serializer.fromJson<int?>(json['estimatedPomodoros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String?>(note),
      'dueDate': serializer.toJson<int?>(dueDate),
      'dueDateHasTime': serializer.toJson<bool>(dueDateHasTime),
      'priority': serializer.toJson<int>(
        $TasksTable.$converterpriority.toJson(priority),
      ),
      'status': serializer.toJson<int>(
        $TasksTable.$converterstatus.toJson(status),
      ),
      'listId': serializer.toJson<String?>(listId),
      'recurrenceRuleId': serializer.toJson<String?>(recurrenceRuleId),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'estimatedPomodoros': serializer.toJson<int?>(estimatedPomodoros),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    Value<String?> note = const Value.absent(),
    Value<int?> dueDate = const Value.absent(),
    bool? dueDateHasTime,
    TaskPriority? priority,
    TaskStatus? status,
    Value<String?> listId = const Value.absent(),
    Value<String?> recurrenceRuleId = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> completedAt = const Value.absent(),
    Value<int?> estimatedPomodoros = const Value.absent(),
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    note: note.present ? note.value : this.note,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    dueDateHasTime: dueDateHasTime ?? this.dueDateHasTime,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    listId: listId.present ? listId.value : this.listId,
    recurrenceRuleId: recurrenceRuleId.present
        ? recurrenceRuleId.value
        : this.recurrenceRuleId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    estimatedPomodoros: estimatedPomodoros.present
        ? estimatedPomodoros.value
        : this.estimatedPomodoros,
  );
  Task copyWithCompanion(TasksCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      dueDateHasTime: data.dueDateHasTime.present
          ? data.dueDateHasTime.value
          : this.dueDateHasTime,
      priority: data.priority.present ? data.priority.value : this.priority,
      status: data.status.present ? data.status.value : this.status,
      listId: data.listId.present ? data.listId.value : this.listId,
      recurrenceRuleId: data.recurrenceRuleId.present
          ? data.recurrenceRuleId.value
          : this.recurrenceRuleId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      estimatedPomodoros: data.estimatedPomodoros.present
          ? data.estimatedPomodoros.value
          : this.estimatedPomodoros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueDateHasTime: $dueDateHasTime, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('listId: $listId, ')
          ..write('recurrenceRuleId: $recurrenceRuleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('estimatedPomodoros: $estimatedPomodoros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    note,
    dueDate,
    dueDateHasTime,
    priority,
    status,
    listId,
    recurrenceRuleId,
    createdAt,
    updatedAt,
    completedAt,
    estimatedPomodoros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.title == this.title &&
          other.note == this.note &&
          other.dueDate == this.dueDate &&
          other.dueDateHasTime == this.dueDateHasTime &&
          other.priority == this.priority &&
          other.status == this.status &&
          other.listId == this.listId &&
          other.recurrenceRuleId == this.recurrenceRuleId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt &&
          other.estimatedPomodoros == this.estimatedPomodoros);
}

class TasksCompanion extends UpdateCompanion<Task> {
  final Value<String> id;
  final Value<String> title;
  final Value<String?> note;
  final Value<int?> dueDate;
  final Value<bool> dueDateHasTime;
  final Value<TaskPriority> priority;
  final Value<TaskStatus> status;
  final Value<String?> listId;
  final Value<String?> recurrenceRuleId;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> completedAt;
  final Value<int?> estimatedPomodoros;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueDateHasTime = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.listId = const Value.absent(),
    this.recurrenceRuleId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.estimatedPomodoros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String title,
    this.note = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.dueDateHasTime = const Value.absent(),
    this.priority = const Value.absent(),
    this.status = const Value.absent(),
    this.listId = const Value.absent(),
    this.recurrenceRuleId = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.completedAt = const Value.absent(),
    this.estimatedPomodoros = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Task> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? note,
    Expression<int>? dueDate,
    Expression<bool>? dueDateHasTime,
    Expression<int>? priority,
    Expression<int>? status,
    Expression<String>? listId,
    Expression<String>? recurrenceRuleId,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? completedAt,
    Expression<int>? estimatedPomodoros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (dueDate != null) 'due_date': dueDate,
      if (dueDateHasTime != null) 'due_date_has_time': dueDateHasTime,
      if (priority != null) 'priority': priority,
      if (status != null) 'status': status,
      if (listId != null) 'list_id': listId,
      if (recurrenceRuleId != null) 'recurrence_rule_id': recurrenceRuleId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (estimatedPomodoros != null) 'estimated_pomodoros': estimatedPomodoros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String?>? note,
    Value<int?>? dueDate,
    Value<bool>? dueDateHasTime,
    Value<TaskPriority>? priority,
    Value<TaskStatus>? status,
    Value<String?>? listId,
    Value<String?>? recurrenceRuleId,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? completedAt,
    Value<int?>? estimatedPomodoros,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueDate: dueDate ?? this.dueDate,
      dueDateHasTime: dueDateHasTime ?? this.dueDateHasTime,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      listId: listId ?? this.listId,
      recurrenceRuleId: recurrenceRuleId ?? this.recurrenceRuleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<int>(dueDate.value);
    }
    if (dueDateHasTime.present) {
      map['due_date_has_time'] = Variable<bool>(dueDateHasTime.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(
        $TasksTable.$converterpriority.toSql(priority.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<int>(
        $TasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (recurrenceRuleId.present) {
      map['recurrence_rule_id'] = Variable<String>(recurrenceRuleId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (estimatedPomodoros.present) {
      map['estimated_pomodoros'] = Variable<int>(estimatedPomodoros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueDate: $dueDate, ')
          ..write('dueDateHasTime: $dueDateHasTime, ')
          ..write('priority: $priority, ')
          ..write('status: $status, ')
          ..write('listId: $listId, ')
          ..write('recurrenceRuleId: $recurrenceRuleId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('estimatedPomodoros: $estimatedPomodoros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;

  /// 标签名。**唯一**——同名标签是用户的输入失误，不是两种东西。
  /// 新建时若已存在同名标签，复用已有的那条（大小写不敏感）。
  final String name;
  final int? color;
  final int createdAt;
  const Tag({
    required this.id,
    required this.name,
    this.color,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int?>(json['color']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int?>(color),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    Value<int?> color = const Value.absent(),
    int? createdAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
    createdAt: createdAt ?? this.createdAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<int?> color;
  final Value<int> createdAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int?>? color,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TaskTagsTable extends TaskTags with TableInfo<$TaskTagsTable, TaskTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [taskId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'task_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {taskId, tagId};
  @override
  TaskTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskTag(
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TaskTagsTable createAlias(String alias) {
    return $TaskTagsTable(attachedDatabase, alias);
  }
}

class TaskTag extends DataClass implements Insertable<TaskTag> {
  /// 任务删除时连带删除关联行。
  final String taskId;

  /// 标签删除时连带删除关联行。
  final String tagId;
  const TaskTag({required this.taskId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['task_id'] = Variable<String>(taskId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TaskTagsCompanion toCompanion(bool nullToAbsent) {
    return TaskTagsCompanion(taskId: Value(taskId), tagId: Value(tagId));
  }

  factory TaskTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskTag(
      taskId: serializer.fromJson<String>(json['taskId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'taskId': serializer.toJson<String>(taskId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TaskTag copyWith({String? taskId, String? tagId}) =>
      TaskTag(taskId: taskId ?? this.taskId, tagId: tagId ?? this.tagId);
  TaskTag copyWithCompanion(TaskTagsCompanion data) {
    return TaskTag(
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskTag(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(taskId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskTag &&
          other.taskId == this.taskId &&
          other.tagId == this.tagId);
}

class TaskTagsCompanion extends UpdateCompanion<TaskTag> {
  final Value<String> taskId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TaskTagsCompanion({
    this.taskId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TaskTagsCompanion.insert({
    required String taskId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : taskId = Value(taskId),
       tagId = Value(tagId);
  static Insertable<TaskTag> custom({
    Expression<String>? taskId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (taskId != null) 'task_id': taskId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TaskTagsCompanion copyWith({
    Value<String>? taskId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TaskTagsCompanion(
      taskId: taskId ?? this.taskId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTagsCompanion(')
          ..write('taskId: $taskId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtasksTable extends Subtasks with TableInfo<$SubtasksTable, Subtask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 500,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    title,
    isDone,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subtask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subtask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subtask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SubtasksTable createAlias(String alias) {
    return $SubtasksTable(attachedDatabase, alias);
  }
}

class Subtask extends DataClass implements Insertable<Subtask> {
  final String id;

  /// 所属任务。任务删除时连带删除子任务。
  final String taskId;
  final String title;
  final bool isDone;
  final int sortOrder;
  final int createdAt;
  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isDone,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['title'] = Variable<String>(title);
    map['is_done'] = Variable<bool>(isDone);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SubtasksCompanion toCompanion(bool nullToAbsent) {
    return SubtasksCompanion(
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      isDone: Value(isDone),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory Subtask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subtask(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      title: serializer.fromJson<String>(json['title']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'title': serializer.toJson<String>(title),
      'isDone': serializer.toJson<bool>(isDone),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    bool? isDone,
    int? sortOrder,
    int? createdAt,
  }) => Subtask(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  Subtask copyWithCompanion(SubtasksCompanion data) {
    return Subtask(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      title: data.title.present ? data.title.value : this.title,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subtask(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, taskId, title, isDone, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subtask &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.title == this.title &&
          other.isDone == this.isDone &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class SubtasksCompanion extends UpdateCompanion<Subtask> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> title;
  final Value<bool> isDone;
  final Value<int> sortOrder;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SubtasksCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubtasksCompanion.insert({
    required String id,
    required String taskId,
    required String title,
    this.isDone = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<Subtask> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? title,
    Expression<bool>? isDone,
    Expression<int>? sortOrder,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (title != null) 'title': title,
      if (isDone != null) 'is_done': isDone,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubtasksCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? title,
    Value<bool>? isDone,
    Value<int>? sortOrder,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SubtasksCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtasksCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remindAtMeta = const VerificationMeta(
    'remindAt',
  );
  @override
  late final GeneratedColumn<int> remindAt = GeneratedColumn<int>(
    'remind_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderRepeatType, int>
  repeatType = GeneratedColumn<int>(
    'repeat_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  ).withConverter<ReminderRepeatType>($RemindersTable.$converterrepeatType);
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    remindAt,
    repeatType,
    enabled,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('remind_at')) {
      context.handle(
        _remindAtMeta,
        remindAt.isAcceptableOrUnknown(data['remind_at']!, _remindAtMeta),
      );
    } else if (isInserting) {
      context.missing(_remindAtMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      remindAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remind_at'],
      )!,
      repeatType: $RemindersTable.$converterrepeatType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}repeat_type'],
        )!,
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReminderRepeatType, int, int> $converterrepeatType =
      const EnumIndexConverter<ReminderRepeatType>(ReminderRepeatType.values);
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final String id;

  /// 所属任务。任务删除时连带删除提醒。
  final String taskId;

  /// 提醒时刻，UTC 毫秒。
  final int remindAt;
  final ReminderRepeatType repeatType;

  /// 关掉但保留配置。`false` 的提醒不会被注册到系统。
  final bool enabled;
  final int createdAt;
  const Reminder({
    required this.id,
    required this.taskId,
    required this.remindAt,
    required this.repeatType,
    required this.enabled,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['remind_at'] = Variable<int>(remindAt);
    {
      map['repeat_type'] = Variable<int>(
        $RemindersTable.$converterrepeatType.toSql(repeatType),
      );
    }
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      taskId: Value(taskId),
      remindAt: Value(remindAt),
      repeatType: Value(repeatType),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      remindAt: serializer.fromJson<int>(json['remindAt']),
      repeatType: $RemindersTable.$converterrepeatType.fromJson(
        serializer.fromJson<int>(json['repeatType']),
      ),
      enabled: serializer.fromJson<bool>(json['enabled']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'remindAt': serializer.toJson<int>(remindAt),
      'repeatType': serializer.toJson<int>(
        $RemindersTable.$converterrepeatType.toJson(repeatType),
      ),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  Reminder copyWith({
    String? id,
    String? taskId,
    int? remindAt,
    ReminderRepeatType? repeatType,
    bool? enabled,
    int? createdAt,
  }) => Reminder(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    remindAt: remindAt ?? this.remindAt,
    repeatType: repeatType ?? this.repeatType,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      remindAt: data.remindAt.present ? data.remindAt.value : this.remindAt,
      repeatType: data.repeatType.present
          ? data.repeatType.value
          : this.repeatType,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('remindAt: $remindAt, ')
          ..write('repeatType: $repeatType, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, taskId, remindAt, repeatType, enabled, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.remindAt == this.remindAt &&
          other.repeatType == this.repeatType &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<int> remindAt;
  final Value<ReminderRepeatType> repeatType;
  final Value<bool> enabled;
  final Value<int> createdAt;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.remindAt = const Value.absent(),
    this.repeatType = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String taskId,
    required int remindAt,
    this.repeatType = const Value.absent(),
    this.enabled = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       remindAt = Value(remindAt),
       createdAt = Value(createdAt);
  static Insertable<Reminder> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<int>? remindAt,
    Expression<int>? repeatType,
    Expression<bool>? enabled,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (remindAt != null) 'remind_at': remindAt,
      if (repeatType != null) 'repeat_type': repeatType,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<int>? remindAt,
    Value<ReminderRepeatType>? repeatType,
    Value<bool>? enabled,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      remindAt: remindAt ?? this.remindAt,
      repeatType: repeatType ?? this.repeatType,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (remindAt.present) {
      map['remind_at'] = Variable<int>(remindAt.value);
    }
    if (repeatType.present) {
      map['repeat_type'] = Variable<int>(
        $RemindersTable.$converterrepeatType.toSql(repeatType.value),
      );
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('remindAt: $remindAt, ')
          ..write('repeatType: $repeatType, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ThemeModeSetting, int> themeMode =
      GeneratedColumn<int>(
        'theme_mode',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<ThemeModeSetting>($AppSettingsTable.$converterthemeMode);
  @override
  late final GeneratedColumnWithTypeConverter<DefaultView, int> defaultView =
      GeneratedColumn<int>(
        'default_view',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<DefaultView>($AppSettingsTable.$converterdefaultView);
  static const VerificationMeta _notificationsEnabledMeta =
      const VerificationMeta('notificationsEnabled');
  @override
  late final GeneratedColumn<bool> notificationsEnabled = GeneratedColumn<bool>(
    'notifications_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notifications_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _strongRemindersMeta = const VerificationMeta(
    'strongReminders',
  );
  @override
  late final GeneratedColumn<bool> strongReminders = GeneratedColumn<bool>(
    'strong_reminders',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("strong_reminders" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _focusMinutesMeta = const VerificationMeta(
    'focusMinutes',
  );
  @override
  late final GeneratedColumn<int> focusMinutes = GeneratedColumn<int>(
    'focus_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(25),
  );
  static const VerificationMeta _shortBreakMinutesMeta = const VerificationMeta(
    'shortBreakMinutes',
  );
  @override
  late final GeneratedColumn<int> shortBreakMinutes = GeneratedColumn<int>(
    'short_break_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _longBreakMinutesMeta = const VerificationMeta(
    'longBreakMinutes',
  );
  @override
  late final GeneratedColumn<int> longBreakMinutes = GeneratedColumn<int>(
    'long_break_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(15),
  );
  static const VerificationMeta _roundsBeforeLongBreakMeta =
      const VerificationMeta('roundsBeforeLongBreak');
  @override
  late final GeneratedColumn<int> roundsBeforeLongBreak = GeneratedColumn<int>(
    'rounds_before_long_break',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _autoStartNextMeta = const VerificationMeta(
    'autoStartNext',
  );
  @override
  late final GeneratedColumn<bool> autoStartNext = GeneratedColumn<bool>(
    'auto_start_next',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_start_next" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FocusTimerMode, int>
  defaultTimerMode = GeneratedColumn<int>(
    'default_timer_mode',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  ).withConverter<FocusTimerMode>($AppSettingsTable.$converterdefaultTimerMode);
  static const VerificationMeta _midnightModeMeta = const VerificationMeta(
    'midnightMode',
  );
  @override
  late final GeneratedColumn<bool> midnightMode = GeneratedColumn<bool>(
    'midnight_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("midnight_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _midnightEndHourMeta = const VerificationMeta(
    'midnightEndHour',
  );
  @override
  late final GeneratedColumn<int> midnightEndHour = GeneratedColumn<int>(
    'midnight_end_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _initializedAtMeta = const VerificationMeta(
    'initializedAt',
  );
  @override
  late final GeneratedColumn<int> initializedAt = GeneratedColumn<int>(
    'initialized_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    themeMode,
    defaultView,
    notificationsEnabled,
    strongReminders,
    focusMinutes,
    shortBreakMinutes,
    longBreakMinutes,
    roundsBeforeLongBreak,
    autoStartNext,
    defaultTimerMode,
    midnightMode,
    midnightEndHour,
    initializedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('notifications_enabled')) {
      context.handle(
        _notificationsEnabledMeta,
        notificationsEnabled.isAcceptableOrUnknown(
          data['notifications_enabled']!,
          _notificationsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('strong_reminders')) {
      context.handle(
        _strongRemindersMeta,
        strongReminders.isAcceptableOrUnknown(
          data['strong_reminders']!,
          _strongRemindersMeta,
        ),
      );
    }
    if (data.containsKey('focus_minutes')) {
      context.handle(
        _focusMinutesMeta,
        focusMinutes.isAcceptableOrUnknown(
          data['focus_minutes']!,
          _focusMinutesMeta,
        ),
      );
    }
    if (data.containsKey('short_break_minutes')) {
      context.handle(
        _shortBreakMinutesMeta,
        shortBreakMinutes.isAcceptableOrUnknown(
          data['short_break_minutes']!,
          _shortBreakMinutesMeta,
        ),
      );
    }
    if (data.containsKey('long_break_minutes')) {
      context.handle(
        _longBreakMinutesMeta,
        longBreakMinutes.isAcceptableOrUnknown(
          data['long_break_minutes']!,
          _longBreakMinutesMeta,
        ),
      );
    }
    if (data.containsKey('rounds_before_long_break')) {
      context.handle(
        _roundsBeforeLongBreakMeta,
        roundsBeforeLongBreak.isAcceptableOrUnknown(
          data['rounds_before_long_break']!,
          _roundsBeforeLongBreakMeta,
        ),
      );
    }
    if (data.containsKey('auto_start_next')) {
      context.handle(
        _autoStartNextMeta,
        autoStartNext.isAcceptableOrUnknown(
          data['auto_start_next']!,
          _autoStartNextMeta,
        ),
      );
    }
    if (data.containsKey('midnight_mode')) {
      context.handle(
        _midnightModeMeta,
        midnightMode.isAcceptableOrUnknown(
          data['midnight_mode']!,
          _midnightModeMeta,
        ),
      );
    }
    if (data.containsKey('midnight_end_hour')) {
      context.handle(
        _midnightEndHourMeta,
        midnightEndHour.isAcceptableOrUnknown(
          data['midnight_end_hour']!,
          _midnightEndHourMeta,
        ),
      );
    }
    if (data.containsKey('initialized_at')) {
      context.handle(
        _initializedAtMeta,
        initializedAt.isAcceptableOrUnknown(
          data['initialized_at']!,
          _initializedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      themeMode: $AppSettingsTable.$converterthemeMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}theme_mode'],
        )!,
      ),
      defaultView: $AppSettingsTable.$converterdefaultView.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}default_view'],
        )!,
      ),
      notificationsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notifications_enabled'],
      )!,
      strongReminders: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}strong_reminders'],
      )!,
      focusMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}focus_minutes'],
      )!,
      shortBreakMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}short_break_minutes'],
      )!,
      longBreakMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}long_break_minutes'],
      )!,
      roundsBeforeLongBreak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rounds_before_long_break'],
      )!,
      autoStartNext: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_start_next'],
      )!,
      defaultTimerMode: $AppSettingsTable.$converterdefaultTimerMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}default_timer_mode'],
        )!,
      ),
      midnightMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}midnight_mode'],
      )!,
      midnightEndHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}midnight_end_hour'],
      )!,
      initializedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initialized_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ThemeModeSetting, int, int> $converterthemeMode =
      const EnumIndexConverter<ThemeModeSetting>(ThemeModeSetting.values);
  static JsonTypeConverter2<DefaultView, int, int> $converterdefaultView =
      const EnumIndexConverter<DefaultView>(DefaultView.values);
  static JsonTypeConverter2<FocusTimerMode, int, int>
  $converterdefaultTimerMode = const EnumIndexConverter<FocusTimerMode>(
    FocusTimerMode.values,
  );
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  /// 恒为 `1`。见类文档。
  final int id;
  final ThemeModeSetting themeMode;
  final DefaultView defaultView;

  /// 总开关。关掉后不再注册任何系统通知，但已配置的 [Reminders] 行保留。
  ///
  /// 与「提醒本身被禁用」是两件事：前者是全局态度，后者是单条配置。
  final bool notificationsEnabled;

  /// 强提醒：到点后持续响铃，直到用户处理掉这条通知。
  ///
  /// 默认**关**。它会一直响，默认开启对一个待办应用来说太吵了；
  /// 而且系统勿扰与静音会压制它，用户以为「开了就一定能叫醒」时
  /// 反而更容易误事，所以必须是用户主动选的。
  final bool strongReminders;

  /// 一轮专注的分钟数。
  final int focusMinutes;

  /// 短休息的分钟数。
  final int shortBreakMinutes;

  /// 长休息的分钟数。
  final int longBreakMinutes;

  /// 几轮专注之后接一次长休息。
  final int roundsBeforeLongBreak;

  /// 一轮结束后是否自动开始下一轮。
  ///
  /// 默认**关**：自动接续意味着用户离开工位后计时器还在自己往下跑，
  /// 记下来的「专注」会变成一段没人专注的时间。
  final bool autoStartNext;

  /// 默认的计时模式。`1` = `FocusTimerMode.countDown`（枚举是追加式的，
  /// 倒计时不是第 0 个，所以这里只能写裸值）。
  final FocusTimerMode defaultTimerMode;

  /// 午夜模式：凌晨开始的会话算作前一天。
  ///
  /// 默认**关**。对作息正常的人是纯粹的噪音，对熬夜的人才是刚需。
  final bool midnightMode;

  /// 午夜模式的边界小时：本地时刻小于它的算前一天。默认 4 点。
  final int midnightEndHour;

  /// 首次启动完成时间。`null` 表示还没走过初始化。
  ///
  /// 用它判断要不要建内置清单、要不要显示欢迎引导——
  /// 比「表里有没有数据」可靠，因为用户可能把内置数据全删了。
  final int? initializedAt;
  final int? updatedAt;
  const AppSetting({
    required this.id,
    required this.themeMode,
    required this.defaultView,
    required this.notificationsEnabled,
    required this.strongReminders,
    required this.focusMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.roundsBeforeLongBreak,
    required this.autoStartNext,
    required this.defaultTimerMode,
    required this.midnightMode,
    required this.midnightEndHour,
    this.initializedAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['theme_mode'] = Variable<int>(
        $AppSettingsTable.$converterthemeMode.toSql(themeMode),
      );
    }
    {
      map['default_view'] = Variable<int>(
        $AppSettingsTable.$converterdefaultView.toSql(defaultView),
      );
    }
    map['notifications_enabled'] = Variable<bool>(notificationsEnabled);
    map['strong_reminders'] = Variable<bool>(strongReminders);
    map['focus_minutes'] = Variable<int>(focusMinutes);
    map['short_break_minutes'] = Variable<int>(shortBreakMinutes);
    map['long_break_minutes'] = Variable<int>(longBreakMinutes);
    map['rounds_before_long_break'] = Variable<int>(roundsBeforeLongBreak);
    map['auto_start_next'] = Variable<bool>(autoStartNext);
    {
      map['default_timer_mode'] = Variable<int>(
        $AppSettingsTable.$converterdefaultTimerMode.toSql(defaultTimerMode),
      );
    }
    map['midnight_mode'] = Variable<bool>(midnightMode);
    map['midnight_end_hour'] = Variable<int>(midnightEndHour);
    if (!nullToAbsent || initializedAt != null) {
      map['initialized_at'] = Variable<int>(initializedAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      themeMode: Value(themeMode),
      defaultView: Value(defaultView),
      notificationsEnabled: Value(notificationsEnabled),
      strongReminders: Value(strongReminders),
      focusMinutes: Value(focusMinutes),
      shortBreakMinutes: Value(shortBreakMinutes),
      longBreakMinutes: Value(longBreakMinutes),
      roundsBeforeLongBreak: Value(roundsBeforeLongBreak),
      autoStartNext: Value(autoStartNext),
      defaultTimerMode: Value(defaultTimerMode),
      midnightMode: Value(midnightMode),
      midnightEndHour: Value(midnightEndHour),
      initializedAt: initializedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(initializedAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      themeMode: $AppSettingsTable.$converterthemeMode.fromJson(
        serializer.fromJson<int>(json['themeMode']),
      ),
      defaultView: $AppSettingsTable.$converterdefaultView.fromJson(
        serializer.fromJson<int>(json['defaultView']),
      ),
      notificationsEnabled: serializer.fromJson<bool>(
        json['notificationsEnabled'],
      ),
      strongReminders: serializer.fromJson<bool>(json['strongReminders']),
      focusMinutes: serializer.fromJson<int>(json['focusMinutes']),
      shortBreakMinutes: serializer.fromJson<int>(json['shortBreakMinutes']),
      longBreakMinutes: serializer.fromJson<int>(json['longBreakMinutes']),
      roundsBeforeLongBreak: serializer.fromJson<int>(
        json['roundsBeforeLongBreak'],
      ),
      autoStartNext: serializer.fromJson<bool>(json['autoStartNext']),
      defaultTimerMode: $AppSettingsTable.$converterdefaultTimerMode.fromJson(
        serializer.fromJson<int>(json['defaultTimerMode']),
      ),
      midnightMode: serializer.fromJson<bool>(json['midnightMode']),
      midnightEndHour: serializer.fromJson<int>(json['midnightEndHour']),
      initializedAt: serializer.fromJson<int?>(json['initializedAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'themeMode': serializer.toJson<int>(
        $AppSettingsTable.$converterthemeMode.toJson(themeMode),
      ),
      'defaultView': serializer.toJson<int>(
        $AppSettingsTable.$converterdefaultView.toJson(defaultView),
      ),
      'notificationsEnabled': serializer.toJson<bool>(notificationsEnabled),
      'strongReminders': serializer.toJson<bool>(strongReminders),
      'focusMinutes': serializer.toJson<int>(focusMinutes),
      'shortBreakMinutes': serializer.toJson<int>(shortBreakMinutes),
      'longBreakMinutes': serializer.toJson<int>(longBreakMinutes),
      'roundsBeforeLongBreak': serializer.toJson<int>(roundsBeforeLongBreak),
      'autoStartNext': serializer.toJson<bool>(autoStartNext),
      'defaultTimerMode': serializer.toJson<int>(
        $AppSettingsTable.$converterdefaultTimerMode.toJson(defaultTimerMode),
      ),
      'midnightMode': serializer.toJson<bool>(midnightMode),
      'midnightEndHour': serializer.toJson<int>(midnightEndHour),
      'initializedAt': serializer.toJson<int?>(initializedAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  AppSetting copyWith({
    int? id,
    ThemeModeSetting? themeMode,
    DefaultView? defaultView,
    bool? notificationsEnabled,
    bool? strongReminders,
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? roundsBeforeLongBreak,
    bool? autoStartNext,
    FocusTimerMode? defaultTimerMode,
    bool? midnightMode,
    int? midnightEndHour,
    Value<int?> initializedAt = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
  }) => AppSetting(
    id: id ?? this.id,
    themeMode: themeMode ?? this.themeMode,
    defaultView: defaultView ?? this.defaultView,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    strongReminders: strongReminders ?? this.strongReminders,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    roundsBeforeLongBreak: roundsBeforeLongBreak ?? this.roundsBeforeLongBreak,
    autoStartNext: autoStartNext ?? this.autoStartNext,
    defaultTimerMode: defaultTimerMode ?? this.defaultTimerMode,
    midnightMode: midnightMode ?? this.midnightMode,
    midnightEndHour: midnightEndHour ?? this.midnightEndHour,
    initializedAt: initializedAt.present
        ? initializedAt.value
        : this.initializedAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      defaultView: data.defaultView.present
          ? data.defaultView.value
          : this.defaultView,
      notificationsEnabled: data.notificationsEnabled.present
          ? data.notificationsEnabled.value
          : this.notificationsEnabled,
      strongReminders: data.strongReminders.present
          ? data.strongReminders.value
          : this.strongReminders,
      focusMinutes: data.focusMinutes.present
          ? data.focusMinutes.value
          : this.focusMinutes,
      shortBreakMinutes: data.shortBreakMinutes.present
          ? data.shortBreakMinutes.value
          : this.shortBreakMinutes,
      longBreakMinutes: data.longBreakMinutes.present
          ? data.longBreakMinutes.value
          : this.longBreakMinutes,
      roundsBeforeLongBreak: data.roundsBeforeLongBreak.present
          ? data.roundsBeforeLongBreak.value
          : this.roundsBeforeLongBreak,
      autoStartNext: data.autoStartNext.present
          ? data.autoStartNext.value
          : this.autoStartNext,
      defaultTimerMode: data.defaultTimerMode.present
          ? data.defaultTimerMode.value
          : this.defaultTimerMode,
      midnightMode: data.midnightMode.present
          ? data.midnightMode.value
          : this.midnightMode,
      midnightEndHour: data.midnightEndHour.present
          ? data.midnightEndHour.value
          : this.midnightEndHour,
      initializedAt: data.initializedAt.present
          ? data.initializedAt.value
          : this.initializedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('defaultView: $defaultView, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('strongReminders: $strongReminders, ')
          ..write('focusMinutes: $focusMinutes, ')
          ..write('shortBreakMinutes: $shortBreakMinutes, ')
          ..write('longBreakMinutes: $longBreakMinutes, ')
          ..write('roundsBeforeLongBreak: $roundsBeforeLongBreak, ')
          ..write('autoStartNext: $autoStartNext, ')
          ..write('defaultTimerMode: $defaultTimerMode, ')
          ..write('midnightMode: $midnightMode, ')
          ..write('midnightEndHour: $midnightEndHour, ')
          ..write('initializedAt: $initializedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    themeMode,
    defaultView,
    notificationsEnabled,
    strongReminders,
    focusMinutes,
    shortBreakMinutes,
    longBreakMinutes,
    roundsBeforeLongBreak,
    autoStartNext,
    defaultTimerMode,
    midnightMode,
    midnightEndHour,
    initializedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.themeMode == this.themeMode &&
          other.defaultView == this.defaultView &&
          other.notificationsEnabled == this.notificationsEnabled &&
          other.strongReminders == this.strongReminders &&
          other.focusMinutes == this.focusMinutes &&
          other.shortBreakMinutes == this.shortBreakMinutes &&
          other.longBreakMinutes == this.longBreakMinutes &&
          other.roundsBeforeLongBreak == this.roundsBeforeLongBreak &&
          other.autoStartNext == this.autoStartNext &&
          other.defaultTimerMode == this.defaultTimerMode &&
          other.midnightMode == this.midnightMode &&
          other.midnightEndHour == this.midnightEndHour &&
          other.initializedAt == this.initializedAt &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<ThemeModeSetting> themeMode;
  final Value<DefaultView> defaultView;
  final Value<bool> notificationsEnabled;
  final Value<bool> strongReminders;
  final Value<int> focusMinutes;
  final Value<int> shortBreakMinutes;
  final Value<int> longBreakMinutes;
  final Value<int> roundsBeforeLongBreak;
  final Value<bool> autoStartNext;
  final Value<FocusTimerMode> defaultTimerMode;
  final Value<bool> midnightMode;
  final Value<int> midnightEndHour;
  final Value<int?> initializedAt;
  final Value<int?> updatedAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.defaultView = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.strongReminders = const Value.absent(),
    this.focusMinutes = const Value.absent(),
    this.shortBreakMinutes = const Value.absent(),
    this.longBreakMinutes = const Value.absent(),
    this.roundsBeforeLongBreak = const Value.absent(),
    this.autoStartNext = const Value.absent(),
    this.defaultTimerMode = const Value.absent(),
    this.midnightMode = const Value.absent(),
    this.midnightEndHour = const Value.absent(),
    this.initializedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.defaultView = const Value.absent(),
    this.notificationsEnabled = const Value.absent(),
    this.strongReminders = const Value.absent(),
    this.focusMinutes = const Value.absent(),
    this.shortBreakMinutes = const Value.absent(),
    this.longBreakMinutes = const Value.absent(),
    this.roundsBeforeLongBreak = const Value.absent(),
    this.autoStartNext = const Value.absent(),
    this.defaultTimerMode = const Value.absent(),
    this.midnightMode = const Value.absent(),
    this.midnightEndHour = const Value.absent(),
    this.initializedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<int>? themeMode,
    Expression<int>? defaultView,
    Expression<bool>? notificationsEnabled,
    Expression<bool>? strongReminders,
    Expression<int>? focusMinutes,
    Expression<int>? shortBreakMinutes,
    Expression<int>? longBreakMinutes,
    Expression<int>? roundsBeforeLongBreak,
    Expression<bool>? autoStartNext,
    Expression<int>? defaultTimerMode,
    Expression<bool>? midnightMode,
    Expression<int>? midnightEndHour,
    Expression<int>? initializedAt,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (themeMode != null) 'theme_mode': themeMode,
      if (defaultView != null) 'default_view': defaultView,
      if (notificationsEnabled != null)
        'notifications_enabled': notificationsEnabled,
      if (strongReminders != null) 'strong_reminders': strongReminders,
      if (focusMinutes != null) 'focus_minutes': focusMinutes,
      if (shortBreakMinutes != null) 'short_break_minutes': shortBreakMinutes,
      if (longBreakMinutes != null) 'long_break_minutes': longBreakMinutes,
      if (roundsBeforeLongBreak != null)
        'rounds_before_long_break': roundsBeforeLongBreak,
      if (autoStartNext != null) 'auto_start_next': autoStartNext,
      if (defaultTimerMode != null) 'default_timer_mode': defaultTimerMode,
      if (midnightMode != null) 'midnight_mode': midnightMode,
      if (midnightEndHour != null) 'midnight_end_hour': midnightEndHour,
      if (initializedAt != null) 'initialized_at': initializedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<ThemeModeSetting>? themeMode,
    Value<DefaultView>? defaultView,
    Value<bool>? notificationsEnabled,
    Value<bool>? strongReminders,
    Value<int>? focusMinutes,
    Value<int>? shortBreakMinutes,
    Value<int>? longBreakMinutes,
    Value<int>? roundsBeforeLongBreak,
    Value<bool>? autoStartNext,
    Value<FocusTimerMode>? defaultTimerMode,
    Value<bool>? midnightMode,
    Value<int>? midnightEndHour,
    Value<int?>? initializedAt,
    Value<int?>? updatedAt,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      themeMode: themeMode ?? this.themeMode,
      defaultView: defaultView ?? this.defaultView,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      strongReminders: strongReminders ?? this.strongReminders,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      roundsBeforeLongBreak:
          roundsBeforeLongBreak ?? this.roundsBeforeLongBreak,
      autoStartNext: autoStartNext ?? this.autoStartNext,
      defaultTimerMode: defaultTimerMode ?? this.defaultTimerMode,
      midnightMode: midnightMode ?? this.midnightMode,
      midnightEndHour: midnightEndHour ?? this.midnightEndHour,
      initializedAt: initializedAt ?? this.initializedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<int>(
        $AppSettingsTable.$converterthemeMode.toSql(themeMode.value),
      );
    }
    if (defaultView.present) {
      map['default_view'] = Variable<int>(
        $AppSettingsTable.$converterdefaultView.toSql(defaultView.value),
      );
    }
    if (notificationsEnabled.present) {
      map['notifications_enabled'] = Variable<bool>(notificationsEnabled.value);
    }
    if (strongReminders.present) {
      map['strong_reminders'] = Variable<bool>(strongReminders.value);
    }
    if (focusMinutes.present) {
      map['focus_minutes'] = Variable<int>(focusMinutes.value);
    }
    if (shortBreakMinutes.present) {
      map['short_break_minutes'] = Variable<int>(shortBreakMinutes.value);
    }
    if (longBreakMinutes.present) {
      map['long_break_minutes'] = Variable<int>(longBreakMinutes.value);
    }
    if (roundsBeforeLongBreak.present) {
      map['rounds_before_long_break'] = Variable<int>(
        roundsBeforeLongBreak.value,
      );
    }
    if (autoStartNext.present) {
      map['auto_start_next'] = Variable<bool>(autoStartNext.value);
    }
    if (defaultTimerMode.present) {
      map['default_timer_mode'] = Variable<int>(
        $AppSettingsTable.$converterdefaultTimerMode.toSql(
          defaultTimerMode.value,
        ),
      );
    }
    if (midnightMode.present) {
      map['midnight_mode'] = Variable<bool>(midnightMode.value);
    }
    if (midnightEndHour.present) {
      map['midnight_end_hour'] = Variable<int>(midnightEndHour.value);
    }
    if (initializedAt.present) {
      map['initialized_at'] = Variable<int>(initializedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('themeMode: $themeMode, ')
          ..write('defaultView: $defaultView, ')
          ..write('notificationsEnabled: $notificationsEnabled, ')
          ..write('strongReminders: $strongReminders, ')
          ..write('focusMinutes: $focusMinutes, ')
          ..write('shortBreakMinutes: $shortBreakMinutes, ')
          ..write('longBreakMinutes: $longBreakMinutes, ')
          ..write('roundsBeforeLongBreak: $roundsBeforeLongBreak, ')
          ..write('autoStartNext: $autoStartNext, ')
          ..write('defaultTimerMode: $defaultTimerMode, ')
          ..write('midnightMode: $midnightMode, ')
          ..write('midnightEndHour: $midnightEndHour, ')
          ..write('initializedAt: $initializedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $FocusSessionsTable extends FocusSessions
    with TableInfo<$FocusSessionsTable, FocusSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FocusSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedMillisMeta = const VerificationMeta(
    'pausedMillis',
  );
  @override
  late final GeneratedColumn<int> pausedMillis = GeneratedColumn<int>(
    'paused_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pausedAtMeta = const VerificationMeta(
    'pausedAt',
  );
  @override
  late final GeneratedColumn<int> pausedAt = GeneratedColumn<int>(
    'paused_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedSecondsMeta = const VerificationMeta(
    'plannedSeconds',
  );
  @override
  late final GeneratedColumn<int> plannedSeconds = GeneratedColumn<int>(
    'planned_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualSecondsMeta = const VerificationMeta(
    'actualSeconds',
  );
  @override
  late final GeneratedColumn<int> actualSeconds = GeneratedColumn<int>(
    'actual_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FocusSessionKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<FocusSessionKind>($FocusSessionsTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<FocusTimerMode, int> timerMode =
      GeneratedColumn<int>(
        'timer_mode',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(1),
      ).withConverter<FocusTimerMode>($FocusSessionsTable.$convertertimerMode);
  static const VerificationMeta _logicalDateMeta = const VerificationMeta(
    'logicalDate',
  );
  @override
  late final GeneratedColumn<int> logicalDate = GeneratedColumn<int>(
    'logical_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    startedAt,
    endedAt,
    pausedMillis,
    pausedAt,
    plannedSeconds,
    actualSeconds,
    kind,
    timerMode,
    logicalDate,
    completed,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'focus_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<FocusSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('paused_millis')) {
      context.handle(
        _pausedMillisMeta,
        pausedMillis.isAcceptableOrUnknown(
          data['paused_millis']!,
          _pausedMillisMeta,
        ),
      );
    }
    if (data.containsKey('paused_at')) {
      context.handle(
        _pausedAtMeta,
        pausedAt.isAcceptableOrUnknown(data['paused_at']!, _pausedAtMeta),
      );
    }
    if (data.containsKey('planned_seconds')) {
      context.handle(
        _plannedSecondsMeta,
        plannedSeconds.isAcceptableOrUnknown(
          data['planned_seconds']!,
          _plannedSecondsMeta,
        ),
      );
    }
    if (data.containsKey('actual_seconds')) {
      context.handle(
        _actualSecondsMeta,
        actualSeconds.isAcceptableOrUnknown(
          data['actual_seconds']!,
          _actualSecondsMeta,
        ),
      );
    }
    if (data.containsKey('logical_date')) {
      context.handle(
        _logicalDateMeta,
        logicalDate.isAcceptableOrUnknown(
          data['logical_date']!,
          _logicalDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_logicalDateMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FocusSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FocusSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      pausedMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_millis'],
      )!,
      pausedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paused_at'],
      ),
      plannedSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_seconds'],
      ),
      actualSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_seconds'],
      )!,
      kind: $FocusSessionsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      timerMode: $FocusSessionsTable.$convertertimerMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}timer_mode'],
        )!,
      ),
      logicalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}logical_date'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $FocusSessionsTable createAlias(String alias) {
    return $FocusSessionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FocusSessionKind, int, int> $converterkind =
      const EnumIndexConverter<FocusSessionKind>(FocusSessionKind.values);
  static JsonTypeConverter2<FocusTimerMode, int, int> $convertertimerMode =
      const EnumIndexConverter<FocusTimerMode>(FocusTimerMode.values);
}

class FocusSession extends DataClass implements Insertable<FocusSession> {
  final String id;

  /// 归属任务。`null` = 没挂任务的自由专注。
  final String? taskId;

  /// 会话开始时刻，UTC 毫秒。
  final int startedAt;

  /// 结束时刻。`null` 表示还在进行中。
  final int? endedAt;

  /// 累计暂停时长（毫秒）。与 `FocusTimerState.pausedMillis` 直接对应。
  ///
  /// **只含已经结束的暂停**。正在进行中的那次暂停由 [pausedAt] 单独表示，
  /// 因为它的时长要到恢复时才确定。
  final int pausedMillis;

  /// 当前这次暂停的开始时刻。非空 = 会话正暂停着。
  ///
  /// **这一列不在最初的设计稿里，是写实现时补的**：只有 [pausedMillis]
  /// 的话，用户在暂停状态下被系统杀进程，重开后只能看到「从开始就一直跑着」，
  /// 于是整段暂停时间会被安静地算成专注时间——而杀进程恰恰是这套设计
  /// 必须扛住的场景。表随 v3 一起发布，此刻加列不需要额外迁移。
  final int? pausedAt;

  /// 计划时长（秒）。正计时模式为 `null`。
  final int? plannedSeconds;

  /// 实际时长（秒）。结束时写入，不含暂停。
  final int actualSeconds;

  /// 这是专注还是休息。
  final FocusSessionKind kind;

  /// 正计时还是倒计时。
  final FocusTimerMode timerMode;

  /// 归属的逻辑日（本地零点毫秒）。写入时按当时的设置冻结，见类文档。
  final int logicalDate;

  /// 是否走满了计划时长。正计时模式结束时为 `false`——它没有「走满」这回事。
  final bool completed;

  /// 这一笔的备注，会话结束后补填。
  ///
  /// **不在最初的设计稿里**：F3 的「记一笔」要求会话结束后可以写备注，
  /// 而表里没有地方放。趁 v3 还没发布加进来，比之后为它单独开一次迁移便宜。
  final String? note;
  const FocusSession({
    required this.id,
    this.taskId,
    required this.startedAt,
    this.endedAt,
    required this.pausedMillis,
    this.pausedAt,
    this.plannedSeconds,
    required this.actualSeconds,
    required this.kind,
    required this.timerMode,
    required this.logicalDate,
    required this.completed,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || taskId != null) {
      map['task_id'] = Variable<String>(taskId);
    }
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    map['paused_millis'] = Variable<int>(pausedMillis);
    if (!nullToAbsent || pausedAt != null) {
      map['paused_at'] = Variable<int>(pausedAt);
    }
    if (!nullToAbsent || plannedSeconds != null) {
      map['planned_seconds'] = Variable<int>(plannedSeconds);
    }
    map['actual_seconds'] = Variable<int>(actualSeconds);
    {
      map['kind'] = Variable<int>(
        $FocusSessionsTable.$converterkind.toSql(kind),
      );
    }
    {
      map['timer_mode'] = Variable<int>(
        $FocusSessionsTable.$convertertimerMode.toSql(timerMode),
      );
    }
    map['logical_date'] = Variable<int>(logicalDate);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  FocusSessionsCompanion toCompanion(bool nullToAbsent) {
    return FocusSessionsCompanion(
      id: Value(id),
      taskId: taskId == null && nullToAbsent
          ? const Value.absent()
          : Value(taskId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      pausedMillis: Value(pausedMillis),
      pausedAt: pausedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedAt),
      plannedSeconds: plannedSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedSeconds),
      actualSeconds: Value(actualSeconds),
      kind: Value(kind),
      timerMode: Value(timerMode),
      logicalDate: Value(logicalDate),
      completed: Value(completed),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory FocusSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FocusSession(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String?>(json['taskId']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      pausedMillis: serializer.fromJson<int>(json['pausedMillis']),
      pausedAt: serializer.fromJson<int?>(json['pausedAt']),
      plannedSeconds: serializer.fromJson<int?>(json['plannedSeconds']),
      actualSeconds: serializer.fromJson<int>(json['actualSeconds']),
      kind: $FocusSessionsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      timerMode: $FocusSessionsTable.$convertertimerMode.fromJson(
        serializer.fromJson<int>(json['timerMode']),
      ),
      logicalDate: serializer.fromJson<int>(json['logicalDate']),
      completed: serializer.fromJson<bool>(json['completed']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String?>(taskId),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'pausedMillis': serializer.toJson<int>(pausedMillis),
      'pausedAt': serializer.toJson<int?>(pausedAt),
      'plannedSeconds': serializer.toJson<int?>(plannedSeconds),
      'actualSeconds': serializer.toJson<int>(actualSeconds),
      'kind': serializer.toJson<int>(
        $FocusSessionsTable.$converterkind.toJson(kind),
      ),
      'timerMode': serializer.toJson<int>(
        $FocusSessionsTable.$convertertimerMode.toJson(timerMode),
      ),
      'logicalDate': serializer.toJson<int>(logicalDate),
      'completed': serializer.toJson<bool>(completed),
      'note': serializer.toJson<String?>(note),
    };
  }

  FocusSession copyWith({
    String? id,
    Value<String?> taskId = const Value.absent(),
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    int? pausedMillis,
    Value<int?> pausedAt = const Value.absent(),
    Value<int?> plannedSeconds = const Value.absent(),
    int? actualSeconds,
    FocusSessionKind? kind,
    FocusTimerMode? timerMode,
    int? logicalDate,
    bool? completed,
    Value<String?> note = const Value.absent(),
  }) => FocusSession(
    id: id ?? this.id,
    taskId: taskId.present ? taskId.value : this.taskId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    pausedMillis: pausedMillis ?? this.pausedMillis,
    pausedAt: pausedAt.present ? pausedAt.value : this.pausedAt,
    plannedSeconds: plannedSeconds.present
        ? plannedSeconds.value
        : this.plannedSeconds,
    actualSeconds: actualSeconds ?? this.actualSeconds,
    kind: kind ?? this.kind,
    timerMode: timerMode ?? this.timerMode,
    logicalDate: logicalDate ?? this.logicalDate,
    completed: completed ?? this.completed,
    note: note.present ? note.value : this.note,
  );
  FocusSession copyWithCompanion(FocusSessionsCompanion data) {
    return FocusSession(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      pausedMillis: data.pausedMillis.present
          ? data.pausedMillis.value
          : this.pausedMillis,
      pausedAt: data.pausedAt.present ? data.pausedAt.value : this.pausedAt,
      plannedSeconds: data.plannedSeconds.present
          ? data.plannedSeconds.value
          : this.plannedSeconds,
      actualSeconds: data.actualSeconds.present
          ? data.actualSeconds.value
          : this.actualSeconds,
      kind: data.kind.present ? data.kind.value : this.kind,
      timerMode: data.timerMode.present ? data.timerMode.value : this.timerMode,
      logicalDate: data.logicalDate.present
          ? data.logicalDate.value
          : this.logicalDate,
      completed: data.completed.present ? data.completed.value : this.completed,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FocusSession(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedMillis: $pausedMillis, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('plannedSeconds: $plannedSeconds, ')
          ..write('actualSeconds: $actualSeconds, ')
          ..write('kind: $kind, ')
          ..write('timerMode: $timerMode, ')
          ..write('logicalDate: $logicalDate, ')
          ..write('completed: $completed, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    startedAt,
    endedAt,
    pausedMillis,
    pausedAt,
    plannedSeconds,
    actualSeconds,
    kind,
    timerMode,
    logicalDate,
    completed,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FocusSession &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.pausedMillis == this.pausedMillis &&
          other.pausedAt == this.pausedAt &&
          other.plannedSeconds == this.plannedSeconds &&
          other.actualSeconds == this.actualSeconds &&
          other.kind == this.kind &&
          other.timerMode == this.timerMode &&
          other.logicalDate == this.logicalDate &&
          other.completed == this.completed &&
          other.note == this.note);
}

class FocusSessionsCompanion extends UpdateCompanion<FocusSession> {
  final Value<String> id;
  final Value<String?> taskId;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<int> pausedMillis;
  final Value<int?> pausedAt;
  final Value<int?> plannedSeconds;
  final Value<int> actualSeconds;
  final Value<FocusSessionKind> kind;
  final Value<FocusTimerMode> timerMode;
  final Value<int> logicalDate;
  final Value<bool> completed;
  final Value<String?> note;
  final Value<int> rowid;
  const FocusSessionsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.pausedMillis = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.plannedSeconds = const Value.absent(),
    this.actualSeconds = const Value.absent(),
    this.kind = const Value.absent(),
    this.timerMode = const Value.absent(),
    this.logicalDate = const Value.absent(),
    this.completed = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FocusSessionsCompanion.insert({
    required String id,
    this.taskId = const Value.absent(),
    required int startedAt,
    this.endedAt = const Value.absent(),
    this.pausedMillis = const Value.absent(),
    this.pausedAt = const Value.absent(),
    this.plannedSeconds = const Value.absent(),
    this.actualSeconds = const Value.absent(),
    this.kind = const Value.absent(),
    this.timerMode = const Value.absent(),
    required int logicalDate,
    this.completed = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       logicalDate = Value(logicalDate);
  static Insertable<FocusSession> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<int>? pausedMillis,
    Expression<int>? pausedAt,
    Expression<int>? plannedSeconds,
    Expression<int>? actualSeconds,
    Expression<int>? kind,
    Expression<int>? timerMode,
    Expression<int>? logicalDate,
    Expression<bool>? completed,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (pausedMillis != null) 'paused_millis': pausedMillis,
      if (pausedAt != null) 'paused_at': pausedAt,
      if (plannedSeconds != null) 'planned_seconds': plannedSeconds,
      if (actualSeconds != null) 'actual_seconds': actualSeconds,
      if (kind != null) 'kind': kind,
      if (timerMode != null) 'timer_mode': timerMode,
      if (logicalDate != null) 'logical_date': logicalDate,
      if (completed != null) 'completed': completed,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FocusSessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? taskId,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<int>? pausedMillis,
    Value<int?>? pausedAt,
    Value<int?>? plannedSeconds,
    Value<int>? actualSeconds,
    Value<FocusSessionKind>? kind,
    Value<FocusTimerMode>? timerMode,
    Value<int>? logicalDate,
    Value<bool>? completed,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return FocusSessionsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      pausedMillis: pausedMillis ?? this.pausedMillis,
      pausedAt: pausedAt ?? this.pausedAt,
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      actualSeconds: actualSeconds ?? this.actualSeconds,
      kind: kind ?? this.kind,
      timerMode: timerMode ?? this.timerMode,
      logicalDate: logicalDate ?? this.logicalDate,
      completed: completed ?? this.completed,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (pausedMillis.present) {
      map['paused_millis'] = Variable<int>(pausedMillis.value);
    }
    if (pausedAt.present) {
      map['paused_at'] = Variable<int>(pausedAt.value);
    }
    if (plannedSeconds.present) {
      map['planned_seconds'] = Variable<int>(plannedSeconds.value);
    }
    if (actualSeconds.present) {
      map['actual_seconds'] = Variable<int>(actualSeconds.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $FocusSessionsTable.$converterkind.toSql(kind.value),
      );
    }
    if (timerMode.present) {
      map['timer_mode'] = Variable<int>(
        $FocusSessionsTable.$convertertimerMode.toSql(timerMode.value),
      );
    }
    if (logicalDate.present) {
      map['logical_date'] = Variable<int>(logicalDate.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FocusSessionsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedMillis: $pausedMillis, ')
          ..write('pausedAt: $pausedAt, ')
          ..write('plannedSeconds: $plannedSeconds, ')
          ..write('actualSeconds: $actualSeconds, ')
          ..write('kind: $kind, ')
          ..write('timerMode: $timerMode, ')
          ..write('logicalDate: $logicalDate, ')
          ..write('completed: $completed, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TaskListsTable taskLists = $TaskListsTable(this);
  late final $RecurrenceRulesTable recurrenceRules = $RecurrenceRulesTable(
    this,
  );
  late final $TasksTable tasks = $TasksTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TaskTagsTable taskTags = $TaskTagsTable(this);
  late final $SubtasksTable subtasks = $SubtasksTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $FocusSessionsTable focusSessions = $FocusSessionsTable(this);
  late final Index taskListsSortOrder = Index(
    'task_lists_sort_order',
    'CREATE INDEX task_lists_sort_order ON task_lists (sort_order)',
  );
  late final Index tasksStatus = Index(
    'tasks_status',
    'CREATE INDEX tasks_status ON tasks (status)',
  );
  late final Index tasksDueDate = Index(
    'tasks_due_date',
    'CREATE INDEX tasks_due_date ON tasks (due_date)',
  );
  late final Index tasksListId = Index(
    'tasks_list_id',
    'CREATE INDEX tasks_list_id ON tasks (list_id)',
  );
  late final Index tasksRecurrenceRuleId = Index(
    'tasks_recurrence_rule_id',
    'CREATE INDEX tasks_recurrence_rule_id ON tasks (recurrence_rule_id)',
  );
  late final Index tagsName = Index(
    'tags_name',
    'CREATE UNIQUE INDEX tags_name ON tags (name)',
  );
  late final Index taskTagsTagId = Index(
    'task_tags_tag_id',
    'CREATE INDEX task_tags_tag_id ON task_tags (tag_id)',
  );
  late final Index subtasksTaskId = Index(
    'subtasks_task_id',
    'CREATE INDEX subtasks_task_id ON subtasks (task_id)',
  );
  late final Index subtasksTaskSort = Index(
    'subtasks_task_sort',
    'CREATE INDEX subtasks_task_sort ON subtasks (task_id, sort_order)',
  );
  late final Index remindersTaskId = Index(
    'reminders_task_id',
    'CREATE INDEX reminders_task_id ON reminders (task_id)',
  );
  late final Index remindersRemindAt = Index(
    'reminders_remind_at',
    'CREATE INDEX reminders_remind_at ON reminders (remind_at)',
  );
  late final Index focusSessionsLogicalDate = Index(
    'focus_sessions_logical_date',
    'CREATE INDEX focus_sessions_logical_date ON focus_sessions (logical_date)',
  );
  late final Index focusSessionsTaskId = Index(
    'focus_sessions_task_id',
    'CREATE INDEX focus_sessions_task_id ON focus_sessions (task_id)',
  );
  late final Index focusSessionsStartedAt = Index(
    'focus_sessions_started_at',
    'CREATE INDEX focus_sessions_started_at ON focus_sessions (started_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    taskLists,
    recurrenceRules,
    tasks,
    tags,
    taskTags,
    subtasks,
    reminders,
    appSettings,
    focusSessions,
    taskListsSortOrder,
    tasksStatus,
    tasksDueDate,
    tasksListId,
    tasksRecurrenceRuleId,
    tagsName,
    taskTagsTagId,
    subtasksTaskId,
    subtasksTaskSort,
    remindersTaskId,
    remindersRemindAt,
    focusSessionsLogicalDate,
    focusSessionsTaskId,
    focusSessionsStartedAt,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'task_lists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recurrence_rules',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tasks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('task_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('subtasks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('focus_sessions', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$TaskListsTableCreateCompanionBuilder =
    TaskListsCompanion Function({
      required String id,
      required String name,
      Value<int?> color,
      Value<bool> isBuiltIn,
      Value<int> sortOrder,
      required int createdAt,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$TaskListsTableUpdateCompanionBuilder =
    TaskListsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int?> color,
      Value<bool> isBuiltIn,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$TaskListsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskListsTable, TaskList> {
  $$TaskListsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: $_aliasNameGenerator(db.taskLists.id, db.tasks.listId),
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.listId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TaskListsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskListsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TaskListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskListsTable> {
  $$TaskListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.listId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskListsTable,
          TaskList,
          $$TaskListsTableFilterComposer,
          $$TaskListsTableOrderingComposer,
          $$TaskListsTableAnnotationComposer,
          $$TaskListsTableCreateCompanionBuilder,
          $$TaskListsTableUpdateCompanionBuilder,
          (TaskList, $$TaskListsTableReferences),
          TaskList,
          PrefetchHooks Function({bool tasksRefs})
        > {
  $$TaskListsTableTableManager(_$AppDatabase db, $TaskListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TaskListsCompanion(
                id: id,
                name: name,
                color: color,
                isBuiltIn: isBuiltIn,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int?> color = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TaskListsCompanion.insert(
                id: id,
                name: name,
                color: color,
                isBuiltIn: isBuiltIn,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskListsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedData<TaskList, $TaskListsTable, Task>(
                      currentTable: table,
                      referencedTable: $$TaskListsTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TaskListsTableReferences(db, table, p0).tasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TaskListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskListsTable,
      TaskList,
      $$TaskListsTableFilterComposer,
      $$TaskListsTableOrderingComposer,
      $$TaskListsTableAnnotationComposer,
      $$TaskListsTableCreateCompanionBuilder,
      $$TaskListsTableUpdateCompanionBuilder,
      (TaskList, $$TaskListsTableReferences),
      TaskList,
      PrefetchHooks Function({bool tasksRefs})
    >;
typedef $$RecurrenceRulesTableCreateCompanionBuilder =
    RecurrenceRulesCompanion Function({
      required String id,
      required RecurrenceFrequency frequency,
      Value<int> interval,
      Value<int> startsOn,
      Value<String?> byWeekday,
      Value<String?> byMonthDay,
      Value<int?> endDate,
      Value<int?> endCount,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$RecurrenceRulesTableUpdateCompanionBuilder =
    RecurrenceRulesCompanion Function({
      Value<String> id,
      Value<RecurrenceFrequency> frequency,
      Value<int> interval,
      Value<int> startsOn,
      Value<String?> byWeekday,
      Value<String?> byMonthDay,
      Value<int?> endDate,
      Value<int?> endCount,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$RecurrenceRulesTableReferences
    extends
        BaseReferences<_$AppDatabase, $RecurrenceRulesTable, RecurrenceRule> {
  $$RecurrenceRulesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TasksTable, List<Task>> _tasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: $_aliasNameGenerator(
      db.recurrenceRules.id,
      db.tasks.recurrenceRuleId,
    ),
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager($_db, $_db.tasks).filter(
      (f) => f.recurrenceRuleId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecurrenceRulesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurrenceRulesTable> {
  $$RecurrenceRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RecurrenceFrequency, RecurrenceFrequency, int>
  get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byWeekday => $composableBuilder(
    column: $table.byWeekday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get byMonthDay => $composableBuilder(
    column: $table.byMonthDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endCount => $composableBuilder(
    column: $table.endCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.recurrenceRuleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurrenceRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurrenceRulesTable> {
  $$RecurrenceRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interval => $composableBuilder(
    column: $table.interval,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byWeekday => $composableBuilder(
    column: $table.byWeekday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get byMonthDay => $composableBuilder(
    column: $table.byMonthDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endCount => $composableBuilder(
    column: $table.endCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurrenceRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurrenceRulesTable> {
  $$RecurrenceRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecurrenceFrequency, int> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<int> get interval =>
      $composableBuilder(column: $table.interval, builder: (column) => column);

  GeneratedColumn<int> get startsOn =>
      $composableBuilder(column: $table.startsOn, builder: (column) => column);

  GeneratedColumn<String> get byWeekday =>
      $composableBuilder(column: $table.byWeekday, builder: (column) => column);

  GeneratedColumn<String> get byMonthDay => $composableBuilder(
    column: $table.byMonthDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<int> get endCount =>
      $composableBuilder(column: $table.endCount, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.recurrenceRuleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecurrenceRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurrenceRulesTable,
          RecurrenceRule,
          $$RecurrenceRulesTableFilterComposer,
          $$RecurrenceRulesTableOrderingComposer,
          $$RecurrenceRulesTableAnnotationComposer,
          $$RecurrenceRulesTableCreateCompanionBuilder,
          $$RecurrenceRulesTableUpdateCompanionBuilder,
          (RecurrenceRule, $$RecurrenceRulesTableReferences),
          RecurrenceRule,
          PrefetchHooks Function({bool tasksRefs})
        > {
  $$RecurrenceRulesTableTableManager(
    _$AppDatabase db,
    $RecurrenceRulesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurrenceRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurrenceRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecurrenceRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<RecurrenceFrequency> frequency = const Value.absent(),
                Value<int> interval = const Value.absent(),
                Value<int> startsOn = const Value.absent(),
                Value<String?> byWeekday = const Value.absent(),
                Value<String?> byMonthDay = const Value.absent(),
                Value<int?> endDate = const Value.absent(),
                Value<int?> endCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurrenceRulesCompanion(
                id: id,
                frequency: frequency,
                interval: interval,
                startsOn: startsOn,
                byWeekday: byWeekday,
                byMonthDay: byMonthDay,
                endDate: endDate,
                endCount: endCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required RecurrenceFrequency frequency,
                Value<int> interval = const Value.absent(),
                Value<int> startsOn = const Value.absent(),
                Value<String?> byWeekday = const Value.absent(),
                Value<String?> byMonthDay = const Value.absent(),
                Value<int?> endDate = const Value.absent(),
                Value<int?> endCount = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RecurrenceRulesCompanion.insert(
                id: id,
                frequency: frequency,
                interval: interval,
                startsOn: startsOn,
                byWeekday: byWeekday,
                byMonthDay: byMonthDay,
                endDate: endDate,
                endCount: endCount,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecurrenceRulesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (tasksRefs) db.tasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (tasksRefs)
                    await $_getPrefetchedData<
                      RecurrenceRule,
                      $RecurrenceRulesTable,
                      Task
                    >(
                      currentTable: table,
                      referencedTable: $$RecurrenceRulesTableReferences
                          ._tasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RecurrenceRulesTableReferences(
                            db,
                            table,
                            p0,
                          ).tasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.recurrenceRuleId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RecurrenceRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurrenceRulesTable,
      RecurrenceRule,
      $$RecurrenceRulesTableFilterComposer,
      $$RecurrenceRulesTableOrderingComposer,
      $$RecurrenceRulesTableAnnotationComposer,
      $$RecurrenceRulesTableCreateCompanionBuilder,
      $$RecurrenceRulesTableUpdateCompanionBuilder,
      (RecurrenceRule, $$RecurrenceRulesTableReferences),
      RecurrenceRule,
      PrefetchHooks Function({bool tasksRefs})
    >;
typedef $$TasksTableCreateCompanionBuilder =
    TasksCompanion Function({
      required String id,
      required String title,
      Value<String?> note,
      Value<int?> dueDate,
      Value<bool> dueDateHasTime,
      Value<TaskPriority> priority,
      Value<TaskStatus> status,
      Value<String?> listId,
      Value<String?> recurrenceRuleId,
      required int createdAt,
      required int updatedAt,
      Value<int?> completedAt,
      Value<int?> estimatedPomodoros,
      Value<int> rowid,
    });
typedef $$TasksTableUpdateCompanionBuilder =
    TasksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String?> note,
      Value<int?> dueDate,
      Value<bool> dueDateHasTime,
      Value<TaskPriority> priority,
      Value<TaskStatus> status,
      Value<String?> listId,
      Value<String?> recurrenceRuleId,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> completedAt,
      Value<int?> estimatedPomodoros,
      Value<int> rowid,
    });

final class $$TasksTableReferences
    extends BaseReferences<_$AppDatabase, $TasksTable, Task> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TaskListsTable _listIdTable(_$AppDatabase db) => db.taskLists
      .createAlias($_aliasNameGenerator(db.tasks.listId, db.taskLists.id));

  $$TaskListsTableProcessedTableManager? get listId {
    final $_column = $_itemColumn<String>('list_id');
    if ($_column == null) return null;
    final manager = $$TaskListsTableTableManager(
      $_db,
      $_db.taskLists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RecurrenceRulesTable _recurrenceRuleIdTable(_$AppDatabase db) =>
      db.recurrenceRules.createAlias(
        $_aliasNameGenerator(db.tasks.recurrenceRuleId, db.recurrenceRules.id),
      );

  $$RecurrenceRulesTableProcessedTableManager? get recurrenceRuleId {
    final $_column = $_itemColumn<String>('recurrence_rule_id');
    if ($_column == null) return null;
    final manager = $$RecurrenceRulesTableTableManager(
      $_db,
      $_db.recurrenceRules,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recurrenceRuleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TaskTagsTable, List<TaskTag>> _taskTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTags,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.taskTags.taskId),
  );

  $$TaskTagsTableProcessedTableManager get taskTagsRefs {
    final manager = $$TaskTagsTableTableManager(
      $_db,
      $_db.taskTags,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SubtasksTable, List<Subtask>> _subtasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.subtasks,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.subtasks.taskId),
  );

  $$SubtasksTableProcessedTableManager get subtasksRefs {
    final manager = $$SubtasksTableTableManager(
      $_db,
      $_db.subtasks,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subtasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<Reminder>>
  _remindersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.reminders.taskId),
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FocusSessionsTable, List<FocusSession>>
  _focusSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.focusSessions,
    aliasName: $_aliasNameGenerator(db.tasks.id, db.focusSessions.taskId),
  );

  $$FocusSessionsTableProcessedTableManager get focusSessionsRefs {
    final manager = $$FocusSessionsTableTableManager(
      $_db,
      $_db.focusSessions,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_focusSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dueDateHasTime => $composableBuilder(
    column: $table.dueDateHasTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskPriority, TaskPriority, int>
  get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskStatus, TaskStatus, int> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedPomodoros => $composableBuilder(
    column: $table.estimatedPomodoros,
    builder: (column) => ColumnFilters(column),
  );

  $$TaskListsTableFilterComposer get listId {
    final $$TaskListsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.taskLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskListsTableFilterComposer(
            $db: $db,
            $table: $db.taskLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurrenceRulesTableFilterComposer get recurrenceRuleId {
    final $$RecurrenceRulesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recurrenceRuleId,
      referencedTable: $db.recurrenceRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurrenceRulesTableFilterComposer(
            $db: $db,
            $table: $db.recurrenceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> taskTagsRefs(
    Expression<bool> Function($$TaskTagsTableFilterComposer f) f,
  ) {
    final $$TaskTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableFilterComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> subtasksRefs(
    Expression<bool> Function($$SubtasksTableFilterComposer f) f,
  ) {
    final $$SubtasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtasksTableFilterComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> focusSessionsRefs(
    Expression<bool> Function($$FocusSessionsTableFilterComposer f) f,
  ) {
    final $$FocusSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.focusSessions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FocusSessionsTableFilterComposer(
            $db: $db,
            $table: $db.focusSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dueDateHasTime => $composableBuilder(
    column: $table.dueDateHasTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedPomodoros => $composableBuilder(
    column: $table.estimatedPomodoros,
    builder: (column) => ColumnOrderings(column),
  );

  $$TaskListsTableOrderingComposer get listId {
    final $$TaskListsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.taskLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskListsTableOrderingComposer(
            $db: $db,
            $table: $db.taskLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurrenceRulesTableOrderingComposer get recurrenceRuleId {
    final $$RecurrenceRulesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recurrenceRuleId,
      referencedTable: $db.recurrenceRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurrenceRulesTableOrderingComposer(
            $db: $db,
            $table: $db.recurrenceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<bool> get dueDateHasTime => $composableBuilder(
    column: $table.dueDateHasTime,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TaskPriority, int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedPomodoros => $composableBuilder(
    column: $table.estimatedPomodoros,
    builder: (column) => column,
  );

  $$TaskListsTableAnnotationComposer get listId {
    final $$TaskListsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listId,
      referencedTable: $db.taskLists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskListsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskLists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RecurrenceRulesTableAnnotationComposer get recurrenceRuleId {
    final $$RecurrenceRulesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recurrenceRuleId,
      referencedTable: $db.recurrenceRules,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecurrenceRulesTableAnnotationComposer(
            $db: $db,
            $table: $db.recurrenceRules,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> taskTagsRefs<T extends Object>(
    Expression<T> Function($$TaskTagsTableAnnotationComposer a) f,
  ) {
    final $$TaskTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> subtasksRefs<T extends Object>(
    Expression<T> Function($$SubtasksTableAnnotationComposer a) f,
  ) {
    final $$SubtasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtasksTableAnnotationComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> focusSessionsRefs<T extends Object>(
    Expression<T> Function($$FocusSessionsTableAnnotationComposer a) f,
  ) {
    final $$FocusSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.focusSessions,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FocusSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.focusSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TasksTable,
          Task,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (Task, $$TasksTableReferences),
          Task,
          PrefetchHooks Function({
            bool listId,
            bool recurrenceRuleId,
            bool taskTagsRefs,
            bool subtasksRefs,
            bool remindersRefs,
            bool focusSessionsRefs,
          })
        > {
  $$TasksTableTableManager(_$AppDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> dueDate = const Value.absent(),
                Value<bool> dueDateHasTime = const Value.absent(),
                Value<TaskPriority> priority = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<String?> listId = const Value.absent(),
                Value<String?> recurrenceRuleId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<int?> estimatedPomodoros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                title: title,
                note: note,
                dueDate: dueDate,
                dueDateHasTime: dueDateHasTime,
                priority: priority,
                status: status,
                listId: listId,
                recurrenceRuleId: recurrenceRuleId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                estimatedPomodoros: estimatedPomodoros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String?> note = const Value.absent(),
                Value<int?> dueDate = const Value.absent(),
                Value<bool> dueDateHasTime = const Value.absent(),
                Value<TaskPriority> priority = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<String?> listId = const Value.absent(),
                Value<String?> recurrenceRuleId = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> completedAt = const Value.absent(),
                Value<int?> estimatedPomodoros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                title: title,
                note: note,
                dueDate: dueDate,
                dueDateHasTime: dueDateHasTime,
                priority: priority,
                status: status,
                listId: listId,
                recurrenceRuleId: recurrenceRuleId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                estimatedPomodoros: estimatedPomodoros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                listId = false,
                recurrenceRuleId = false,
                taskTagsRefs = false,
                subtasksRefs = false,
                remindersRefs = false,
                focusSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskTagsRefs) db.taskTags,
                    if (subtasksRefs) db.subtasks,
                    if (remindersRefs) db.reminders,
                    if (focusSessionsRefs) db.focusSessions,
                  ],
                  addJoins:
                      <
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
                          dynamic
                        >
                      >(state) {
                        if (listId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.listId,
                                    referencedTable: $$TasksTableReferences
                                        ._listIdTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._listIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (recurrenceRuleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.recurrenceRuleId,
                                    referencedTable: $$TasksTableReferences
                                        ._recurrenceRuleIdTable(db),
                                    referencedColumn: $$TasksTableReferences
                                        ._recurrenceRuleIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskTagsRefs)
                        await $_getPrefetchedData<Task, $TasksTable, TaskTag>(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._taskTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).taskTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (subtasksRefs)
                        await $_getPrefetchedData<Task, $TasksTable, Subtask>(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._subtasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).subtasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remindersRefs)
                        await $_getPrefetchedData<Task, $TasksTable, Reminder>(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._remindersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).remindersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (focusSessionsRefs)
                        await $_getPrefetchedData<
                          Task,
                          $TasksTable,
                          FocusSession
                        >(
                          currentTable: table,
                          referencedTable: $$TasksTableReferences
                              ._focusSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TasksTableReferences(
                                db,
                                table,
                                p0,
                              ).focusSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.taskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TasksTable,
      Task,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (Task, $$TasksTableReferences),
      Task,
      PrefetchHooks Function({
        bool listId,
        bool recurrenceRuleId,
        bool taskTagsRefs,
        bool subtasksRefs,
        bool remindersRefs,
        bool focusSessionsRefs,
      })
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      Value<int?> color,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int?> color,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TaskTagsTable, List<TaskTag>> _taskTagsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.taskTags.tagId),
  );

  $$TaskTagsTableProcessedTableManager get taskTagsRefs {
    final manager = $$TaskTagsTableTableManager(
      $_db,
      $_db.taskTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskTagsRefs(
    Expression<bool> Function($$TaskTagsTableFilterComposer f) f,
  ) {
    final $$TaskTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableFilterComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> taskTagsRefs<T extends Object>(
    Expression<T> Function($$TaskTagsTableAnnotationComposer a) f,
  ) {
    final $$TaskTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool taskTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int?> color = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({taskTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (taskTagsRefs) db.taskTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (taskTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, TaskTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences._taskTagsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).taskTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool taskTagsRefs})
    >;
typedef $$TaskTagsTableCreateCompanionBuilder =
    TaskTagsCompanion Function({
      required String taskId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$TaskTagsTableUpdateCompanionBuilder =
    TaskTagsCompanion Function({
      Value<String> taskId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$TaskTagsTableReferences
    extends BaseReferences<_$AppDatabase, $TaskTagsTable, TaskTag> {
  $$TaskTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.taskTags.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias($_aliasNameGenerator(db.taskTags.tagId, db.tags.id));

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TaskTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTagsTable> {
  $$TaskTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskTagsTable,
          TaskTag,
          $$TaskTagsTableFilterComposer,
          $$TaskTagsTableOrderingComposer,
          $$TaskTagsTableAnnotationComposer,
          $$TaskTagsTableCreateCompanionBuilder,
          $$TaskTagsTableUpdateCompanionBuilder,
          (TaskTag, $$TaskTagsTableReferences),
          TaskTag,
          PrefetchHooks Function({bool taskId, bool tagId})
        > {
  $$TaskTagsTableTableManager(_$AppDatabase db, $TaskTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> taskId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  TaskTagsCompanion(taskId: taskId, tagId: tagId, rowid: rowid),
          createCompanionCallback:
              ({
                required String taskId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TaskTagsCompanion.insert(
                taskId: taskId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TaskTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$TaskTagsTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$TaskTagsTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$TaskTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$TaskTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TaskTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskTagsTable,
      TaskTag,
      $$TaskTagsTableFilterComposer,
      $$TaskTagsTableOrderingComposer,
      $$TaskTagsTableAnnotationComposer,
      $$TaskTagsTableCreateCompanionBuilder,
      $$TaskTagsTableUpdateCompanionBuilder,
      (TaskTag, $$TaskTagsTableReferences),
      TaskTag,
      PrefetchHooks Function({bool taskId, bool tagId})
    >;
typedef $$SubtasksTableCreateCompanionBuilder =
    SubtasksCompanion Function({
      required String id,
      required String taskId,
      required String title,
      Value<bool> isDone,
      Value<int> sortOrder,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SubtasksTableUpdateCompanionBuilder =
    SubtasksCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<String> title,
      Value<bool> isDone,
      Value<int> sortOrder,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$SubtasksTableReferences
    extends BaseReferences<_$AppDatabase, $SubtasksTable, Subtask> {
  $$SubtasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.subtasks.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubtasksTableFilterComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubtasksTable,
          Subtask,
          $$SubtasksTableFilterComposer,
          $$SubtasksTableOrderingComposer,
          $$SubtasksTableAnnotationComposer,
          $$SubtasksTableCreateCompanionBuilder,
          $$SubtasksTableUpdateCompanionBuilder,
          (Subtask, $$SubtasksTableReferences),
          Subtask,
          PrefetchHooks Function({bool taskId})
        > {
  $$SubtasksTableTableManager(_$AppDatabase db, $SubtasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion(
                id: id,
                taskId: taskId,
                title: title,
                isDone: isDone,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String title,
                Value<bool> isDone = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SubtasksCompanion.insert(
                id: id,
                taskId: taskId,
                title: title,
                isDone: isDone,
                sortOrder: sortOrder,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubtasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$SubtasksTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$SubtasksTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubtasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubtasksTable,
      Subtask,
      $$SubtasksTableFilterComposer,
      $$SubtasksTableOrderingComposer,
      $$SubtasksTableAnnotationComposer,
      $$SubtasksTableCreateCompanionBuilder,
      $$SubtasksTableUpdateCompanionBuilder,
      (Subtask, $$SubtasksTableReferences),
      Subtask,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$RemindersTableCreateCompanionBuilder =
    RemindersCompanion Function({
      required String id,
      required String taskId,
      required int remindAt,
      Value<ReminderRepeatType> repeatType,
      Value<bool> enabled,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$RemindersTableUpdateCompanionBuilder =
    RemindersCompanion Function({
      Value<String> id,
      Value<String> taskId,
      Value<int> remindAt,
      Value<ReminderRepeatType> repeatType,
      Value<bool> enabled,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$RemindersTableReferences
    extends BaseReferences<_$AppDatabase, $RemindersTable, Reminder> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.reminders.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReminderRepeatType, ReminderRepeatType, int>
  get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindAt => $composableBuilder(
    column: $table.remindAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remindAt =>
      $composableBuilder(column: $table.remindAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderRepeatType, int> get repeatType =>
      $composableBuilder(
        column: $table.repeatType,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, $$RemindersTableReferences),
          Reminder,
          PrefetchHooks Function({bool taskId})
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<int> remindAt = const Value.absent(),
                Value<ReminderRepeatType> repeatType = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                taskId: taskId,
                remindAt: remindAt,
                repeatType: repeatType,
                enabled: enabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required int remindAt,
                Value<ReminderRepeatType> repeatType = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                taskId: taskId,
                remindAt: remindAt,
                repeatType: repeatType,
                enabled: enabled,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$RemindersTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$RemindersTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, $$RemindersTableReferences),
      Reminder,
      PrefetchHooks Function({bool taskId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<ThemeModeSetting> themeMode,
      Value<DefaultView> defaultView,
      Value<bool> notificationsEnabled,
      Value<bool> strongReminders,
      Value<int> focusMinutes,
      Value<int> shortBreakMinutes,
      Value<int> longBreakMinutes,
      Value<int> roundsBeforeLongBreak,
      Value<bool> autoStartNext,
      Value<FocusTimerMode> defaultTimerMode,
      Value<bool> midnightMode,
      Value<int> midnightEndHour,
      Value<int?> initializedAt,
      Value<int?> updatedAt,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<ThemeModeSetting> themeMode,
      Value<DefaultView> defaultView,
      Value<bool> notificationsEnabled,
      Value<bool> strongReminders,
      Value<int> focusMinutes,
      Value<int> shortBreakMinutes,
      Value<int> longBreakMinutes,
      Value<int> roundsBeforeLongBreak,
      Value<bool> autoStartNext,
      Value<FocusTimerMode> defaultTimerMode,
      Value<bool> midnightMode,
      Value<int> midnightEndHour,
      Value<int?> initializedAt,
      Value<int?> updatedAt,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ThemeModeSetting, ThemeModeSetting, int>
  get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DefaultView, DefaultView, int>
  get defaultView => $composableBuilder(
    column: $table.defaultView,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get strongReminders => $composableBuilder(
    column: $table.strongReminders,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get shortBreakMinutes => $composableBuilder(
    column: $table.shortBreakMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longBreakMinutes => $composableBuilder(
    column: $table.longBreakMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roundsBeforeLongBreak => $composableBuilder(
    column: $table.roundsBeforeLongBreak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoStartNext => $composableBuilder(
    column: $table.autoStartNext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FocusTimerMode, FocusTimerMode, int>
  get defaultTimerMode => $composableBuilder(
    column: $table.defaultTimerMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get midnightMode => $composableBuilder(
    column: $table.midnightMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get midnightEndHour => $composableBuilder(
    column: $table.midnightEndHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initializedAt => $composableBuilder(
    column: $table.initializedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultView => $composableBuilder(
    column: $table.defaultView,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get strongReminders => $composableBuilder(
    column: $table.strongReminders,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get shortBreakMinutes => $composableBuilder(
    column: $table.shortBreakMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longBreakMinutes => $composableBuilder(
    column: $table.longBreakMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roundsBeforeLongBreak => $composableBuilder(
    column: $table.roundsBeforeLongBreak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoStartNext => $composableBuilder(
    column: $table.autoStartNext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultTimerMode => $composableBuilder(
    column: $table.defaultTimerMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get midnightMode => $composableBuilder(
    column: $table.midnightMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get midnightEndHour => $composableBuilder(
    column: $table.midnightEndHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initializedAt => $composableBuilder(
    column: $table.initializedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ThemeModeSetting, int> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DefaultView, int> get defaultView =>
      $composableBuilder(
        column: $table.defaultView,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get notificationsEnabled => $composableBuilder(
    column: $table.notificationsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get strongReminders => $composableBuilder(
    column: $table.strongReminders,
    builder: (column) => column,
  );

  GeneratedColumn<int> get focusMinutes => $composableBuilder(
    column: $table.focusMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get shortBreakMinutes => $composableBuilder(
    column: $table.shortBreakMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get longBreakMinutes => $composableBuilder(
    column: $table.longBreakMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get roundsBeforeLongBreak => $composableBuilder(
    column: $table.roundsBeforeLongBreak,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoStartNext => $composableBuilder(
    column: $table.autoStartNext,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FocusTimerMode, int> get defaultTimerMode =>
      $composableBuilder(
        column: $table.defaultTimerMode,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get midnightMode => $composableBuilder(
    column: $table.midnightMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get midnightEndHour => $composableBuilder(
    column: $table.midnightEndHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get initializedAt => $composableBuilder(
    column: $table.initializedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<ThemeModeSetting> themeMode = const Value.absent(),
                Value<DefaultView> defaultView = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> strongReminders = const Value.absent(),
                Value<int> focusMinutes = const Value.absent(),
                Value<int> shortBreakMinutes = const Value.absent(),
                Value<int> longBreakMinutes = const Value.absent(),
                Value<int> roundsBeforeLongBreak = const Value.absent(),
                Value<bool> autoStartNext = const Value.absent(),
                Value<FocusTimerMode> defaultTimerMode = const Value.absent(),
                Value<bool> midnightMode = const Value.absent(),
                Value<int> midnightEndHour = const Value.absent(),
                Value<int?> initializedAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                themeMode: themeMode,
                defaultView: defaultView,
                notificationsEnabled: notificationsEnabled,
                strongReminders: strongReminders,
                focusMinutes: focusMinutes,
                shortBreakMinutes: shortBreakMinutes,
                longBreakMinutes: longBreakMinutes,
                roundsBeforeLongBreak: roundsBeforeLongBreak,
                autoStartNext: autoStartNext,
                defaultTimerMode: defaultTimerMode,
                midnightMode: midnightMode,
                midnightEndHour: midnightEndHour,
                initializedAt: initializedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<ThemeModeSetting> themeMode = const Value.absent(),
                Value<DefaultView> defaultView = const Value.absent(),
                Value<bool> notificationsEnabled = const Value.absent(),
                Value<bool> strongReminders = const Value.absent(),
                Value<int> focusMinutes = const Value.absent(),
                Value<int> shortBreakMinutes = const Value.absent(),
                Value<int> longBreakMinutes = const Value.absent(),
                Value<int> roundsBeforeLongBreak = const Value.absent(),
                Value<bool> autoStartNext = const Value.absent(),
                Value<FocusTimerMode> defaultTimerMode = const Value.absent(),
                Value<bool> midnightMode = const Value.absent(),
                Value<int> midnightEndHour = const Value.absent(),
                Value<int?> initializedAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                themeMode: themeMode,
                defaultView: defaultView,
                notificationsEnabled: notificationsEnabled,
                strongReminders: strongReminders,
                focusMinutes: focusMinutes,
                shortBreakMinutes: shortBreakMinutes,
                longBreakMinutes: longBreakMinutes,
                roundsBeforeLongBreak: roundsBeforeLongBreak,
                autoStartNext: autoStartNext,
                defaultTimerMode: defaultTimerMode,
                midnightMode: midnightMode,
                midnightEndHour: midnightEndHour,
                initializedAt: initializedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$FocusSessionsTableCreateCompanionBuilder =
    FocusSessionsCompanion Function({
      required String id,
      Value<String?> taskId,
      required int startedAt,
      Value<int?> endedAt,
      Value<int> pausedMillis,
      Value<int?> pausedAt,
      Value<int?> plannedSeconds,
      Value<int> actualSeconds,
      Value<FocusSessionKind> kind,
      Value<FocusTimerMode> timerMode,
      required int logicalDate,
      Value<bool> completed,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$FocusSessionsTableUpdateCompanionBuilder =
    FocusSessionsCompanion Function({
      Value<String> id,
      Value<String?> taskId,
      Value<int> startedAt,
      Value<int?> endedAt,
      Value<int> pausedMillis,
      Value<int?> pausedAt,
      Value<int?> plannedSeconds,
      Value<int> actualSeconds,
      Value<FocusSessionKind> kind,
      Value<FocusTimerMode> timerMode,
      Value<int> logicalDate,
      Value<bool> completed,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$FocusSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $FocusSessionsTable, FocusSession> {
  $$FocusSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TasksTable _taskIdTable(_$AppDatabase db) => db.tasks.createAlias(
    $_aliasNameGenerator(db.focusSessions.taskId, db.tasks.id),
  );

  $$TasksTableProcessedTableManager? get taskId {
    final $_column = $_itemColumn<String>('task_id');
    if ($_column == null) return null;
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FocusSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedMillis => $composableBuilder(
    column: $table.pausedMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedSeconds => $composableBuilder(
    column: $table.plannedSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualSeconds => $composableBuilder(
    column: $table.actualSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FocusSessionKind, FocusSessionKind, int>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<FocusTimerMode, FocusTimerMode, int>
  get timerMode => $composableBuilder(
    column: $table.timerMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get logicalDate => $composableBuilder(
    column: $table.logicalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FocusSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedMillis => $composableBuilder(
    column: $table.pausedMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pausedAt => $composableBuilder(
    column: $table.pausedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedSeconds => $composableBuilder(
    column: $table.plannedSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualSeconds => $composableBuilder(
    column: $table.actualSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timerMode => $composableBuilder(
    column: $table.timerMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get logicalDate => $composableBuilder(
    column: $table.logicalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FocusSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FocusSessionsTable> {
  $$FocusSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get pausedMillis => $composableBuilder(
    column: $table.pausedMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pausedAt =>
      $composableBuilder(column: $table.pausedAt, builder: (column) => column);

  GeneratedColumn<int> get plannedSeconds => $composableBuilder(
    column: $table.plannedSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualSeconds => $composableBuilder(
    column: $table.actualSeconds,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FocusSessionKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FocusTimerMode, int> get timerMode =>
      $composableBuilder(column: $table.timerMode, builder: (column) => column);

  GeneratedColumn<int> get logicalDate => $composableBuilder(
    column: $table.logicalDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FocusSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FocusSessionsTable,
          FocusSession,
          $$FocusSessionsTableFilterComposer,
          $$FocusSessionsTableOrderingComposer,
          $$FocusSessionsTableAnnotationComposer,
          $$FocusSessionsTableCreateCompanionBuilder,
          $$FocusSessionsTableUpdateCompanionBuilder,
          (FocusSession, $$FocusSessionsTableReferences),
          FocusSession,
          PrefetchHooks Function({bool taskId})
        > {
  $$FocusSessionsTableTableManager(_$AppDatabase db, $FocusSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FocusSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FocusSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FocusSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> taskId = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<int> pausedMillis = const Value.absent(),
                Value<int?> pausedAt = const Value.absent(),
                Value<int?> plannedSeconds = const Value.absent(),
                Value<int> actualSeconds = const Value.absent(),
                Value<FocusSessionKind> kind = const Value.absent(),
                Value<FocusTimerMode> timerMode = const Value.absent(),
                Value<int> logicalDate = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion(
                id: id,
                taskId: taskId,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedMillis: pausedMillis,
                pausedAt: pausedAt,
                plannedSeconds: plannedSeconds,
                actualSeconds: actualSeconds,
                kind: kind,
                timerMode: timerMode,
                logicalDate: logicalDate,
                completed: completed,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> taskId = const Value.absent(),
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                Value<int> pausedMillis = const Value.absent(),
                Value<int?> pausedAt = const Value.absent(),
                Value<int?> plannedSeconds = const Value.absent(),
                Value<int> actualSeconds = const Value.absent(),
                Value<FocusSessionKind> kind = const Value.absent(),
                Value<FocusTimerMode> timerMode = const Value.absent(),
                required int logicalDate,
                Value<bool> completed = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FocusSessionsCompanion.insert(
                id: id,
                taskId: taskId,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedMillis: pausedMillis,
                pausedAt: pausedAt,
                plannedSeconds: plannedSeconds,
                actualSeconds: actualSeconds,
                kind: kind,
                timerMode: timerMode,
                logicalDate: logicalDate,
                completed: completed,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FocusSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({taskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
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
                      dynamic
                    >
                  >(state) {
                    if (taskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.taskId,
                                referencedTable: $$FocusSessionsTableReferences
                                    ._taskIdTable(db),
                                referencedColumn: $$FocusSessionsTableReferences
                                    ._taskIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FocusSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FocusSessionsTable,
      FocusSession,
      $$FocusSessionsTableFilterComposer,
      $$FocusSessionsTableOrderingComposer,
      $$FocusSessionsTableAnnotationComposer,
      $$FocusSessionsTableCreateCompanionBuilder,
      $$FocusSessionsTableUpdateCompanionBuilder,
      (FocusSession, $$FocusSessionsTableReferences),
      FocusSession,
      PrefetchHooks Function({bool taskId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TaskListsTableTableManager get taskLists =>
      $$TaskListsTableTableManager(_db, _db.taskLists);
  $$RecurrenceRulesTableTableManager get recurrenceRules =>
      $$RecurrenceRulesTableTableManager(_db, _db.recurrenceRules);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TaskTagsTableTableManager get taskTags =>
      $$TaskTagsTableTableManager(_db, _db.taskTags);
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db, _db.subtasks);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$FocusSessionsTableTableManager get focusSessions =>
      $$FocusSessionsTableTableManager(_db, _db.focusSessions);
}
