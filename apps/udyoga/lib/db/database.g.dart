// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $JobListingsTable extends JobListings with TableInfo<$JobListingsTable, Job> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobListingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyMeta = const VerificationMeta('company');
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _countryMeta = const VerificationMeta('country');
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _remoteMeta = const VerificationMeta('remote');
  @override
  late final GeneratedColumn<bool> remote = GeneratedColumn<bool>(
    'remote',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("remote" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _salaryMinMeta = const VerificationMeta('salaryMin');
  @override
  late final GeneratedColumn<int> salaryMin = GeneratedColumn<int>(
    'salary_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _salaryMaxMeta = const VerificationMeta('salaryMax');
  @override
  late final GeneratedColumn<int> salaryMax = GeneratedColumn<int>(
    'salary_max',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _salaryTextMeta = const VerificationMeta('salaryText');
  @override
  late final GeneratedColumn<String> salaryText = GeneratedColumn<String>(
    'salary_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _postedMeta = const VerificationMeta('posted');
  @override
  late final GeneratedColumn<String> posted = GeneratedColumn<String>(
    'posted',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closingMeta = const VerificationMeta('closing');
  @override
  late final GeneratedColumn<String> closing = GeneratedColumn<String>(
    'closing',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _foundMeta = const VerificationMeta('found');
  @override
  late final GeneratedColumn<String> found = GeneratedColumn<String>(
    'found',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _fitMeta = const VerificationMeta('fit');
  @override
  late final GeneratedColumn<int> fit = GeneratedColumn<int>(
    'fit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assessmentMeta = const VerificationMeta('assessment');
  @override
  late final GeneratedColumn<String> assessment = GeneratedColumn<String>(
    'assessment',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hlc,
    deleted,
    title,
    company,
    location,
    country,
    remote,
    salaryMin,
    salaryMax,
    currency,
    salaryText,
    url,
    description,
    posted,
    closing,
    source,
    sourceId,
    found,
    status,
    fit,
    assessment,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'job_listings';
  @override
  VerificationContext validateIntegrity(Insertable<Job> instance, {bool isInserting = false}) {
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
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('company')) {
      context.handle(_companyMeta, company.isAcceptableOrUnknown(data['company']!, _companyMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta, location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('country')) {
      context.handle(_countryMeta, country.isAcceptableOrUnknown(data['country']!, _countryMeta));
    }
    if (data.containsKey('remote')) {
      context.handle(_remoteMeta, remote.isAcceptableOrUnknown(data['remote']!, _remoteMeta));
    }
    if (data.containsKey('salary_min')) {
      context.handle(_salaryMinMeta, salaryMin.isAcceptableOrUnknown(data['salary_min']!, _salaryMinMeta));
    }
    if (data.containsKey('salary_max')) {
      context.handle(_salaryMaxMeta, salaryMax.isAcceptableOrUnknown(data['salary_max']!, _salaryMaxMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta, currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('salary_text')) {
      context.handle(
        _salaryTextMeta,
        salaryText.isAcceptableOrUnknown(data['salary_text']!, _salaryTextMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(data['description']!, _descriptionMeta),
      );
    }
    if (data.containsKey('posted')) {
      context.handle(_postedMeta, posted.isAcceptableOrUnknown(data['posted']!, _postedMeta));
    }
    if (data.containsKey('closing')) {
      context.handle(_closingMeta, closing.isAcceptableOrUnknown(data['closing']!, _closingMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta, sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    }
    if (data.containsKey('found')) {
      context.handle(_foundMeta, found.isAcceptableOrUnknown(data['found']!, _foundMeta));
    } else if (isInserting) {
      context.missing(_foundMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('fit')) {
      context.handle(_fitMeta, fit.isAcceptableOrUnknown(data['fit']!, _fitMeta));
    }
    if (data.containsKey('assessment')) {
      context.handle(_assessmentMeta, assessment.isAcceptableOrUnknown(data['assessment']!, _assessmentMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Job map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Job(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      company: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}company'])!,
      location: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}location'])!,
      country: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}country'])!,
      remote: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}remote'])!,
      salaryMin: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}salary_min']),
      salaryMax: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}salary_max']),
      currency: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      salaryText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salary_text'],
      )!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      posted: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}posted']),
      closing: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}closing']),
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      sourceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      found: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}found'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      fit: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}fit']),
      assessment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assessment'],
      )!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
    );
  }

  @override
  $JobListingsTable createAlias(String alias) {
    return $JobListingsTable(attachedDatabase, alias);
  }
}

class Job extends DataClass implements Insertable<Job> {
  final String id;
  final String hlc;
  final bool deleted;
  final String title;
  final String company;
  final String location;

  /// ISO 3166 alpha-2, upper case ('GB', 'IE', 'IN'); '' when unknown.
  final String country;
  final bool remote;

  /// Yearly figures in [currency] when the advert gives them.
  final int? salaryMin;
  final int? salaryMax;
  final String currency;

  /// The advert's own wording ("£24,000 - £26,500 a year", "Band 4").
  final String salaryText;
  final String url;
  final String description;
  final String? posted;
  final String? closing;

  /// adzuna | reed | arbeitnow | remotive | jobicy | ai | manual; with the
  /// source's own id, so a refresh updates instead of duplicating.
  final String source;
  final String sourceId;
  final String found;

  /// new | saved | dismissed | applied
  final String status;

  /// 0 to 100: the AI's when it has assessed the job, else the local match.
  final int? fit;

  /// The AI's assessment (FitAssessment), '' until asked.
  final String assessment;
  final String notes;
  const Job({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.title,
    required this.company,
    required this.location,
    required this.country,
    required this.remote,
    this.salaryMin,
    this.salaryMax,
    required this.currency,
    required this.salaryText,
    required this.url,
    required this.description,
    this.posted,
    this.closing,
    required this.source,
    required this.sourceId,
    required this.found,
    required this.status,
    this.fit,
    required this.assessment,
    required this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['title'] = Variable<String>(title);
    map['company'] = Variable<String>(company);
    map['location'] = Variable<String>(location);
    map['country'] = Variable<String>(country);
    map['remote'] = Variable<bool>(remote);
    if (!nullToAbsent || salaryMin != null) {
      map['salary_min'] = Variable<int>(salaryMin);
    }
    if (!nullToAbsent || salaryMax != null) {
      map['salary_max'] = Variable<int>(salaryMax);
    }
    map['currency'] = Variable<String>(currency);
    map['salary_text'] = Variable<String>(salaryText);
    map['url'] = Variable<String>(url);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || posted != null) {
      map['posted'] = Variable<String>(posted);
    }
    if (!nullToAbsent || closing != null) {
      map['closing'] = Variable<String>(closing);
    }
    map['source'] = Variable<String>(source);
    map['source_id'] = Variable<String>(sourceId);
    map['found'] = Variable<String>(found);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || fit != null) {
      map['fit'] = Variable<int>(fit);
    }
    map['assessment'] = Variable<String>(assessment);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  JobListingsCompanion toCompanion(bool nullToAbsent) {
    return JobListingsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      title: Value(title),
      company: Value(company),
      location: Value(location),
      country: Value(country),
      remote: Value(remote),
      salaryMin: salaryMin == null && nullToAbsent ? const Value.absent() : Value(salaryMin),
      salaryMax: salaryMax == null && nullToAbsent ? const Value.absent() : Value(salaryMax),
      currency: Value(currency),
      salaryText: Value(salaryText),
      url: Value(url),
      description: Value(description),
      posted: posted == null && nullToAbsent ? const Value.absent() : Value(posted),
      closing: closing == null && nullToAbsent ? const Value.absent() : Value(closing),
      source: Value(source),
      sourceId: Value(sourceId),
      found: Value(found),
      status: Value(status),
      fit: fit == null && nullToAbsent ? const Value.absent() : Value(fit),
      assessment: Value(assessment),
      notes: Value(notes),
    );
  }

  factory Job.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Job(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      title: serializer.fromJson<String>(json['title']),
      company: serializer.fromJson<String>(json['company']),
      location: serializer.fromJson<String>(json['location']),
      country: serializer.fromJson<String>(json['country']),
      remote: serializer.fromJson<bool>(json['remote']),
      salaryMin: serializer.fromJson<int?>(json['salaryMin']),
      salaryMax: serializer.fromJson<int?>(json['salaryMax']),
      currency: serializer.fromJson<String>(json['currency']),
      salaryText: serializer.fromJson<String>(json['salaryText']),
      url: serializer.fromJson<String>(json['url']),
      description: serializer.fromJson<String>(json['description']),
      posted: serializer.fromJson<String?>(json['posted']),
      closing: serializer.fromJson<String?>(json['closing']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      found: serializer.fromJson<String>(json['found']),
      status: serializer.fromJson<String>(json['status']),
      fit: serializer.fromJson<int?>(json['fit']),
      assessment: serializer.fromJson<String>(json['assessment']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'title': serializer.toJson<String>(title),
      'company': serializer.toJson<String>(company),
      'location': serializer.toJson<String>(location),
      'country': serializer.toJson<String>(country),
      'remote': serializer.toJson<bool>(remote),
      'salaryMin': serializer.toJson<int?>(salaryMin),
      'salaryMax': serializer.toJson<int?>(salaryMax),
      'currency': serializer.toJson<String>(currency),
      'salaryText': serializer.toJson<String>(salaryText),
      'url': serializer.toJson<String>(url),
      'description': serializer.toJson<String>(description),
      'posted': serializer.toJson<String?>(posted),
      'closing': serializer.toJson<String?>(closing),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String>(sourceId),
      'found': serializer.toJson<String>(found),
      'status': serializer.toJson<String>(status),
      'fit': serializer.toJson<int?>(fit),
      'assessment': serializer.toJson<String>(assessment),
      'notes': serializer.toJson<String>(notes),
    };
  }

  Job copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? title,
    String? company,
    String? location,
    String? country,
    bool? remote,
    Value<int?> salaryMin = const Value.absent(),
    Value<int?> salaryMax = const Value.absent(),
    String? currency,
    String? salaryText,
    String? url,
    String? description,
    Value<String?> posted = const Value.absent(),
    Value<String?> closing = const Value.absent(),
    String? source,
    String? sourceId,
    String? found,
    String? status,
    Value<int?> fit = const Value.absent(),
    String? assessment,
    String? notes,
  }) => Job(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    title: title ?? this.title,
    company: company ?? this.company,
    location: location ?? this.location,
    country: country ?? this.country,
    remote: remote ?? this.remote,
    salaryMin: salaryMin.present ? salaryMin.value : this.salaryMin,
    salaryMax: salaryMax.present ? salaryMax.value : this.salaryMax,
    currency: currency ?? this.currency,
    salaryText: salaryText ?? this.salaryText,
    url: url ?? this.url,
    description: description ?? this.description,
    posted: posted.present ? posted.value : this.posted,
    closing: closing.present ? closing.value : this.closing,
    source: source ?? this.source,
    sourceId: sourceId ?? this.sourceId,
    found: found ?? this.found,
    status: status ?? this.status,
    fit: fit.present ? fit.value : this.fit,
    assessment: assessment ?? this.assessment,
    notes: notes ?? this.notes,
  );
  Job copyWithCompanion(JobListingsCompanion data) {
    return Job(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      title: data.title.present ? data.title.value : this.title,
      company: data.company.present ? data.company.value : this.company,
      location: data.location.present ? data.location.value : this.location,
      country: data.country.present ? data.country.value : this.country,
      remote: data.remote.present ? data.remote.value : this.remote,
      salaryMin: data.salaryMin.present ? data.salaryMin.value : this.salaryMin,
      salaryMax: data.salaryMax.present ? data.salaryMax.value : this.salaryMax,
      currency: data.currency.present ? data.currency.value : this.currency,
      salaryText: data.salaryText.present ? data.salaryText.value : this.salaryText,
      url: data.url.present ? data.url.value : this.url,
      description: data.description.present ? data.description.value : this.description,
      posted: data.posted.present ? data.posted.value : this.posted,
      closing: data.closing.present ? data.closing.value : this.closing,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      found: data.found.present ? data.found.value : this.found,
      status: data.status.present ? data.status.value : this.status,
      fit: data.fit.present ? data.fit.value : this.fit,
      assessment: data.assessment.present ? data.assessment.value : this.assessment,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Job(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('title: $title, ')
          ..write('company: $company, ')
          ..write('location: $location, ')
          ..write('country: $country, ')
          ..write('remote: $remote, ')
          ..write('salaryMin: $salaryMin, ')
          ..write('salaryMax: $salaryMax, ')
          ..write('currency: $currency, ')
          ..write('salaryText: $salaryText, ')
          ..write('url: $url, ')
          ..write('description: $description, ')
          ..write('posted: $posted, ')
          ..write('closing: $closing, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('found: $found, ')
          ..write('status: $status, ')
          ..write('fit: $fit, ')
          ..write('assessment: $assessment, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    hlc,
    deleted,
    title,
    company,
    location,
    country,
    remote,
    salaryMin,
    salaryMax,
    currency,
    salaryText,
    url,
    description,
    posted,
    closing,
    source,
    sourceId,
    found,
    status,
    fit,
    assessment,
    notes,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Job &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.title == this.title &&
          other.company == this.company &&
          other.location == this.location &&
          other.country == this.country &&
          other.remote == this.remote &&
          other.salaryMin == this.salaryMin &&
          other.salaryMax == this.salaryMax &&
          other.currency == this.currency &&
          other.salaryText == this.salaryText &&
          other.url == this.url &&
          other.description == this.description &&
          other.posted == this.posted &&
          other.closing == this.closing &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.found == this.found &&
          other.status == this.status &&
          other.fit == this.fit &&
          other.assessment == this.assessment &&
          other.notes == this.notes);
}

class JobListingsCompanion extends UpdateCompanion<Job> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> title;
  final Value<String> company;
  final Value<String> location;
  final Value<String> country;
  final Value<bool> remote;
  final Value<int?> salaryMin;
  final Value<int?> salaryMax;
  final Value<String> currency;
  final Value<String> salaryText;
  final Value<String> url;
  final Value<String> description;
  final Value<String?> posted;
  final Value<String?> closing;
  final Value<String> source;
  final Value<String> sourceId;
  final Value<String> found;
  final Value<String> status;
  final Value<int?> fit;
  final Value<String> assessment;
  final Value<String> notes;
  final Value<int> rowid;
  const JobListingsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.title = const Value.absent(),
    this.company = const Value.absent(),
    this.location = const Value.absent(),
    this.country = const Value.absent(),
    this.remote = const Value.absent(),
    this.salaryMin = const Value.absent(),
    this.salaryMax = const Value.absent(),
    this.currency = const Value.absent(),
    this.salaryText = const Value.absent(),
    this.url = const Value.absent(),
    this.description = const Value.absent(),
    this.posted = const Value.absent(),
    this.closing = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.found = const Value.absent(),
    this.status = const Value.absent(),
    this.fit = const Value.absent(),
    this.assessment = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JobListingsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String title,
    this.company = const Value.absent(),
    this.location = const Value.absent(),
    this.country = const Value.absent(),
    this.remote = const Value.absent(),
    this.salaryMin = const Value.absent(),
    this.salaryMax = const Value.absent(),
    this.currency = const Value.absent(),
    this.salaryText = const Value.absent(),
    this.url = const Value.absent(),
    this.description = const Value.absent(),
    this.posted = const Value.absent(),
    this.closing = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    required String found,
    this.status = const Value.absent(),
    this.fit = const Value.absent(),
    this.assessment = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       found = Value(found);
  static Insertable<Job> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? title,
    Expression<String>? company,
    Expression<String>? location,
    Expression<String>? country,
    Expression<bool>? remote,
    Expression<int>? salaryMin,
    Expression<int>? salaryMax,
    Expression<String>? currency,
    Expression<String>? salaryText,
    Expression<String>? url,
    Expression<String>? description,
    Expression<String>? posted,
    Expression<String>? closing,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<String>? found,
    Expression<String>? status,
    Expression<int>? fit,
    Expression<String>? assessment,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (title != null) 'title': title,
      if (company != null) 'company': company,
      if (location != null) 'location': location,
      if (country != null) 'country': country,
      if (remote != null) 'remote': remote,
      if (salaryMin != null) 'salary_min': salaryMin,
      if (salaryMax != null) 'salary_max': salaryMax,
      if (currency != null) 'currency': currency,
      if (salaryText != null) 'salary_text': salaryText,
      if (url != null) 'url': url,
      if (description != null) 'description': description,
      if (posted != null) 'posted': posted,
      if (closing != null) 'closing': closing,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (found != null) 'found': found,
      if (status != null) 'status': status,
      if (fit != null) 'fit': fit,
      if (assessment != null) 'assessment': assessment,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JobListingsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? title,
    Value<String>? company,
    Value<String>? location,
    Value<String>? country,
    Value<bool>? remote,
    Value<int?>? salaryMin,
    Value<int?>? salaryMax,
    Value<String>? currency,
    Value<String>? salaryText,
    Value<String>? url,
    Value<String>? description,
    Value<String?>? posted,
    Value<String?>? closing,
    Value<String>? source,
    Value<String>? sourceId,
    Value<String>? found,
    Value<String>? status,
    Value<int?>? fit,
    Value<String>? assessment,
    Value<String>? notes,
    Value<int>? rowid,
  }) {
    return JobListingsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      country: country ?? this.country,
      remote: remote ?? this.remote,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      currency: currency ?? this.currency,
      salaryText: salaryText ?? this.salaryText,
      url: url ?? this.url,
      description: description ?? this.description,
      posted: posted ?? this.posted,
      closing: closing ?? this.closing,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      found: found ?? this.found,
      status: status ?? this.status,
      fit: fit ?? this.fit,
      assessment: assessment ?? this.assessment,
      notes: notes ?? this.notes,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (remote.present) {
      map['remote'] = Variable<bool>(remote.value);
    }
    if (salaryMin.present) {
      map['salary_min'] = Variable<int>(salaryMin.value);
    }
    if (salaryMax.present) {
      map['salary_max'] = Variable<int>(salaryMax.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (salaryText.present) {
      map['salary_text'] = Variable<String>(salaryText.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (posted.present) {
      map['posted'] = Variable<String>(posted.value);
    }
    if (closing.present) {
      map['closing'] = Variable<String>(closing.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (found.present) {
      map['found'] = Variable<String>(found.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (fit.present) {
      map['fit'] = Variable<int>(fit.value);
    }
    if (assessment.present) {
      map['assessment'] = Variable<String>(assessment.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JobListingsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('title: $title, ')
          ..write('company: $company, ')
          ..write('location: $location, ')
          ..write('country: $country, ')
          ..write('remote: $remote, ')
          ..write('salaryMin: $salaryMin, ')
          ..write('salaryMax: $salaryMax, ')
          ..write('currency: $currency, ')
          ..write('salaryText: $salaryText, ')
          ..write('url: $url, ')
          ..write('description: $description, ')
          ..write('posted: $posted, ')
          ..write('closing: $closing, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('found: $found, ')
          ..write('status: $status, ')
          ..write('fit: $fit, ')
          ..write('assessment: $assessment, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JobApplicationsTable extends JobApplications with TableInfo<$JobApplicationsTable, JobApplication> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobApplicationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _companyMeta = const VerificationMeta('company');
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta('location');
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('preparing'),
  );
  static const VerificationMeta _appliedMeta = const VerificationMeta('applied');
  @override
  late final GeneratedColumn<String> applied = GeneratedColumn<String>(
    'applied',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followUpMeta = const VerificationMeta('followUp');
  @override
  late final GeneratedColumn<String> followUp = GeneratedColumn<String>(
    'follow_up',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followUpNoteMeta = const VerificationMeta('followUpNote');
  @override
  late final GeneratedColumn<String> followUpNote = GeneratedColumn<String>(
    'follow_up_note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _resumeIdMeta = const VerificationMeta('resumeId');
  @override
  late final GeneratedColumn<String> resumeId = GeneratedColumn<String>(
    'resume_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceMeta = const VerificationMeta('reference');
  @override
  late final GeneratedColumn<String> reference = GeneratedColumn<String>(
    'reference',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedMeta = const VerificationMeta('updated');
  @override
  late final GeneratedColumn<String> updated = GeneratedColumn<String>(
    'updated',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hlc,
    deleted,
    jobId,
    title,
    company,
    location,
    url,
    stage,
    applied,
    followUp,
    followUpNote,
    resumeId,
    reference,
    notes,
    updated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'job_applications';
  @override
  VerificationContext validateIntegrity(Insertable<JobApplication> instance, {bool isInserting = false}) {
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
    if (data.containsKey('job_id')) {
      context.handle(_jobIdMeta, jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('company')) {
      context.handle(_companyMeta, company.isAcceptableOrUnknown(data['company']!, _companyMeta));
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta, location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('stage')) {
      context.handle(_stageMeta, stage.isAcceptableOrUnknown(data['stage']!, _stageMeta));
    }
    if (data.containsKey('applied')) {
      context.handle(_appliedMeta, applied.isAcceptableOrUnknown(data['applied']!, _appliedMeta));
    }
    if (data.containsKey('follow_up')) {
      context.handle(_followUpMeta, followUp.isAcceptableOrUnknown(data['follow_up']!, _followUpMeta));
    }
    if (data.containsKey('follow_up_note')) {
      context.handle(
        _followUpNoteMeta,
        followUpNote.isAcceptableOrUnknown(data['follow_up_note']!, _followUpNoteMeta),
      );
    }
    if (data.containsKey('resume_id')) {
      context.handle(_resumeIdMeta, resumeId.isAcceptableOrUnknown(data['resume_id']!, _resumeIdMeta));
    }
    if (data.containsKey('reference')) {
      context.handle(_referenceMeta, reference.isAcceptableOrUnknown(data['reference']!, _referenceMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('updated')) {
      context.handle(_updatedMeta, updated.isAcceptableOrUnknown(data['updated']!, _updatedMeta));
    } else if (isInserting) {
      context.missing(_updatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JobApplication map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JobApplication(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      jobId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}job_id']),
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      company: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}company'])!,
      location: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}location'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      stage: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}stage'])!,
      applied: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}applied']),
      followUp: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}follow_up']),
      followUpNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}follow_up_note'],
      )!,
      resumeId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}resume_id']),
      reference: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}reference'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      updated: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}updated'])!,
    );
  }

  @override
  $JobApplicationsTable createAlias(String alias) {
    return $JobApplicationsTable(attachedDatabase, alias);
  }
}

class JobApplication extends DataClass implements Insertable<JobApplication> {
  final String id;
  final String hlc;
  final bool deleted;
  final String? jobId;
  final String title;
  final String company;
  final String location;
  final String url;

  /// See domain/pipeline.dart.
  final String stage;
  final String? applied;

  /// When to chase it up, and what to ask.
  final String? followUp;
  final String followUpNote;

  /// The CV sent (career_resumes id).
  final String? resumeId;
  final String reference;
  final String notes;

  /// Last change of stage, for "no reply in N days".
  final String updated;
  const JobApplication({
    required this.id,
    required this.hlc,
    required this.deleted,
    this.jobId,
    required this.title,
    required this.company,
    required this.location,
    required this.url,
    required this.stage,
    this.applied,
    this.followUp,
    required this.followUpNote,
    this.resumeId,
    required this.reference,
    required this.notes,
    required this.updated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || jobId != null) {
      map['job_id'] = Variable<String>(jobId);
    }
    map['title'] = Variable<String>(title);
    map['company'] = Variable<String>(company);
    map['location'] = Variable<String>(location);
    map['url'] = Variable<String>(url);
    map['stage'] = Variable<String>(stage);
    if (!nullToAbsent || applied != null) {
      map['applied'] = Variable<String>(applied);
    }
    if (!nullToAbsent || followUp != null) {
      map['follow_up'] = Variable<String>(followUp);
    }
    map['follow_up_note'] = Variable<String>(followUpNote);
    if (!nullToAbsent || resumeId != null) {
      map['resume_id'] = Variable<String>(resumeId);
    }
    map['reference'] = Variable<String>(reference);
    map['notes'] = Variable<String>(notes);
    map['updated'] = Variable<String>(updated);
    return map;
  }

  JobApplicationsCompanion toCompanion(bool nullToAbsent) {
    return JobApplicationsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      jobId: jobId == null && nullToAbsent ? const Value.absent() : Value(jobId),
      title: Value(title),
      company: Value(company),
      location: Value(location),
      url: Value(url),
      stage: Value(stage),
      applied: applied == null && nullToAbsent ? const Value.absent() : Value(applied),
      followUp: followUp == null && nullToAbsent ? const Value.absent() : Value(followUp),
      followUpNote: Value(followUpNote),
      resumeId: resumeId == null && nullToAbsent ? const Value.absent() : Value(resumeId),
      reference: Value(reference),
      notes: Value(notes),
      updated: Value(updated),
    );
  }

  factory JobApplication.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JobApplication(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      jobId: serializer.fromJson<String?>(json['jobId']),
      title: serializer.fromJson<String>(json['title']),
      company: serializer.fromJson<String>(json['company']),
      location: serializer.fromJson<String>(json['location']),
      url: serializer.fromJson<String>(json['url']),
      stage: serializer.fromJson<String>(json['stage']),
      applied: serializer.fromJson<String?>(json['applied']),
      followUp: serializer.fromJson<String?>(json['followUp']),
      followUpNote: serializer.fromJson<String>(json['followUpNote']),
      resumeId: serializer.fromJson<String?>(json['resumeId']),
      reference: serializer.fromJson<String>(json['reference']),
      notes: serializer.fromJson<String>(json['notes']),
      updated: serializer.fromJson<String>(json['updated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'jobId': serializer.toJson<String?>(jobId),
      'title': serializer.toJson<String>(title),
      'company': serializer.toJson<String>(company),
      'location': serializer.toJson<String>(location),
      'url': serializer.toJson<String>(url),
      'stage': serializer.toJson<String>(stage),
      'applied': serializer.toJson<String?>(applied),
      'followUp': serializer.toJson<String?>(followUp),
      'followUpNote': serializer.toJson<String>(followUpNote),
      'resumeId': serializer.toJson<String?>(resumeId),
      'reference': serializer.toJson<String>(reference),
      'notes': serializer.toJson<String>(notes),
      'updated': serializer.toJson<String>(updated),
    };
  }

  JobApplication copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    Value<String?> jobId = const Value.absent(),
    String? title,
    String? company,
    String? location,
    String? url,
    String? stage,
    Value<String?> applied = const Value.absent(),
    Value<String?> followUp = const Value.absent(),
    String? followUpNote,
    Value<String?> resumeId = const Value.absent(),
    String? reference,
    String? notes,
    String? updated,
  }) => JobApplication(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    jobId: jobId.present ? jobId.value : this.jobId,
    title: title ?? this.title,
    company: company ?? this.company,
    location: location ?? this.location,
    url: url ?? this.url,
    stage: stage ?? this.stage,
    applied: applied.present ? applied.value : this.applied,
    followUp: followUp.present ? followUp.value : this.followUp,
    followUpNote: followUpNote ?? this.followUpNote,
    resumeId: resumeId.present ? resumeId.value : this.resumeId,
    reference: reference ?? this.reference,
    notes: notes ?? this.notes,
    updated: updated ?? this.updated,
  );
  JobApplication copyWithCompanion(JobApplicationsCompanion data) {
    return JobApplication(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      title: data.title.present ? data.title.value : this.title,
      company: data.company.present ? data.company.value : this.company,
      location: data.location.present ? data.location.value : this.location,
      url: data.url.present ? data.url.value : this.url,
      stage: data.stage.present ? data.stage.value : this.stage,
      applied: data.applied.present ? data.applied.value : this.applied,
      followUp: data.followUp.present ? data.followUp.value : this.followUp,
      followUpNote: data.followUpNote.present ? data.followUpNote.value : this.followUpNote,
      resumeId: data.resumeId.present ? data.resumeId.value : this.resumeId,
      reference: data.reference.present ? data.reference.value : this.reference,
      notes: data.notes.present ? data.notes.value : this.notes,
      updated: data.updated.present ? data.updated.value : this.updated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JobApplication(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('jobId: $jobId, ')
          ..write('title: $title, ')
          ..write('company: $company, ')
          ..write('location: $location, ')
          ..write('url: $url, ')
          ..write('stage: $stage, ')
          ..write('applied: $applied, ')
          ..write('followUp: $followUp, ')
          ..write('followUpNote: $followUpNote, ')
          ..write('resumeId: $resumeId, ')
          ..write('reference: $reference, ')
          ..write('notes: $notes, ')
          ..write('updated: $updated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hlc,
    deleted,
    jobId,
    title,
    company,
    location,
    url,
    stage,
    applied,
    followUp,
    followUpNote,
    resumeId,
    reference,
    notes,
    updated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JobApplication &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.jobId == this.jobId &&
          other.title == this.title &&
          other.company == this.company &&
          other.location == this.location &&
          other.url == this.url &&
          other.stage == this.stage &&
          other.applied == this.applied &&
          other.followUp == this.followUp &&
          other.followUpNote == this.followUpNote &&
          other.resumeId == this.resumeId &&
          other.reference == this.reference &&
          other.notes == this.notes &&
          other.updated == this.updated);
}

class JobApplicationsCompanion extends UpdateCompanion<JobApplication> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String?> jobId;
  final Value<String> title;
  final Value<String> company;
  final Value<String> location;
  final Value<String> url;
  final Value<String> stage;
  final Value<String?> applied;
  final Value<String?> followUp;
  final Value<String> followUpNote;
  final Value<String?> resumeId;
  final Value<String> reference;
  final Value<String> notes;
  final Value<String> updated;
  final Value<int> rowid;
  const JobApplicationsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.jobId = const Value.absent(),
    this.title = const Value.absent(),
    this.company = const Value.absent(),
    this.location = const Value.absent(),
    this.url = const Value.absent(),
    this.stage = const Value.absent(),
    this.applied = const Value.absent(),
    this.followUp = const Value.absent(),
    this.followUpNote = const Value.absent(),
    this.resumeId = const Value.absent(),
    this.reference = const Value.absent(),
    this.notes = const Value.absent(),
    this.updated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JobApplicationsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.jobId = const Value.absent(),
    required String title,
    this.company = const Value.absent(),
    this.location = const Value.absent(),
    this.url = const Value.absent(),
    this.stage = const Value.absent(),
    this.applied = const Value.absent(),
    this.followUp = const Value.absent(),
    this.followUpNote = const Value.absent(),
    this.resumeId = const Value.absent(),
    this.reference = const Value.absent(),
    this.notes = const Value.absent(),
    required String updated,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       updated = Value(updated);
  static Insertable<JobApplication> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? jobId,
    Expression<String>? title,
    Expression<String>? company,
    Expression<String>? location,
    Expression<String>? url,
    Expression<String>? stage,
    Expression<String>? applied,
    Expression<String>? followUp,
    Expression<String>? followUpNote,
    Expression<String>? resumeId,
    Expression<String>? reference,
    Expression<String>? notes,
    Expression<String>? updated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (jobId != null) 'job_id': jobId,
      if (title != null) 'title': title,
      if (company != null) 'company': company,
      if (location != null) 'location': location,
      if (url != null) 'url': url,
      if (stage != null) 'stage': stage,
      if (applied != null) 'applied': applied,
      if (followUp != null) 'follow_up': followUp,
      if (followUpNote != null) 'follow_up_note': followUpNote,
      if (resumeId != null) 'resume_id': resumeId,
      if (reference != null) 'reference': reference,
      if (notes != null) 'notes': notes,
      if (updated != null) 'updated': updated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JobApplicationsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String?>? jobId,
    Value<String>? title,
    Value<String>? company,
    Value<String>? location,
    Value<String>? url,
    Value<String>? stage,
    Value<String?>? applied,
    Value<String?>? followUp,
    Value<String>? followUpNote,
    Value<String?>? resumeId,
    Value<String>? reference,
    Value<String>? notes,
    Value<String>? updated,
    Value<int>? rowid,
  }) {
    return JobApplicationsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      jobId: jobId ?? this.jobId,
      title: title ?? this.title,
      company: company ?? this.company,
      location: location ?? this.location,
      url: url ?? this.url,
      stage: stage ?? this.stage,
      applied: applied ?? this.applied,
      followUp: followUp ?? this.followUp,
      followUpNote: followUpNote ?? this.followUpNote,
      resumeId: resumeId ?? this.resumeId,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      updated: updated ?? this.updated,
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
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (applied.present) {
      map['applied'] = Variable<String>(applied.value);
    }
    if (followUp.present) {
      map['follow_up'] = Variable<String>(followUp.value);
    }
    if (followUpNote.present) {
      map['follow_up_note'] = Variable<String>(followUpNote.value);
    }
    if (resumeId.present) {
      map['resume_id'] = Variable<String>(resumeId.value);
    }
    if (reference.present) {
      map['reference'] = Variable<String>(reference.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updated.present) {
      map['updated'] = Variable<String>(updated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JobApplicationsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('jobId: $jobId, ')
          ..write('title: $title, ')
          ..write('company: $company, ')
          ..write('location: $location, ')
          ..write('url: $url, ')
          ..write('stage: $stage, ')
          ..write('applied: $applied, ')
          ..write('followUp: $followUp, ')
          ..write('followUpNote: $followUpNote, ')
          ..write('resumeId: $resumeId, ')
          ..write('reference: $reference, ')
          ..write('notes: $notes, ')
          ..write('updated: $updated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JobEventsTable extends JobEvents with TableInfo<$JobEventsTable, JobEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JobEventsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _applicationIdMeta = const VerificationMeta('applicationId');
  @override
  late final GeneratedColumn<String> applicationId = GeneratedColumn<String>(
    'application_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta('summary');
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, applicationId, at, kind, summary];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'job_events';
  @override
  VerificationContext validateIntegrity(Insertable<JobEvent> instance, {bool isInserting = false}) {
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
    if (data.containsKey('application_id')) {
      context.handle(
        _applicationIdMeta,
        applicationId.isAcceptableOrUnknown(data['application_id']!, _applicationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_applicationIdMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(_summaryMeta, summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JobEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JobEvent(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      applicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}application_id'],
      )!,
      at: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}at'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      summary: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}summary'])!,
    );
  }

  @override
  $JobEventsTable createAlias(String alias) {
    return $JobEventsTable(attachedDatabase, alias);
  }
}

class JobEvent extends DataClass implements Insertable<JobEvent> {
  final String id;
  final String hlc;
  final bool deleted;
  final String applicationId;
  final String at;

  /// applied | followup | reply | interview | offer | rejected | withdrawn | note
  final String kind;
  final String summary;
  const JobEvent({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.applicationId,
    required this.at,
    required this.kind,
    required this.summary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['application_id'] = Variable<String>(applicationId);
    map['at'] = Variable<String>(at);
    map['kind'] = Variable<String>(kind);
    map['summary'] = Variable<String>(summary);
    return map;
  }

  JobEventsCompanion toCompanion(bool nullToAbsent) {
    return JobEventsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      applicationId: Value(applicationId),
      at: Value(at),
      kind: Value(kind),
      summary: Value(summary),
    );
  }

  factory JobEvent.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JobEvent(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      applicationId: serializer.fromJson<String>(json['applicationId']),
      at: serializer.fromJson<String>(json['at']),
      kind: serializer.fromJson<String>(json['kind']),
      summary: serializer.fromJson<String>(json['summary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'applicationId': serializer.toJson<String>(applicationId),
      'at': serializer.toJson<String>(at),
      'kind': serializer.toJson<String>(kind),
      'summary': serializer.toJson<String>(summary),
    };
  }

  JobEvent copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? applicationId,
    String? at,
    String? kind,
    String? summary,
  }) => JobEvent(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    applicationId: applicationId ?? this.applicationId,
    at: at ?? this.at,
    kind: kind ?? this.kind,
    summary: summary ?? this.summary,
  );
  JobEvent copyWithCompanion(JobEventsCompanion data) {
    return JobEvent(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      applicationId: data.applicationId.present ? data.applicationId.value : this.applicationId,
      at: data.at.present ? data.at.value : this.at,
      kind: data.kind.present ? data.kind.value : this.kind,
      summary: data.summary.present ? data.summary.value : this.summary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JobEvent(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('applicationId: $applicationId, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('summary: $summary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, applicationId, at, kind, summary);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JobEvent &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.applicationId == this.applicationId &&
          other.at == this.at &&
          other.kind == this.kind &&
          other.summary == this.summary);
}

class JobEventsCompanion extends UpdateCompanion<JobEvent> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> applicationId;
  final Value<String> at;
  final Value<String> kind;
  final Value<String> summary;
  final Value<int> rowid;
  const JobEventsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.applicationId = const Value.absent(),
    this.at = const Value.absent(),
    this.kind = const Value.absent(),
    this.summary = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JobEventsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String applicationId,
    required String at,
    required String kind,
    this.summary = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       applicationId = Value(applicationId),
       at = Value(at),
       kind = Value(kind);
  static Insertable<JobEvent> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? applicationId,
    Expression<String>? at,
    Expression<String>? kind,
    Expression<String>? summary,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (applicationId != null) 'application_id': applicationId,
      if (at != null) 'at': at,
      if (kind != null) 'kind': kind,
      if (summary != null) 'summary': summary,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JobEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? applicationId,
    Value<String>? at,
    Value<String>? kind,
    Value<String>? summary,
    Value<int>? rowid,
  }) {
    return JobEventsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      applicationId: applicationId ?? this.applicationId,
      at: at ?? this.at,
      kind: kind ?? this.kind,
      summary: summary ?? this.summary,
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
    if (applicationId.present) {
      map['application_id'] = Variable<String>(applicationId.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JobEventsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('applicationId: $applicationId, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('summary: $summary, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareerContactsTable extends CareerContacts with TableInfo<$CareerContactsTable, Lead> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareerContactsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('recruiter'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _companyMeta = const VerificationMeta('company');
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _linkedinMeta = const VerificationMeta('linkedin');
  @override
  late final GeneratedColumn<String> linkedin = GeneratedColumn<String>(
    'linkedin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _lastContactMeta = const VerificationMeta('lastContact');
  @override
  late final GeneratedColumn<String> lastContact = GeneratedColumn<String>(
    'last_contact',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _followUpMeta = const VerificationMeta('followUp');
  @override
  late final GeneratedColumn<String> followUp = GeneratedColumn<String>(
    'follow_up',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hlc,
    deleted,
    name,
    kind,
    title,
    company,
    email,
    phone,
    linkedin,
    source,
    status,
    lastContact,
    followUp,
    jobId,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'career_contacts';
  @override
  VerificationContext validateIntegrity(Insertable<Lead> instance, {bool isInserting = false}) {
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
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('company')) {
      context.handle(_companyMeta, company.isAcceptableOrUnknown(data['company']!, _companyMeta));
    }
    if (data.containsKey('email')) {
      context.handle(_emailMeta, email.isAcceptableOrUnknown(data['email']!, _emailMeta));
    }
    if (data.containsKey('phone')) {
      context.handle(_phoneMeta, phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta));
    }
    if (data.containsKey('linkedin')) {
      context.handle(_linkedinMeta, linkedin.isAcceptableOrUnknown(data['linkedin']!, _linkedinMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('last_contact')) {
      context.handle(
        _lastContactMeta,
        lastContact.isAcceptableOrUnknown(data['last_contact']!, _lastContactMeta),
      );
    }
    if (data.containsKey('follow_up')) {
      context.handle(_followUpMeta, followUp.isAcceptableOrUnknown(data['follow_up']!, _followUpMeta));
    }
    if (data.containsKey('job_id')) {
      context.handle(_jobIdMeta, jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Lead map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Lead(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      company: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}company'])!,
      email: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}email'])!,
      phone: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}phone'])!,
      linkedin: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}linkedin'])!,
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      lastContact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_contact'],
      ),
      followUp: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}follow_up']),
      jobId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}job_id']),
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
    );
  }

  @override
  $CareerContactsTable createAlias(String alias) {
    return $CareerContactsTable(attachedDatabase, alias);
  }
}

class Lead extends DataClass implements Insertable<Lead> {
  final String id;
  final String hlc;
  final bool deleted;
  final String name;

  /// recruiter | hiring_manager | referral | peer | mentor | other
  final String kind;
  final String title;
  final String company;
  final String email;
  final String phone;
  final String linkedin;

  /// Where the lead was found (a team page, a job advert...).
  final String source;

  /// new | contacted | replied | cold
  final String status;
  final String? lastContact;
  final String? followUp;
  final String? jobId;
  final String notes;
  const Lead({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.name,
    required this.kind,
    required this.title,
    required this.company,
    required this.email,
    required this.phone,
    required this.linkedin,
    required this.source,
    required this.status,
    this.lastContact,
    this.followUp,
    this.jobId,
    required this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['company'] = Variable<String>(company);
    map['email'] = Variable<String>(email);
    map['phone'] = Variable<String>(phone);
    map['linkedin'] = Variable<String>(linkedin);
    map['source'] = Variable<String>(source);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastContact != null) {
      map['last_contact'] = Variable<String>(lastContact);
    }
    if (!nullToAbsent || followUp != null) {
      map['follow_up'] = Variable<String>(followUp);
    }
    if (!nullToAbsent || jobId != null) {
      map['job_id'] = Variable<String>(jobId);
    }
    map['notes'] = Variable<String>(notes);
    return map;
  }

  CareerContactsCompanion toCompanion(bool nullToAbsent) {
    return CareerContactsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      name: Value(name),
      kind: Value(kind),
      title: Value(title),
      company: Value(company),
      email: Value(email),
      phone: Value(phone),
      linkedin: Value(linkedin),
      source: Value(source),
      status: Value(status),
      lastContact: lastContact == null && nullToAbsent ? const Value.absent() : Value(lastContact),
      followUp: followUp == null && nullToAbsent ? const Value.absent() : Value(followUp),
      jobId: jobId == null && nullToAbsent ? const Value.absent() : Value(jobId),
      notes: Value(notes),
    );
  }

  factory Lead.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Lead(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      company: serializer.fromJson<String>(json['company']),
      email: serializer.fromJson<String>(json['email']),
      phone: serializer.fromJson<String>(json['phone']),
      linkedin: serializer.fromJson<String>(json['linkedin']),
      source: serializer.fromJson<String>(json['source']),
      status: serializer.fromJson<String>(json['status']),
      lastContact: serializer.fromJson<String?>(json['lastContact']),
      followUp: serializer.fromJson<String?>(json['followUp']),
      jobId: serializer.fromJson<String?>(json['jobId']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'company': serializer.toJson<String>(company),
      'email': serializer.toJson<String>(email),
      'phone': serializer.toJson<String>(phone),
      'linkedin': serializer.toJson<String>(linkedin),
      'source': serializer.toJson<String>(source),
      'status': serializer.toJson<String>(status),
      'lastContact': serializer.toJson<String?>(lastContact),
      'followUp': serializer.toJson<String?>(followUp),
      'jobId': serializer.toJson<String?>(jobId),
      'notes': serializer.toJson<String>(notes),
    };
  }

  Lead copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? name,
    String? kind,
    String? title,
    String? company,
    String? email,
    String? phone,
    String? linkedin,
    String? source,
    String? status,
    Value<String?> lastContact = const Value.absent(),
    Value<String?> followUp = const Value.absent(),
    Value<String?> jobId = const Value.absent(),
    String? notes,
  }) => Lead(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    company: company ?? this.company,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    linkedin: linkedin ?? this.linkedin,
    source: source ?? this.source,
    status: status ?? this.status,
    lastContact: lastContact.present ? lastContact.value : this.lastContact,
    followUp: followUp.present ? followUp.value : this.followUp,
    jobId: jobId.present ? jobId.value : this.jobId,
    notes: notes ?? this.notes,
  );
  Lead copyWithCompanion(CareerContactsCompanion data) {
    return Lead(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      company: data.company.present ? data.company.value : this.company,
      email: data.email.present ? data.email.value : this.email,
      phone: data.phone.present ? data.phone.value : this.phone,
      linkedin: data.linkedin.present ? data.linkedin.value : this.linkedin,
      source: data.source.present ? data.source.value : this.source,
      status: data.status.present ? data.status.value : this.status,
      lastContact: data.lastContact.present ? data.lastContact.value : this.lastContact,
      followUp: data.followUp.present ? data.followUp.value : this.followUp,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Lead(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('company: $company, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('linkedin: $linkedin, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('lastContact: $lastContact, ')
          ..write('followUp: $followUp, ')
          ..write('jobId: $jobId, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hlc,
    deleted,
    name,
    kind,
    title,
    company,
    email,
    phone,
    linkedin,
    source,
    status,
    lastContact,
    followUp,
    jobId,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lead &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.company == this.company &&
          other.email == this.email &&
          other.phone == this.phone &&
          other.linkedin == this.linkedin &&
          other.source == this.source &&
          other.status == this.status &&
          other.lastContact == this.lastContact &&
          other.followUp == this.followUp &&
          other.jobId == this.jobId &&
          other.notes == this.notes);
}

class CareerContactsCompanion extends UpdateCompanion<Lead> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> company;
  final Value<String> email;
  final Value<String> phone;
  final Value<String> linkedin;
  final Value<String> source;
  final Value<String> status;
  final Value<String?> lastContact;
  final Value<String?> followUp;
  final Value<String?> jobId;
  final Value<String> notes;
  final Value<int> rowid;
  const CareerContactsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.company = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.linkedin = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.lastContact = const Value.absent(),
    this.followUp = const Value.absent(),
    this.jobId = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareerContactsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String name,
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.company = const Value.absent(),
    this.email = const Value.absent(),
    this.phone = const Value.absent(),
    this.linkedin = const Value.absent(),
    this.source = const Value.absent(),
    this.status = const Value.absent(),
    this.lastContact = const Value.absent(),
    this.followUp = const Value.absent(),
    this.jobId = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Lead> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? company,
    Expression<String>? email,
    Expression<String>? phone,
    Expression<String>? linkedin,
    Expression<String>? source,
    Expression<String>? status,
    Expression<String>? lastContact,
    Expression<String>? followUp,
    Expression<String>? jobId,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (company != null) 'company': company,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (linkedin != null) 'linkedin': linkedin,
      if (source != null) 'source': source,
      if (status != null) 'status': status,
      if (lastContact != null) 'last_contact': lastContact,
      if (followUp != null) 'follow_up': followUp,
      if (jobId != null) 'job_id': jobId,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareerContactsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? name,
    Value<String>? kind,
    Value<String>? title,
    Value<String>? company,
    Value<String>? email,
    Value<String>? phone,
    Value<String>? linkedin,
    Value<String>? source,
    Value<String>? status,
    Value<String?>? lastContact,
    Value<String?>? followUp,
    Value<String?>? jobId,
    Value<String>? notes,
    Value<int>? rowid,
  }) {
    return CareerContactsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      company: company ?? this.company,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      linkedin: linkedin ?? this.linkedin,
      source: source ?? this.source,
      status: status ?? this.status,
      lastContact: lastContact ?? this.lastContact,
      followUp: followUp ?? this.followUp,
      jobId: jobId ?? this.jobId,
      notes: notes ?? this.notes,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (linkedin.present) {
      map['linkedin'] = Variable<String>(linkedin.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastContact.present) {
      map['last_contact'] = Variable<String>(lastContact.value);
    }
    if (followUp.present) {
      map['follow_up'] = Variable<String>(followUp.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareerContactsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('company: $company, ')
          ..write('email: $email, ')
          ..write('phone: $phone, ')
          ..write('linkedin: $linkedin, ')
          ..write('source: $source, ')
          ..write('status: $status, ')
          ..write('lastContact: $lastContact, ')
          ..write('followUp: $followUp, ')
          ..write('jobId: $jobId, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareerResumesTable extends CareerResumes with TableInfo<$CareerResumesTable, Resume> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareerResumesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta('created');
  @override
  late final GeneratedColumn<String> created = GeneratedColumn<String>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tailoringMeta = const VerificationMeta('tailoring');
  @override
  late final GeneratedColumn<String> tailoring = GeneratedColumn<String>(
    'tailoring',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, name, jobId, created, content, tailoring];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'career_resumes';
  @override
  VerificationContext validateIntegrity(Insertable<Resume> instance, {bool isInserting = false}) {
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
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('job_id')) {
      context.handle(_jobIdMeta, jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta));
    }
    if (data.containsKey('created')) {
      context.handle(_createdMeta, created.isAcceptableOrUnknown(data['created']!, _createdMeta));
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta, content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('tailoring')) {
      context.handle(_tailoringMeta, tailoring.isAcceptableOrUnknown(data['tailoring']!, _tailoringMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Resume map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Resume(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      jobId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}job_id']),
      created: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}created'])!,
      content: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      tailoring: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tailoring'])!,
    );
  }

  @override
  $CareerResumesTable createAlias(String alias) {
    return $CareerResumesTable(attachedDatabase, alias);
  }
}

class Resume extends DataClass implements Insertable<Resume> {
  final String id;
  final String hlc;
  final bool deleted;
  final String name;
  final String? jobId;
  final String created;

  /// ResumeDoc as JSON.
  final String content;

  /// What was changed for the job, keyword cover and cautions (TailorNotes).
  final String tailoring;
  const Resume({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.name,
    this.jobId,
    required this.created,
    required this.content,
    required this.tailoring,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || jobId != null) {
      map['job_id'] = Variable<String>(jobId);
    }
    map['created'] = Variable<String>(created);
    map['content'] = Variable<String>(content);
    map['tailoring'] = Variable<String>(tailoring);
    return map;
  }

  CareerResumesCompanion toCompanion(bool nullToAbsent) {
    return CareerResumesCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      name: Value(name),
      jobId: jobId == null && nullToAbsent ? const Value.absent() : Value(jobId),
      created: Value(created),
      content: Value(content),
      tailoring: Value(tailoring),
    );
  }

  factory Resume.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Resume(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      name: serializer.fromJson<String>(json['name']),
      jobId: serializer.fromJson<String?>(json['jobId']),
      created: serializer.fromJson<String>(json['created']),
      content: serializer.fromJson<String>(json['content']),
      tailoring: serializer.fromJson<String>(json['tailoring']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'name': serializer.toJson<String>(name),
      'jobId': serializer.toJson<String?>(jobId),
      'created': serializer.toJson<String>(created),
      'content': serializer.toJson<String>(content),
      'tailoring': serializer.toJson<String>(tailoring),
    };
  }

  Resume copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? name,
    Value<String?> jobId = const Value.absent(),
    String? created,
    String? content,
    String? tailoring,
  }) => Resume(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    jobId: jobId.present ? jobId.value : this.jobId,
    created: created ?? this.created,
    content: content ?? this.content,
    tailoring: tailoring ?? this.tailoring,
  );
  Resume copyWithCompanion(CareerResumesCompanion data) {
    return Resume(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      name: data.name.present ? data.name.value : this.name,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      created: data.created.present ? data.created.value : this.created,
      content: data.content.present ? data.content.value : this.content,
      tailoring: data.tailoring.present ? data.tailoring.value : this.tailoring,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Resume(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('jobId: $jobId, ')
          ..write('created: $created, ')
          ..write('content: $content, ')
          ..write('tailoring: $tailoring')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, name, jobId, created, content, tailoring);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Resume &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.name == this.name &&
          other.jobId == this.jobId &&
          other.created == this.created &&
          other.content == this.content &&
          other.tailoring == this.tailoring);
}

class CareerResumesCompanion extends UpdateCompanion<Resume> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> name;
  final Value<String?> jobId;
  final Value<String> created;
  final Value<String> content;
  final Value<String> tailoring;
  final Value<int> rowid;
  const CareerResumesCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.name = const Value.absent(),
    this.jobId = const Value.absent(),
    this.created = const Value.absent(),
    this.content = const Value.absent(),
    this.tailoring = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareerResumesCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String name,
    this.jobId = const Value.absent(),
    required String created,
    required String content,
    this.tailoring = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       created = Value(created),
       content = Value(content);
  static Insertable<Resume> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? name,
    Expression<String>? jobId,
    Expression<String>? created,
    Expression<String>? content,
    Expression<String>? tailoring,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (name != null) 'name': name,
      if (jobId != null) 'job_id': jobId,
      if (created != null) 'created': created,
      if (content != null) 'content': content,
      if (tailoring != null) 'tailoring': tailoring,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareerResumesCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? name,
    Value<String?>? jobId,
    Value<String>? created,
    Value<String>? content,
    Value<String>? tailoring,
    Value<int>? rowid,
  }) {
    return CareerResumesCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      name: name ?? this.name,
      jobId: jobId ?? this.jobId,
      created: created ?? this.created,
      content: content ?? this.content,
      tailoring: tailoring ?? this.tailoring,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (created.present) {
      map['created'] = Variable<String>(created.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (tailoring.present) {
      map['tailoring'] = Variable<String>(tailoring.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareerResumesCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('jobId: $jobId, ')
          ..write('created: $created, ')
          ..write('content: $content, ')
          ..write('tailoring: $tailoring, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareerReportsTable extends CareerReports with TableInfo<$CareerReportsTable, Report> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareerReportsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdMeta = const VerificationMeta('created');
  @override
  late final GeneratedColumn<String> created = GeneratedColumn<String>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcesMeta = const VerificationMeta('sources');
  @override
  late final GeneratedColumn<String> sources = GeneratedColumn<String>(
    'sources',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, kind, created, content, sources];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'career_reports';
  @override
  VerificationContext validateIntegrity(Insertable<Report> instance, {bool isInserting = false}) {
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
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('created')) {
      context.handle(_createdMeta, created.isAcceptableOrUnknown(data['created']!, _createdMeta));
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta, content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('sources')) {
      context.handle(_sourcesMeta, sources.isAcceptableOrUnknown(data['sources']!, _sourcesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Report map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Report(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      created: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}created'])!,
      content: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      sources: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}sources'])!,
    );
  }

  @override
  $CareerReportsTable createAlias(String alias) {
    return $CareerReportsTable(attachedDatabase, alias);
  }
}

class Report extends DataClass implements Insertable<Report> {
  final String id;
  final String hlc;
  final bool deleted;

  /// assessment | career_map
  final String kind;
  final String created;
  final String content;

  /// Web pages the AI read for it, as JSON [{title, url}].
  final String sources;
  const Report({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.kind,
    required this.created,
    required this.content,
    required this.sources,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['kind'] = Variable<String>(kind);
    map['created'] = Variable<String>(created);
    map['content'] = Variable<String>(content);
    map['sources'] = Variable<String>(sources);
    return map;
  }

  CareerReportsCompanion toCompanion(bool nullToAbsent) {
    return CareerReportsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      kind: Value(kind),
      created: Value(created),
      content: Value(content),
      sources: Value(sources),
    );
  }

  factory Report.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Report(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      kind: serializer.fromJson<String>(json['kind']),
      created: serializer.fromJson<String>(json['created']),
      content: serializer.fromJson<String>(json['content']),
      sources: serializer.fromJson<String>(json['sources']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'kind': serializer.toJson<String>(kind),
      'created': serializer.toJson<String>(created),
      'content': serializer.toJson<String>(content),
      'sources': serializer.toJson<String>(sources),
    };
  }

  Report copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? kind,
    String? created,
    String? content,
    String? sources,
  }) => Report(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    kind: kind ?? this.kind,
    created: created ?? this.created,
    content: content ?? this.content,
    sources: sources ?? this.sources,
  );
  Report copyWithCompanion(CareerReportsCompanion data) {
    return Report(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      kind: data.kind.present ? data.kind.value : this.kind,
      created: data.created.present ? data.created.value : this.created,
      content: data.content.present ? data.content.value : this.content,
      sources: data.sources.present ? data.sources.value : this.sources,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Report(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('kind: $kind, ')
          ..write('created: $created, ')
          ..write('content: $content, ')
          ..write('sources: $sources')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, kind, created, content, sources);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Report &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.kind == this.kind &&
          other.created == this.created &&
          other.content == this.content &&
          other.sources == this.sources);
}

class CareerReportsCompanion extends UpdateCompanion<Report> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> kind;
  final Value<String> created;
  final Value<String> content;
  final Value<String> sources;
  final Value<int> rowid;
  const CareerReportsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.kind = const Value.absent(),
    this.created = const Value.absent(),
    this.content = const Value.absent(),
    this.sources = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareerReportsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String kind,
    required String created,
    required String content,
    this.sources = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       created = Value(created),
       content = Value(content);
  static Insertable<Report> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? kind,
    Expression<String>? created,
    Expression<String>? content,
    Expression<String>? sources,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (kind != null) 'kind': kind,
      if (created != null) 'created': created,
      if (content != null) 'content': content,
      if (sources != null) 'sources': sources,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareerReportsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? kind,
    Value<String>? created,
    Value<String>? content,
    Value<String>? sources,
    Value<int>? rowid,
  }) {
    return CareerReportsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      kind: kind ?? this.kind,
      created: created ?? this.created,
      content: content ?? this.content,
      sources: sources ?? this.sources,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (created.present) {
      map['created'] = Variable<String>(created.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sources.present) {
      map['sources'] = Variable<String>(sources.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareerReportsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('kind: $kind, ')
          ..write('created: $created, ')
          ..write('content: $content, ')
          ..write('sources: $sources, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareerGrowthTable extends CareerGrowth with TableInfo<$CareerGrowthTable, GrowthItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareerGrowthTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta('provider');
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _whyMeta = const VerificationMeta('why');
  @override
  late final GeneratedColumn<String> why = GeneratedColumn<String>(
    'why',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<String> cost = GeneratedColumn<String>(
    'cost',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _durationMeta = const VerificationMeta('duration');
  @override
  late final GeneratedColumn<String> duration = GeneratedColumn<String>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('suggested'),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta('progress');
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<String> done = GeneratedColumn<String>(
    'done',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<String> added = GeneratedColumn<String>(
    'added',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hlc,
    deleted,
    title,
    kind,
    provider,
    url,
    why,
    cost,
    duration,
    status,
    progress,
    target,
    done,
    path,
    added,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'career_growth';
  @override
  VerificationContext validateIntegrity(Insertable<GrowthItem> instance, {bool isInserting = false}) {
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
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta, provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('why')) {
      context.handle(_whyMeta, why.isAcceptableOrUnknown(data['why']!, _whyMeta));
    }
    if (data.containsKey('cost')) {
      context.handle(_costMeta, cost.isAcceptableOrUnknown(data['cost']!, _costMeta));
    }
    if (data.containsKey('duration')) {
      context.handle(_durationMeta, duration.isAcceptableOrUnknown(data['duration']!, _durationMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta, progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta, target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    }
    if (data.containsKey('done')) {
      context.handle(_doneMeta, done.isAcceptableOrUnknown(data['done']!, _doneMeta));
    }
    if (data.containsKey('path')) {
      context.handle(_pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    }
    if (data.containsKey('added')) {
      context.handle(_addedMeta, added.isAcceptableOrUnknown(data['added']!, _addedMeta));
    } else if (isInserting) {
      context.missing(_addedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GrowthItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GrowthItem(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      provider: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      why: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}why'])!,
      cost: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}cost'])!,
      duration: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}duration'])!,
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      progress: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}progress'])!,
      target: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}target']),
      done: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}done']),
      path: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      added: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}added'])!,
    );
  }

  @override
  $CareerGrowthTable createAlias(String alias) {
    return $CareerGrowthTable(attachedDatabase, alias);
  }
}

class GrowthItem extends DataClass implements Insertable<GrowthItem> {
  final String id;
  final String hlc;
  final bool deleted;
  final String title;

  /// certification | course | degree | skill | experience | goal
  final String kind;
  final String provider;
  final String url;
  final String why;
  final String cost;
  final String duration;

  /// suggested | planned | doing | done | dropped
  final String status;

  /// 0 to 100.
  final int progress;
  final String? target;
  final String? done;

  /// The career path it serves, by name, when it came from the map.
  final String path;
  final String added;
  const GrowthItem({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.title,
    required this.kind,
    required this.provider,
    required this.url,
    required this.why,
    required this.cost,
    required this.duration,
    required this.status,
    required this.progress,
    this.target,
    this.done,
    required this.path,
    required this.added,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<String>(kind);
    map['provider'] = Variable<String>(provider);
    map['url'] = Variable<String>(url);
    map['why'] = Variable<String>(why);
    map['cost'] = Variable<String>(cost);
    map['duration'] = Variable<String>(duration);
    map['status'] = Variable<String>(status);
    map['progress'] = Variable<int>(progress);
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<String>(target);
    }
    if (!nullToAbsent || done != null) {
      map['done'] = Variable<String>(done);
    }
    map['path'] = Variable<String>(path);
    map['added'] = Variable<String>(added);
    return map;
  }

  CareerGrowthCompanion toCompanion(bool nullToAbsent) {
    return CareerGrowthCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      title: Value(title),
      kind: Value(kind),
      provider: Value(provider),
      url: Value(url),
      why: Value(why),
      cost: Value(cost),
      duration: Value(duration),
      status: Value(status),
      progress: Value(progress),
      target: target == null && nullToAbsent ? const Value.absent() : Value(target),
      done: done == null && nullToAbsent ? const Value.absent() : Value(done),
      path: Value(path),
      added: Value(added),
    );
  }

  factory GrowthItem.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GrowthItem(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<String>(json['kind']),
      provider: serializer.fromJson<String>(json['provider']),
      url: serializer.fromJson<String>(json['url']),
      why: serializer.fromJson<String>(json['why']),
      cost: serializer.fromJson<String>(json['cost']),
      duration: serializer.fromJson<String>(json['duration']),
      status: serializer.fromJson<String>(json['status']),
      progress: serializer.fromJson<int>(json['progress']),
      target: serializer.fromJson<String?>(json['target']),
      done: serializer.fromJson<String?>(json['done']),
      path: serializer.fromJson<String>(json['path']),
      added: serializer.fromJson<String>(json['added']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(kind),
      'provider': serializer.toJson<String>(provider),
      'url': serializer.toJson<String>(url),
      'why': serializer.toJson<String>(why),
      'cost': serializer.toJson<String>(cost),
      'duration': serializer.toJson<String>(duration),
      'status': serializer.toJson<String>(status),
      'progress': serializer.toJson<int>(progress),
      'target': serializer.toJson<String?>(target),
      'done': serializer.toJson<String?>(done),
      'path': serializer.toJson<String>(path),
      'added': serializer.toJson<String>(added),
    };
  }

  GrowthItem copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? title,
    String? kind,
    String? provider,
    String? url,
    String? why,
    String? cost,
    String? duration,
    String? status,
    int? progress,
    Value<String?> target = const Value.absent(),
    Value<String?> done = const Value.absent(),
    String? path,
    String? added,
  }) => GrowthItem(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    provider: provider ?? this.provider,
    url: url ?? this.url,
    why: why ?? this.why,
    cost: cost ?? this.cost,
    duration: duration ?? this.duration,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    target: target.present ? target.value : this.target,
    done: done.present ? done.value : this.done,
    path: path ?? this.path,
    added: added ?? this.added,
  );
  GrowthItem copyWithCompanion(CareerGrowthCompanion data) {
    return GrowthItem(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      provider: data.provider.present ? data.provider.value : this.provider,
      url: data.url.present ? data.url.value : this.url,
      why: data.why.present ? data.why.value : this.why,
      cost: data.cost.present ? data.cost.value : this.cost,
      duration: data.duration.present ? data.duration.value : this.duration,
      status: data.status.present ? data.status.value : this.status,
      progress: data.progress.present ? data.progress.value : this.progress,
      target: data.target.present ? data.target.value : this.target,
      done: data.done.present ? data.done.value : this.done,
      path: data.path.present ? data.path.value : this.path,
      added: data.added.present ? data.added.value : this.added,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GrowthItem(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('provider: $provider, ')
          ..write('url: $url, ')
          ..write('why: $why, ')
          ..write('cost: $cost, ')
          ..write('duration: $duration, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('target: $target, ')
          ..write('done: $done, ')
          ..write('path: $path, ')
          ..write('added: $added')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hlc,
    deleted,
    title,
    kind,
    provider,
    url,
    why,
    cost,
    duration,
    status,
    progress,
    target,
    done,
    path,
    added,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GrowthItem &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.provider == this.provider &&
          other.url == this.url &&
          other.why == this.why &&
          other.cost == this.cost &&
          other.duration == this.duration &&
          other.status == this.status &&
          other.progress == this.progress &&
          other.target == this.target &&
          other.done == this.done &&
          other.path == this.path &&
          other.added == this.added);
}

class CareerGrowthCompanion extends UpdateCompanion<GrowthItem> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> title;
  final Value<String> kind;
  final Value<String> provider;
  final Value<String> url;
  final Value<String> why;
  final Value<String> cost;
  final Value<String> duration;
  final Value<String> status;
  final Value<int> progress;
  final Value<String?> target;
  final Value<String?> done;
  final Value<String> path;
  final Value<String> added;
  final Value<int> rowid;
  const CareerGrowthCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.provider = const Value.absent(),
    this.url = const Value.absent(),
    this.why = const Value.absent(),
    this.cost = const Value.absent(),
    this.duration = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.target = const Value.absent(),
    this.done = const Value.absent(),
    this.path = const Value.absent(),
    this.added = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareerGrowthCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String title,
    required String kind,
    this.provider = const Value.absent(),
    this.url = const Value.absent(),
    this.why = const Value.absent(),
    this.cost = const Value.absent(),
    this.duration = const Value.absent(),
    this.status = const Value.absent(),
    this.progress = const Value.absent(),
    this.target = const Value.absent(),
    this.done = const Value.absent(),
    this.path = const Value.absent(),
    required String added,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       kind = Value(kind),
       added = Value(added);
  static Insertable<GrowthItem> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<String>? provider,
    Expression<String>? url,
    Expression<String>? why,
    Expression<String>? cost,
    Expression<String>? duration,
    Expression<String>? status,
    Expression<int>? progress,
    Expression<String>? target,
    Expression<String>? done,
    Expression<String>? path,
    Expression<String>? added,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (provider != null) 'provider': provider,
      if (url != null) 'url': url,
      if (why != null) 'why': why,
      if (cost != null) 'cost': cost,
      if (duration != null) 'duration': duration,
      if (status != null) 'status': status,
      if (progress != null) 'progress': progress,
      if (target != null) 'target': target,
      if (done != null) 'done': done,
      if (path != null) 'path': path,
      if (added != null) 'added': added,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareerGrowthCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? title,
    Value<String>? kind,
    Value<String>? provider,
    Value<String>? url,
    Value<String>? why,
    Value<String>? cost,
    Value<String>? duration,
    Value<String>? status,
    Value<int>? progress,
    Value<String?>? target,
    Value<String?>? done,
    Value<String>? path,
    Value<String>? added,
    Value<int>? rowid,
  }) {
    return CareerGrowthCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      provider: provider ?? this.provider,
      url: url ?? this.url,
      why: why ?? this.why,
      cost: cost ?? this.cost,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      done: done ?? this.done,
      path: path ?? this.path,
      added: added ?? this.added,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (why.present) {
      map['why'] = Variable<String>(why.value);
    }
    if (cost.present) {
      map['cost'] = Variable<String>(cost.value);
    }
    if (duration.present) {
      map['duration'] = Variable<String>(duration.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (done.present) {
      map['done'] = Variable<String>(done.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (added.present) {
      map['added'] = Variable<String>(added.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareerGrowthCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('provider: $provider, ')
          ..write('url: $url, ')
          ..write('why: $why, ')
          ..write('cost: $cost, ')
          ..write('duration: $duration, ')
          ..write('status: $status, ')
          ..write('progress: $progress, ')
          ..write('target: $target, ')
          ..write('done: $done, ')
          ..write('path: $path, ')
          ..write('added: $added, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareerPracticeTable extends CareerPractice with TableInfo<$CareerPracticeTable, PracticeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareerPracticeTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
    'job_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedMeta = const VerificationMeta('started');
  @override
  late final GeneratedColumn<String> started = GeneratedColumn<String>(
    'started',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionsMeta = const VerificationMeta('questions');
  @override
  late final GeneratedColumn<String> questions = GeneratedColumn<String>(
    'questions',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, jobId, role, mode, started, questions, score];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'career_practice';
  @override
  VerificationContext validateIntegrity(Insertable<PracticeSession> instance, {bool isInserting = false}) {
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
    if (data.containsKey('job_id')) {
      context.handle(_jobIdMeta, jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta));
    }
    if (data.containsKey('role')) {
      context.handle(_roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('started')) {
      context.handle(_startedMeta, started.isAcceptableOrUnknown(data['started']!, _startedMeta));
    } else if (isInserting) {
      context.missing(_startedMeta);
    }
    if (data.containsKey('questions')) {
      context.handle(_questionsMeta, questions.isAcceptableOrUnknown(data['questions']!, _questionsMeta));
    } else if (isInserting) {
      context.missing(_questionsMeta);
    }
    if (data.containsKey('score')) {
      context.handle(_scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSession(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      jobId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}job_id']),
      role: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      mode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      started: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}started'])!,
      questions: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}questions'])!,
      score: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}score']),
    );
  }

  @override
  $CareerPracticeTable createAlias(String alias) {
    return $CareerPracticeTable(attachedDatabase, alias);
  }
}

class PracticeSession extends DataClass implements Insertable<PracticeSession> {
  final String id;
  final String hlc;
  final bool deleted;
  final String? jobId;
  final String role;

  /// standard | competency | technical | toughest | ai
  final String mode;
  final String started;

  /// The question set (PracticeQuestion list as JSON).
  final String questions;

  /// Mean of the scored answers, 0 to 10.
  final double? score;
  const PracticeSession({
    required this.id,
    required this.hlc,
    required this.deleted,
    this.jobId,
    required this.role,
    required this.mode,
    required this.started,
    required this.questions,
    this.score,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    if (!nullToAbsent || jobId != null) {
      map['job_id'] = Variable<String>(jobId);
    }
    map['role'] = Variable<String>(role);
    map['mode'] = Variable<String>(mode);
    map['started'] = Variable<String>(started);
    map['questions'] = Variable<String>(questions);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    return map;
  }

  CareerPracticeCompanion toCompanion(bool nullToAbsent) {
    return CareerPracticeCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      jobId: jobId == null && nullToAbsent ? const Value.absent() : Value(jobId),
      role: Value(role),
      mode: Value(mode),
      started: Value(started),
      questions: Value(questions),
      score: score == null && nullToAbsent ? const Value.absent() : Value(score),
    );
  }

  factory PracticeSession.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSession(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      jobId: serializer.fromJson<String?>(json['jobId']),
      role: serializer.fromJson<String>(json['role']),
      mode: serializer.fromJson<String>(json['mode']),
      started: serializer.fromJson<String>(json['started']),
      questions: serializer.fromJson<String>(json['questions']),
      score: serializer.fromJson<double?>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'jobId': serializer.toJson<String?>(jobId),
      'role': serializer.toJson<String>(role),
      'mode': serializer.toJson<String>(mode),
      'started': serializer.toJson<String>(started),
      'questions': serializer.toJson<String>(questions),
      'score': serializer.toJson<double?>(score),
    };
  }

  PracticeSession copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    Value<String?> jobId = const Value.absent(),
    String? role,
    String? mode,
    String? started,
    String? questions,
    Value<double?> score = const Value.absent(),
  }) => PracticeSession(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    jobId: jobId.present ? jobId.value : this.jobId,
    role: role ?? this.role,
    mode: mode ?? this.mode,
    started: started ?? this.started,
    questions: questions ?? this.questions,
    score: score.present ? score.value : this.score,
  );
  PracticeSession copyWithCompanion(CareerPracticeCompanion data) {
    return PracticeSession(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      role: data.role.present ? data.role.value : this.role,
      mode: data.mode.present ? data.mode.value : this.mode,
      started: data.started.present ? data.started.value : this.started,
      questions: data.questions.present ? data.questions.value : this.questions,
      score: data.score.present ? data.score.value : this.score,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSession(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('jobId: $jobId, ')
          ..write('role: $role, ')
          ..write('mode: $mode, ')
          ..write('started: $started, ')
          ..write('questions: $questions, ')
          ..write('score: $score')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, jobId, role, mode, started, questions, score);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSession &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.jobId == this.jobId &&
          other.role == this.role &&
          other.mode == this.mode &&
          other.started == this.started &&
          other.questions == this.questions &&
          other.score == this.score);
}

class CareerPracticeCompanion extends UpdateCompanion<PracticeSession> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String?> jobId;
  final Value<String> role;
  final Value<String> mode;
  final Value<String> started;
  final Value<String> questions;
  final Value<double?> score;
  final Value<int> rowid;
  const CareerPracticeCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.jobId = const Value.absent(),
    this.role = const Value.absent(),
    this.mode = const Value.absent(),
    this.started = const Value.absent(),
    this.questions = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareerPracticeCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.jobId = const Value.absent(),
    required String role,
    required String mode,
    required String started,
    required String questions,
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       mode = Value(mode),
       started = Value(started),
       questions = Value(questions);
  static Insertable<PracticeSession> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? jobId,
    Expression<String>? role,
    Expression<String>? mode,
    Expression<String>? started,
    Expression<String>? questions,
    Expression<double>? score,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (jobId != null) 'job_id': jobId,
      if (role != null) 'role': role,
      if (mode != null) 'mode': mode,
      if (started != null) 'started': started,
      if (questions != null) 'questions': questions,
      if (score != null) 'score': score,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareerPracticeCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String?>? jobId,
    Value<String>? role,
    Value<String>? mode,
    Value<String>? started,
    Value<String>? questions,
    Value<double?>? score,
    Value<int>? rowid,
  }) {
    return CareerPracticeCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      jobId: jobId ?? this.jobId,
      role: role ?? this.role,
      mode: mode ?? this.mode,
      started: started ?? this.started,
      questions: questions ?? this.questions,
      score: score ?? this.score,
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
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (started.present) {
      map['started'] = Variable<String>(started.value);
    }
    if (questions.present) {
      map['questions'] = Variable<String>(questions.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareerPracticeCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('jobId: $jobId, ')
          ..write('role: $role, ')
          ..write('mode: $mode, ')
          ..write('started: $started, ')
          ..write('questions: $questions, ')
          ..write('score: $score, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareerAnswersTable extends CareerAnswers with TableInfo<$CareerAnswersTable, PracticeAnswer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareerAnswersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta('question');
  @override
  late final GeneratedColumn<int> question = GeneratedColumn<int>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reviewMeta = const VerificationMeta('review');
  @override
  late final GeneratedColumn<String> review = GeneratedColumn<String>(
    'review',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, sessionId, question, answer, at, review, score];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'career_answers';
  @override
  VerificationContext validateIntegrity(Insertable<PracticeAnswer> instance, {bool isInserting = false}) {
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
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta, sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('question')) {
      context.handle(_questionMeta, question.isAcceptableOrUnknown(data['question']!, _questionMeta));
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(_answerMeta, answer.isAcceptableOrUnknown(data['answer']!, _answerMeta));
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('review')) {
      context.handle(_reviewMeta, review.isAcceptableOrUnknown(data['review']!, _reviewMeta));
    }
    if (data.containsKey('score')) {
      context.handle(_scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeAnswer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeAnswer(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      question: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}question'])!,
      answer: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}answer'])!,
      at: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}at'])!,
      review: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}review'])!,
      score: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}score']),
    );
  }

  @override
  $CareerAnswersTable createAlias(String alias) {
    return $CareerAnswersTable(attachedDatabase, alias);
  }
}

class PracticeAnswer extends DataClass implements Insertable<PracticeAnswer> {
  final String id;
  final String hlc;
  final bool deleted;
  final String sessionId;
  final int question;
  final String answer;
  final String at;

  /// AnswerReview as JSON, '' until evaluated.
  final String review;
  final double? score;
  const PracticeAnswer({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.sessionId,
    required this.question,
    required this.answer,
    required this.at,
    required this.review,
    this.score,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['session_id'] = Variable<String>(sessionId);
    map['question'] = Variable<int>(question);
    map['answer'] = Variable<String>(answer);
    map['at'] = Variable<String>(at);
    map['review'] = Variable<String>(review);
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    return map;
  }

  CareerAnswersCompanion toCompanion(bool nullToAbsent) {
    return CareerAnswersCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      sessionId: Value(sessionId),
      question: Value(question),
      answer: Value(answer),
      at: Value(at),
      review: Value(review),
      score: score == null && nullToAbsent ? const Value.absent() : Value(score),
    );
  }

  factory PracticeAnswer.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeAnswer(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      question: serializer.fromJson<int>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      at: serializer.fromJson<String>(json['at']),
      review: serializer.fromJson<String>(json['review']),
      score: serializer.fromJson<double?>(json['score']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'sessionId': serializer.toJson<String>(sessionId),
      'question': serializer.toJson<int>(question),
      'answer': serializer.toJson<String>(answer),
      'at': serializer.toJson<String>(at),
      'review': serializer.toJson<String>(review),
      'score': serializer.toJson<double?>(score),
    };
  }

  PracticeAnswer copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? sessionId,
    int? question,
    String? answer,
    String? at,
    String? review,
    Value<double?> score = const Value.absent(),
  }) => PracticeAnswer(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    sessionId: sessionId ?? this.sessionId,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    at: at ?? this.at,
    review: review ?? this.review,
    score: score.present ? score.value : this.score,
  );
  PracticeAnswer copyWithCompanion(CareerAnswersCompanion data) {
    return PracticeAnswer(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      at: data.at.present ? data.at.value : this.at,
      review: data.review.present ? data.review.value : this.review,
      score: data.score.present ? data.score.value : this.score,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeAnswer(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('sessionId: $sessionId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('at: $at, ')
          ..write('review: $review, ')
          ..write('score: $score')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, sessionId, question, answer, at, review, score);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeAnswer &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.sessionId == this.sessionId &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.at == this.at &&
          other.review == this.review &&
          other.score == this.score);
}

class CareerAnswersCompanion extends UpdateCompanion<PracticeAnswer> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> sessionId;
  final Value<int> question;
  final Value<String> answer;
  final Value<String> at;
  final Value<String> review;
  final Value<double?> score;
  final Value<int> rowid;
  const CareerAnswersCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.at = const Value.absent(),
    this.review = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareerAnswersCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String sessionId,
    required int question,
    required String answer,
    required String at,
    this.review = const Value.absent(),
    this.score = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       question = Value(question),
       answer = Value(answer),
       at = Value(at);
  static Insertable<PracticeAnswer> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? sessionId,
    Expression<int>? question,
    Expression<String>? answer,
    Expression<String>? at,
    Expression<String>? review,
    Expression<double>? score,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (sessionId != null) 'session_id': sessionId,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (at != null) 'at': at,
      if (review != null) 'review': review,
      if (score != null) 'score': score,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareerAnswersCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? sessionId,
    Value<int>? question,
    Value<String>? answer,
    Value<String>? at,
    Value<String>? review,
    Value<double?>? score,
    Value<int>? rowid,
  }) {
    return CareerAnswersCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      sessionId: sessionId ?? this.sessionId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      at: at ?? this.at,
      review: review ?? this.review,
      score: score ?? this.score,
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
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (question.present) {
      map['question'] = Variable<int>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (review.present) {
      map['review'] = Variable<String>(review.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareerAnswersCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('sessionId: $sessionId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('at: $at, ')
          ..write('review: $review, ')
          ..write('score: $score, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

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
  late final $JobListingsTable jobListings = $JobListingsTable(this);
  late final $JobApplicationsTable jobApplications = $JobApplicationsTable(this);
  late final $JobEventsTable jobEvents = $JobEventsTable(this);
  late final $CareerContactsTable careerContacts = $CareerContactsTable(this);
  late final $CareerResumesTable careerResumes = $CareerResumesTable(this);
  late final $CareerReportsTable careerReports = $CareerReportsTable(this);
  late final $CareerGrowthTable careerGrowth = $CareerGrowthTable(this);
  late final $CareerPracticeTable careerPractice = $CareerPracticeTable(this);
  late final $CareerAnswersTable careerAnswers = $CareerAnswersTable(this);
  late final $PrefsTable prefs = $PrefsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    jobListings,
    jobApplications,
    jobEvents,
    careerContacts,
    careerResumes,
    careerReports,
    careerGrowth,
    careerPractice,
    careerAnswers,
    prefs,
    outbox,
    syncCursors,
    localSettings,
  ];
}

typedef $$JobListingsTableCreateCompanionBuilder = JobListingsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String title,
  Value<String> company,
  Value<String> location,
  Value<String> country,
  Value<bool> remote,
  Value<int?> salaryMin,
  Value<int?> salaryMax,
  Value<String> currency,
  Value<String> salaryText,
  Value<String> url,
  Value<String> description,
  Value<String?> posted,
  Value<String?> closing,
  Value<String> source,
  Value<String> sourceId,
  required String found,
  Value<String> status,
  Value<int?> fit,
  Value<String> assessment,
  Value<String> notes,
  Value<int> rowid,
});
typedef $$JobListingsTableUpdateCompanionBuilder = JobListingsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> title,
  Value<String> company,
  Value<String> location,
  Value<String> country,
  Value<bool> remote,
  Value<int?> salaryMin,
  Value<int?> salaryMax,
  Value<String> currency,
  Value<String> salaryText,
  Value<String> url,
  Value<String> description,
  Value<String?> posted,
  Value<String?> closing,
  Value<String> source,
  Value<String> sourceId,
  Value<String> found,
  Value<String> status,
  Value<int?> fit,
  Value<String> assessment,
  Value<String> notes,
  Value<int> rowid,
});

class $$JobListingsTableFilterComposer extends Composer<_$AppDatabase, $JobListingsTable> {
  $$JobListingsTableFilterComposer({
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

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get remote =>
      $composableBuilder(column: $table.remote, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get salaryMin =>
      $composableBuilder(column: $table.salaryMin, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get salaryMax =>
      $composableBuilder(column: $table.salaryMax, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get salaryText =>
      $composableBuilder(column: $table.salaryText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get posted =>
      $composableBuilder(column: $table.posted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get closing =>
      $composableBuilder(column: $table.closing, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get found =>
      $composableBuilder(column: $table.found, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fit =>
      $composableBuilder(column: $table.fit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get assessment =>
      $composableBuilder(column: $table.assessment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$JobListingsTableOrderingComposer extends Composer<_$AppDatabase, $JobListingsTable> {
  $$JobListingsTableOrderingComposer({
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

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get remote =>
      $composableBuilder(column: $table.remote, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get salaryMin =>
      $composableBuilder(column: $table.salaryMin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get salaryMax =>
      $composableBuilder(column: $table.salaryMax, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get salaryText =>
      $composableBuilder(column: $table.salaryText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get posted =>
      $composableBuilder(column: $table.posted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get closing =>
      $composableBuilder(column: $table.closing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get found =>
      $composableBuilder(column: $table.found, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fit =>
      $composableBuilder(column: $table.fit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get assessment =>
      $composableBuilder(column: $table.assessment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$JobListingsTableAnnotationComposer extends Composer<_$AppDatabase, $JobListingsTable> {
  $$JobListingsTableAnnotationComposer({
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

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<bool> get remote => $composableBuilder(column: $table.remote, builder: (column) => column);

  GeneratedColumn<int> get salaryMin =>
      $composableBuilder(column: $table.salaryMin, builder: (column) => column);

  GeneratedColumn<int> get salaryMax =>
      $composableBuilder(column: $table.salaryMax, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get salaryText =>
      $composableBuilder(column: $table.salaryText, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get posted =>
      $composableBuilder(column: $table.posted, builder: (column) => column);

  GeneratedColumn<String> get closing =>
      $composableBuilder(column: $table.closing, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get found => $composableBuilder(column: $table.found, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get fit => $composableBuilder(column: $table.fit, builder: (column) => column);

  GeneratedColumn<String> get assessment =>
      $composableBuilder(column: $table.assessment, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$JobListingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JobListingsTable,
          Job,
          $$JobListingsTableFilterComposer,
          $$JobListingsTableOrderingComposer,
          $$JobListingsTableAnnotationComposer,
          $$JobListingsTableCreateCompanionBuilder,
          $$JobListingsTableUpdateCompanionBuilder,
          (Job, BaseReferences<_$AppDatabase, $JobListingsTable, Job>),
          Job,
          PrefetchHooks Function()
        > {
  $$JobListingsTableTableManager(_$AppDatabase db, $JobListingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$JobListingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$JobListingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$JobListingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> country = const Value.absent(),
                Value<bool> remote = const Value.absent(),
                Value<int?> salaryMin = const Value.absent(),
                Value<int?> salaryMax = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> salaryText = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> posted = const Value.absent(),
                Value<String?> closing = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> found = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> fit = const Value.absent(),
                Value<String> assessment = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobListingsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                title: title,
                company: company,
                location: location,
                country: country,
                remote: remote,
                salaryMin: salaryMin,
                salaryMax: salaryMax,
                currency: currency,
                salaryText: salaryText,
                url: url,
                description: description,
                posted: posted,
                closing: closing,
                source: source,
                sourceId: sourceId,
                found: found,
                status: status,
                fit: fit,
                assessment: assessment,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String title,
                Value<String> company = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> country = const Value.absent(),
                Value<bool> remote = const Value.absent(),
                Value<int?> salaryMin = const Value.absent(),
                Value<int?> salaryMax = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> salaryText = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> posted = const Value.absent(),
                Value<String?> closing = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                required String found,
                Value<String> status = const Value.absent(),
                Value<int?> fit = const Value.absent(),
                Value<String> assessment = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobListingsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                title: title,
                company: company,
                location: location,
                country: country,
                remote: remote,
                salaryMin: salaryMin,
                salaryMax: salaryMax,
                currency: currency,
                salaryText: salaryText,
                url: url,
                description: description,
                posted: posted,
                closing: closing,
                source: source,
                sourceId: sourceId,
                found: found,
                status: status,
                fit: fit,
                assessment: assessment,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JobListingsTable, Job>(table),
                  BaseReferences<_$AppDatabase, $JobListingsTable, Job>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JobListingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JobListingsTable,
      Job,
      $$JobListingsTableFilterComposer,
      $$JobListingsTableOrderingComposer,
      $$JobListingsTableAnnotationComposer,
      $$JobListingsTableCreateCompanionBuilder,
      $$JobListingsTableUpdateCompanionBuilder,
      (Job, BaseReferences<_$AppDatabase, $JobListingsTable, Job>),
      Job,
      PrefetchHooks Function()
    >;
typedef $$JobApplicationsTableCreateCompanionBuilder = JobApplicationsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String?> jobId,
  required String title,
  Value<String> company,
  Value<String> location,
  Value<String> url,
  Value<String> stage,
  Value<String?> applied,
  Value<String?> followUp,
  Value<String> followUpNote,
  Value<String?> resumeId,
  Value<String> reference,
  Value<String> notes,
  required String updated,
  Value<int> rowid,
});
typedef $$JobApplicationsTableUpdateCompanionBuilder = JobApplicationsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String?> jobId,
  Value<String> title,
  Value<String> company,
  Value<String> location,
  Value<String> url,
  Value<String> stage,
  Value<String?> applied,
  Value<String?> followUp,
  Value<String> followUpNote,
  Value<String?> resumeId,
  Value<String> reference,
  Value<String> notes,
  Value<String> updated,
  Value<int> rowid,
});

class $$JobApplicationsTableFilterComposer extends Composer<_$AppDatabase, $JobApplicationsTable> {
  $$JobApplicationsTableFilterComposer({
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

  ColumnFilters<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get applied =>
      $composableBuilder(column: $table.applied, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get followUp =>
      $composableBuilder(column: $table.followUp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get followUpNote =>
      $composableBuilder(column: $table.followUpNote, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resumeId =>
      $composableBuilder(column: $table.resumeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => ColumnFilters(column));
}

class $$JobApplicationsTableOrderingComposer extends Composer<_$AppDatabase, $JobApplicationsTable> {
  $$JobApplicationsTableOrderingComposer({
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

  ColumnOrderings<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get applied =>
      $composableBuilder(column: $table.applied, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get followUp =>
      $composableBuilder(column: $table.followUp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get followUpNote =>
      $composableBuilder(column: $table.followUpNote, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resumeId =>
      $composableBuilder(column: $table.resumeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => ColumnOrderings(column));
}

class $$JobApplicationsTableAnnotationComposer extends Composer<_$AppDatabase, $JobApplicationsTable> {
  $$JobApplicationsTableAnnotationComposer({
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

  GeneratedColumn<String> get jobId => $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get stage => $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get applied =>
      $composableBuilder(column: $table.applied, builder: (column) => column);

  GeneratedColumn<String> get followUp =>
      $composableBuilder(column: $table.followUp, builder: (column) => column);

  GeneratedColumn<String> get followUpNote =>
      $composableBuilder(column: $table.followUpNote, builder: (column) => column);

  GeneratedColumn<String> get resumeId =>
      $composableBuilder(column: $table.resumeId, builder: (column) => column);

  GeneratedColumn<String> get reference =>
      $composableBuilder(column: $table.reference, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);
}

class $$JobApplicationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JobApplicationsTable,
          JobApplication,
          $$JobApplicationsTableFilterComposer,
          $$JobApplicationsTableOrderingComposer,
          $$JobApplicationsTableAnnotationComposer,
          $$JobApplicationsTableCreateCompanionBuilder,
          $$JobApplicationsTableUpdateCompanionBuilder,
          (JobApplication, BaseReferences<_$AppDatabase, $JobApplicationsTable, JobApplication>),
          JobApplication,
          PrefetchHooks Function()
        > {
  $$JobApplicationsTableTableManager(_$AppDatabase db, $JobApplicationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$JobApplicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$JobApplicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$JobApplicationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> jobId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String?> applied = const Value.absent(),
                Value<String?> followUp = const Value.absent(),
                Value<String> followUpNote = const Value.absent(),
                Value<String?> resumeId = const Value.absent(),
                Value<String> reference = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> updated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobApplicationsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                jobId: jobId,
                title: title,
                company: company,
                location: location,
                url: url,
                stage: stage,
                applied: applied,
                followUp: followUp,
                followUpNote: followUpNote,
                resumeId: resumeId,
                reference: reference,
                notes: notes,
                updated: updated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> jobId = const Value.absent(),
                required String title,
                Value<String> company = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String?> applied = const Value.absent(),
                Value<String?> followUp = const Value.absent(),
                Value<String> followUpNote = const Value.absent(),
                Value<String?> resumeId = const Value.absent(),
                Value<String> reference = const Value.absent(),
                Value<String> notes = const Value.absent(),
                required String updated,
                Value<int> rowid = const Value.absent(),
              }) => JobApplicationsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                jobId: jobId,
                title: title,
                company: company,
                location: location,
                url: url,
                stage: stage,
                applied: applied,
                followUp: followUp,
                followUpNote: followUpNote,
                resumeId: resumeId,
                reference: reference,
                notes: notes,
                updated: updated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JobApplicationsTable, JobApplication>(table),
                  BaseReferences<_$AppDatabase, $JobApplicationsTable, JobApplication>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JobApplicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JobApplicationsTable,
      JobApplication,
      $$JobApplicationsTableFilterComposer,
      $$JobApplicationsTableOrderingComposer,
      $$JobApplicationsTableAnnotationComposer,
      $$JobApplicationsTableCreateCompanionBuilder,
      $$JobApplicationsTableUpdateCompanionBuilder,
      (JobApplication, BaseReferences<_$AppDatabase, $JobApplicationsTable, JobApplication>),
      JobApplication,
      PrefetchHooks Function()
    >;
typedef $$JobEventsTableCreateCompanionBuilder = JobEventsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String applicationId,
  required String at,
  required String kind,
  Value<String> summary,
  Value<int> rowid,
});
typedef $$JobEventsTableUpdateCompanionBuilder = JobEventsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> applicationId,
  Value<String> at,
  Value<String> kind,
  Value<String> summary,
  Value<int> rowid,
});

class $$JobEventsTableFilterComposer extends Composer<_$AppDatabase, $JobEventsTable> {
  $$JobEventsTableFilterComposer({
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

  ColumnFilters<String> get applicationId =>
      $composableBuilder(column: $table.applicationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => ColumnFilters(column));
}

class $$JobEventsTableOrderingComposer extends Composer<_$AppDatabase, $JobEventsTable> {
  $$JobEventsTableOrderingComposer({
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

  ColumnOrderings<String> get applicationId =>
      $composableBuilder(column: $table.applicationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => ColumnOrderings(column));
}

class $$JobEventsTableAnnotationComposer extends Composer<_$AppDatabase, $JobEventsTable> {
  $$JobEventsTableAnnotationComposer({
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

  GeneratedColumn<String> get applicationId =>
      $composableBuilder(column: $table.applicationId, builder: (column) => column);

  GeneratedColumn<String> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);
}

class $$JobEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JobEventsTable,
          JobEvent,
          $$JobEventsTableFilterComposer,
          $$JobEventsTableOrderingComposer,
          $$JobEventsTableAnnotationComposer,
          $$JobEventsTableCreateCompanionBuilder,
          $$JobEventsTableUpdateCompanionBuilder,
          (JobEvent, BaseReferences<_$AppDatabase, $JobEventsTable, JobEvent>),
          JobEvent,
          PrefetchHooks Function()
        > {
  $$JobEventsTableTableManager(_$AppDatabase db, $JobEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$JobEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$JobEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$JobEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> applicationId = const Value.absent(),
                Value<String> at = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobEventsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                applicationId: applicationId,
                at: at,
                kind: kind,
                summary: summary,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String applicationId,
                required String at,
                required String kind,
                Value<String> summary = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JobEventsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                applicationId: applicationId,
                at: at,
                kind: kind,
                summary: summary,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$JobEventsTable, JobEvent>(table),
                  BaseReferences<_$AppDatabase, $JobEventsTable, JobEvent>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$JobEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JobEventsTable,
      JobEvent,
      $$JobEventsTableFilterComposer,
      $$JobEventsTableOrderingComposer,
      $$JobEventsTableAnnotationComposer,
      $$JobEventsTableCreateCompanionBuilder,
      $$JobEventsTableUpdateCompanionBuilder,
      (JobEvent, BaseReferences<_$AppDatabase, $JobEventsTable, JobEvent>),
      JobEvent,
      PrefetchHooks Function()
    >;
typedef $$CareerContactsTableCreateCompanionBuilder = CareerContactsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String name,
  Value<String> kind,
  Value<String> title,
  Value<String> company,
  Value<String> email,
  Value<String> phone,
  Value<String> linkedin,
  Value<String> source,
  Value<String> status,
  Value<String?> lastContact,
  Value<String?> followUp,
  Value<String?> jobId,
  Value<String> notes,
  Value<int> rowid,
});
typedef $$CareerContactsTableUpdateCompanionBuilder = CareerContactsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> name,
  Value<String> kind,
  Value<String> title,
  Value<String> company,
  Value<String> email,
  Value<String> phone,
  Value<String> linkedin,
  Value<String> source,
  Value<String> status,
  Value<String?> lastContact,
  Value<String?> followUp,
  Value<String?> jobId,
  Value<String> notes,
  Value<int> rowid,
});

class $$CareerContactsTableFilterComposer extends Composer<_$AppDatabase, $CareerContactsTable> {
  $$CareerContactsTableFilterComposer({
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

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get linkedin =>
      $composableBuilder(column: $table.linkedin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastContact =>
      $composableBuilder(column: $table.lastContact, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get followUp =>
      $composableBuilder(column: $table.followUp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$CareerContactsTableOrderingComposer extends Composer<_$AppDatabase, $CareerContactsTable> {
  $$CareerContactsTableOrderingComposer({
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

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get linkedin =>
      $composableBuilder(column: $table.linkedin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastContact =>
      $composableBuilder(column: $table.lastContact, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get followUp =>
      $composableBuilder(column: $table.followUp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$CareerContactsTableAnnotationComposer extends Composer<_$AppDatabase, $CareerContactsTable> {
  $$CareerContactsTableAnnotationComposer({
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

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get email => $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phone => $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get linkedin =>
      $composableBuilder(column: $table.linkedin, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastContact =>
      $composableBuilder(column: $table.lastContact, builder: (column) => column);

  GeneratedColumn<String> get followUp =>
      $composableBuilder(column: $table.followUp, builder: (column) => column);

  GeneratedColumn<String> get jobId => $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$CareerContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareerContactsTable,
          Lead,
          $$CareerContactsTableFilterComposer,
          $$CareerContactsTableOrderingComposer,
          $$CareerContactsTableAnnotationComposer,
          $$CareerContactsTableCreateCompanionBuilder,
          $$CareerContactsTableUpdateCompanionBuilder,
          (Lead, BaseReferences<_$AppDatabase, $CareerContactsTable, Lead>),
          Lead,
          PrefetchHooks Function()
        > {
  $$CareerContactsTableTableManager(_$AppDatabase db, $CareerContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CareerContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CareerContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CareerContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> linkedin = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastContact = const Value.absent(),
                Value<String?> followUp = const Value.absent(),
                Value<String?> jobId = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerContactsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                name: name,
                kind: kind,
                title: title,
                company: company,
                email: email,
                phone: phone,
                linkedin: linkedin,
                source: source,
                status: status,
                lastContact: lastContact,
                followUp: followUp,
                jobId: jobId,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String name,
                Value<String> kind = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> linkedin = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> lastContact = const Value.absent(),
                Value<String?> followUp = const Value.absent(),
                Value<String?> jobId = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerContactsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                name: name,
                kind: kind,
                title: title,
                company: company,
                email: email,
                phone: phone,
                linkedin: linkedin,
                source: source,
                status: status,
                lastContact: lastContact,
                followUp: followUp,
                jobId: jobId,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CareerContactsTable, Lead>(table),
                  BaseReferences<_$AppDatabase, $CareerContactsTable, Lead>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareerContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareerContactsTable,
      Lead,
      $$CareerContactsTableFilterComposer,
      $$CareerContactsTableOrderingComposer,
      $$CareerContactsTableAnnotationComposer,
      $$CareerContactsTableCreateCompanionBuilder,
      $$CareerContactsTableUpdateCompanionBuilder,
      (Lead, BaseReferences<_$AppDatabase, $CareerContactsTable, Lead>),
      Lead,
      PrefetchHooks Function()
    >;
typedef $$CareerResumesTableCreateCompanionBuilder = CareerResumesCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String name,
  Value<String?> jobId,
  required String created,
  required String content,
  Value<String> tailoring,
  Value<int> rowid,
});
typedef $$CareerResumesTableUpdateCompanionBuilder = CareerResumesCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> name,
  Value<String?> jobId,
  Value<String> created,
  Value<String> content,
  Value<String> tailoring,
  Value<int> rowid,
});

class $$CareerResumesTableFilterComposer extends Composer<_$AppDatabase, $CareerResumesTable> {
  $$CareerResumesTableFilterComposer({
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

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tailoring =>
      $composableBuilder(column: $table.tailoring, builder: (column) => ColumnFilters(column));
}

class $$CareerResumesTableOrderingComposer extends Composer<_$AppDatabase, $CareerResumesTable> {
  $$CareerResumesTableOrderingComposer({
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

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tailoring =>
      $composableBuilder(column: $table.tailoring, builder: (column) => ColumnOrderings(column));
}

class $$CareerResumesTableAnnotationComposer extends Composer<_$AppDatabase, $CareerResumesTable> {
  $$CareerResumesTableAnnotationComposer({
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

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get jobId => $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get tailoring =>
      $composableBuilder(column: $table.tailoring, builder: (column) => column);
}

class $$CareerResumesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareerResumesTable,
          Resume,
          $$CareerResumesTableFilterComposer,
          $$CareerResumesTableOrderingComposer,
          $$CareerResumesTableAnnotationComposer,
          $$CareerResumesTableCreateCompanionBuilder,
          $$CareerResumesTableUpdateCompanionBuilder,
          (Resume, BaseReferences<_$AppDatabase, $CareerResumesTable, Resume>),
          Resume,
          PrefetchHooks Function()
        > {
  $$CareerResumesTableTableManager(_$AppDatabase db, $CareerResumesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CareerResumesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CareerResumesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CareerResumesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> jobId = const Value.absent(),
                Value<String> created = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> tailoring = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerResumesCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                name: name,
                jobId: jobId,
                created: created,
                content: content,
                tailoring: tailoring,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String name,
                Value<String?> jobId = const Value.absent(),
                required String created,
                required String content,
                Value<String> tailoring = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerResumesCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                name: name,
                jobId: jobId,
                created: created,
                content: content,
                tailoring: tailoring,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CareerResumesTable, Resume>(table),
                  BaseReferences<_$AppDatabase, $CareerResumesTable, Resume>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareerResumesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareerResumesTable,
      Resume,
      $$CareerResumesTableFilterComposer,
      $$CareerResumesTableOrderingComposer,
      $$CareerResumesTableAnnotationComposer,
      $$CareerResumesTableCreateCompanionBuilder,
      $$CareerResumesTableUpdateCompanionBuilder,
      (Resume, BaseReferences<_$AppDatabase, $CareerResumesTable, Resume>),
      Resume,
      PrefetchHooks Function()
    >;
typedef $$CareerReportsTableCreateCompanionBuilder = CareerReportsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String kind,
  required String created,
  required String content,
  Value<String> sources,
  Value<int> rowid,
});
typedef $$CareerReportsTableUpdateCompanionBuilder = CareerReportsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> kind,
  Value<String> created,
  Value<String> content,
  Value<String> sources,
  Value<int> rowid,
});

class $$CareerReportsTableFilterComposer extends Composer<_$AppDatabase, $CareerReportsTable> {
  $$CareerReportsTableFilterComposer({
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

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => ColumnFilters(column));
}

class $$CareerReportsTableOrderingComposer extends Composer<_$AppDatabase, $CareerReportsTable> {
  $$CareerReportsTableOrderingComposer({
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

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => ColumnOrderings(column));
}

class $$CareerReportsTableAnnotationComposer extends Composer<_$AppDatabase, $CareerReportsTable> {
  $$CareerReportsTableAnnotationComposer({
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

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sources =>
      $composableBuilder(column: $table.sources, builder: (column) => column);
}

class $$CareerReportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareerReportsTable,
          Report,
          $$CareerReportsTableFilterComposer,
          $$CareerReportsTableOrderingComposer,
          $$CareerReportsTableAnnotationComposer,
          $$CareerReportsTableCreateCompanionBuilder,
          $$CareerReportsTableUpdateCompanionBuilder,
          (Report, BaseReferences<_$AppDatabase, $CareerReportsTable, Report>),
          Report,
          PrefetchHooks Function()
        > {
  $$CareerReportsTableTableManager(_$AppDatabase db, $CareerReportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CareerReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CareerReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CareerReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> created = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> sources = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerReportsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                kind: kind,
                created: created,
                content: content,
                sources: sources,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String kind,
                required String created,
                required String content,
                Value<String> sources = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerReportsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                kind: kind,
                created: created,
                content: content,
                sources: sources,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CareerReportsTable, Report>(table),
                  BaseReferences<_$AppDatabase, $CareerReportsTable, Report>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareerReportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareerReportsTable,
      Report,
      $$CareerReportsTableFilterComposer,
      $$CareerReportsTableOrderingComposer,
      $$CareerReportsTableAnnotationComposer,
      $$CareerReportsTableCreateCompanionBuilder,
      $$CareerReportsTableUpdateCompanionBuilder,
      (Report, BaseReferences<_$AppDatabase, $CareerReportsTable, Report>),
      Report,
      PrefetchHooks Function()
    >;
typedef $$CareerGrowthTableCreateCompanionBuilder = CareerGrowthCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String title,
  required String kind,
  Value<String> provider,
  Value<String> url,
  Value<String> why,
  Value<String> cost,
  Value<String> duration,
  Value<String> status,
  Value<int> progress,
  Value<String?> target,
  Value<String?> done,
  Value<String> path,
  required String added,
  Value<int> rowid,
});
typedef $$CareerGrowthTableUpdateCompanionBuilder = CareerGrowthCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> title,
  Value<String> kind,
  Value<String> provider,
  Value<String> url,
  Value<String> why,
  Value<String> cost,
  Value<String> duration,
  Value<String> status,
  Value<int> progress,
  Value<String?> target,
  Value<String?> done,
  Value<String> path,
  Value<String> added,
  Value<int> rowid,
});

class $$CareerGrowthTableFilterComposer extends Composer<_$AppDatabase, $CareerGrowthTable> {
  $$CareerGrowthTableFilterComposer({
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

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get why =>
      $composableBuilder(column: $table.why, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get done =>
      $composableBuilder(column: $table.done, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get added =>
      $composableBuilder(column: $table.added, builder: (column) => ColumnFilters(column));
}

class $$CareerGrowthTableOrderingComposer extends Composer<_$AppDatabase, $CareerGrowthTable> {
  $$CareerGrowthTableOrderingComposer({
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

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get why =>
      $composableBuilder(column: $table.why, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get done =>
      $composableBuilder(column: $table.done, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get added =>
      $composableBuilder(column: $table.added, builder: (column) => ColumnOrderings(column));
}

class $$CareerGrowthTableAnnotationComposer extends Composer<_$AppDatabase, $CareerGrowthTable> {
  $$CareerGrowthTableAnnotationComposer({
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

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get why => $composableBuilder(column: $table.why, builder: (column) => column);

  GeneratedColumn<String> get cost => $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<String> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get done => $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<String> get path => $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get added => $composableBuilder(column: $table.added, builder: (column) => column);
}

class $$CareerGrowthTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareerGrowthTable,
          GrowthItem,
          $$CareerGrowthTableFilterComposer,
          $$CareerGrowthTableOrderingComposer,
          $$CareerGrowthTableAnnotationComposer,
          $$CareerGrowthTableCreateCompanionBuilder,
          $$CareerGrowthTableUpdateCompanionBuilder,
          (GrowthItem, BaseReferences<_$AppDatabase, $CareerGrowthTable, GrowthItem>),
          GrowthItem,
          PrefetchHooks Function()
        > {
  $$CareerGrowthTableTableManager(_$AppDatabase db, $CareerGrowthTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CareerGrowthTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CareerGrowthTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CareerGrowthTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> why = const Value.absent(),
                Value<String> cost = const Value.absent(),
                Value<String> duration = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<String?> target = const Value.absent(),
                Value<String?> done = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> added = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerGrowthCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                title: title,
                kind: kind,
                provider: provider,
                url: url,
                why: why,
                cost: cost,
                duration: duration,
                status: status,
                progress: progress,
                target: target,
                done: done,
                path: path,
                added: added,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String title,
                required String kind,
                Value<String> provider = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> why = const Value.absent(),
                Value<String> cost = const Value.absent(),
                Value<String> duration = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> progress = const Value.absent(),
                Value<String?> target = const Value.absent(),
                Value<String?> done = const Value.absent(),
                Value<String> path = const Value.absent(),
                required String added,
                Value<int> rowid = const Value.absent(),
              }) => CareerGrowthCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                title: title,
                kind: kind,
                provider: provider,
                url: url,
                why: why,
                cost: cost,
                duration: duration,
                status: status,
                progress: progress,
                target: target,
                done: done,
                path: path,
                added: added,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CareerGrowthTable, GrowthItem>(table),
                  BaseReferences<_$AppDatabase, $CareerGrowthTable, GrowthItem>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareerGrowthTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareerGrowthTable,
      GrowthItem,
      $$CareerGrowthTableFilterComposer,
      $$CareerGrowthTableOrderingComposer,
      $$CareerGrowthTableAnnotationComposer,
      $$CareerGrowthTableCreateCompanionBuilder,
      $$CareerGrowthTableUpdateCompanionBuilder,
      (GrowthItem, BaseReferences<_$AppDatabase, $CareerGrowthTable, GrowthItem>),
      GrowthItem,
      PrefetchHooks Function()
    >;
typedef $$CareerPracticeTableCreateCompanionBuilder = CareerPracticeCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String?> jobId,
  required String role,
  required String mode,
  required String started,
  required String questions,
  Value<double?> score,
  Value<int> rowid,
});
typedef $$CareerPracticeTableUpdateCompanionBuilder = CareerPracticeCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String?> jobId,
  Value<String> role,
  Value<String> mode,
  Value<String> started,
  Value<String> questions,
  Value<double?> score,
  Value<int> rowid,
});

class $$CareerPracticeTableFilterComposer extends Composer<_$AppDatabase, $CareerPracticeTable> {
  $$CareerPracticeTableFilterComposer({
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

  ColumnFilters<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get started =>
      $composableBuilder(column: $table.started, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get questions =>
      $composableBuilder(column: $table.questions, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => ColumnFilters(column));
}

class $$CareerPracticeTableOrderingComposer extends Composer<_$AppDatabase, $CareerPracticeTable> {
  $$CareerPracticeTableOrderingComposer({
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

  ColumnOrderings<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get started =>
      $composableBuilder(column: $table.started, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get questions =>
      $composableBuilder(column: $table.questions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => ColumnOrderings(column));
}

class $$CareerPracticeTableAnnotationComposer extends Composer<_$AppDatabase, $CareerPracticeTable> {
  $$CareerPracticeTableAnnotationComposer({
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

  GeneratedColumn<String> get jobId => $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get role => $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get started =>
      $composableBuilder(column: $table.started, builder: (column) => column);

  GeneratedColumn<String> get questions =>
      $composableBuilder(column: $table.questions, builder: (column) => column);

  GeneratedColumn<double> get score => $composableBuilder(column: $table.score, builder: (column) => column);
}

class $$CareerPracticeTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareerPracticeTable,
          PracticeSession,
          $$CareerPracticeTableFilterComposer,
          $$CareerPracticeTableOrderingComposer,
          $$CareerPracticeTableAnnotationComposer,
          $$CareerPracticeTableCreateCompanionBuilder,
          $$CareerPracticeTableUpdateCompanionBuilder,
          (PracticeSession, BaseReferences<_$AppDatabase, $CareerPracticeTable, PracticeSession>),
          PracticeSession,
          PrefetchHooks Function()
        > {
  $$CareerPracticeTableTableManager(_$AppDatabase db, $CareerPracticeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CareerPracticeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CareerPracticeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CareerPracticeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> jobId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> started = const Value.absent(),
                Value<String> questions = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerPracticeCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                jobId: jobId,
                role: role,
                mode: mode,
                started: started,
                questions: questions,
                score: score,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String?> jobId = const Value.absent(),
                required String role,
                required String mode,
                required String started,
                required String questions,
                Value<double?> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerPracticeCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                jobId: jobId,
                role: role,
                mode: mode,
                started: started,
                questions: questions,
                score: score,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CareerPracticeTable, PracticeSession>(table),
                  BaseReferences<_$AppDatabase, $CareerPracticeTable, PracticeSession>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareerPracticeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareerPracticeTable,
      PracticeSession,
      $$CareerPracticeTableFilterComposer,
      $$CareerPracticeTableOrderingComposer,
      $$CareerPracticeTableAnnotationComposer,
      $$CareerPracticeTableCreateCompanionBuilder,
      $$CareerPracticeTableUpdateCompanionBuilder,
      (PracticeSession, BaseReferences<_$AppDatabase, $CareerPracticeTable, PracticeSession>),
      PracticeSession,
      PrefetchHooks Function()
    >;
typedef $$CareerAnswersTableCreateCompanionBuilder = CareerAnswersCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String sessionId,
  required int question,
  required String answer,
  required String at,
  Value<String> review,
  Value<double?> score,
  Value<int> rowid,
});
typedef $$CareerAnswersTableUpdateCompanionBuilder = CareerAnswersCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> sessionId,
  Value<int> question,
  Value<String> answer,
  Value<String> at,
  Value<String> review,
  Value<double?> score,
  Value<int> rowid,
});

class $$CareerAnswersTableFilterComposer extends Composer<_$AppDatabase, $CareerAnswersTable> {
  $$CareerAnswersTableFilterComposer({
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

  ColumnFilters<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get question =>
      $composableBuilder(column: $table.question, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get review =>
      $composableBuilder(column: $table.review, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => ColumnFilters(column));
}

class $$CareerAnswersTableOrderingComposer extends Composer<_$AppDatabase, $CareerAnswersTable> {
  $$CareerAnswersTableOrderingComposer({
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

  ColumnOrderings<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get question =>
      $composableBuilder(column: $table.question, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get review =>
      $composableBuilder(column: $table.review, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => ColumnOrderings(column));
}

class $$CareerAnswersTableAnnotationComposer extends Composer<_$AppDatabase, $CareerAnswersTable> {
  $$CareerAnswersTableAnnotationComposer({
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

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<int> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get review =>
      $composableBuilder(column: $table.review, builder: (column) => column);

  GeneratedColumn<double> get score => $composableBuilder(column: $table.score, builder: (column) => column);
}

class $$CareerAnswersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CareerAnswersTable,
          PracticeAnswer,
          $$CareerAnswersTableFilterComposer,
          $$CareerAnswersTableOrderingComposer,
          $$CareerAnswersTableAnnotationComposer,
          $$CareerAnswersTableCreateCompanionBuilder,
          $$CareerAnswersTableUpdateCompanionBuilder,
          (PracticeAnswer, BaseReferences<_$AppDatabase, $CareerAnswersTable, PracticeAnswer>),
          PracticeAnswer,
          PrefetchHooks Function()
        > {
  $$CareerAnswersTableTableManager(_$AppDatabase db, $CareerAnswersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CareerAnswersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CareerAnswersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CareerAnswersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<int> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> at = const Value.absent(),
                Value<String> review = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerAnswersCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                sessionId: sessionId,
                question: question,
                answer: answer,
                at: at,
                review: review,
                score: score,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String sessionId,
                required int question,
                required String answer,
                required String at,
                Value<String> review = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CareerAnswersCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                sessionId: sessionId,
                question: question,
                answer: answer,
                at: at,
                review: review,
                score: score,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CareerAnswersTable, PracticeAnswer>(table),
                  BaseReferences<_$AppDatabase, $CareerAnswersTable, PracticeAnswer>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CareerAnswersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CareerAnswersTable,
      PracticeAnswer,
      $$CareerAnswersTableFilterComposer,
      $$CareerAnswersTableOrderingComposer,
      $$CareerAnswersTableAnnotationComposer,
      $$CareerAnswersTableCreateCompanionBuilder,
      $$CareerAnswersTableUpdateCompanionBuilder,
      (PracticeAnswer, BaseReferences<_$AppDatabase, $CareerAnswersTable, PracticeAnswer>),
      PracticeAnswer,
      PrefetchHooks Function()
    >;
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
  $$JobListingsTableTableManager get jobListings => $$JobListingsTableTableManager(_db, _db.jobListings);
  $$JobApplicationsTableTableManager get jobApplications =>
      $$JobApplicationsTableTableManager(_db, _db.jobApplications);
  $$JobEventsTableTableManager get jobEvents => $$JobEventsTableTableManager(_db, _db.jobEvents);
  $$CareerContactsTableTableManager get careerContacts =>
      $$CareerContactsTableTableManager(_db, _db.careerContacts);
  $$CareerResumesTableTableManager get careerResumes =>
      $$CareerResumesTableTableManager(_db, _db.careerResumes);
  $$CareerReportsTableTableManager get careerReports =>
      $$CareerReportsTableTableManager(_db, _db.careerReports);
  $$CareerGrowthTableTableManager get careerGrowth => $$CareerGrowthTableTableManager(_db, _db.careerGrowth);
  $$CareerPracticeTableTableManager get careerPractice =>
      $$CareerPracticeTableTableManager(_db, _db.careerPractice);
  $$CareerAnswersTableTableManager get careerAnswers =>
      $$CareerAnswersTableTableManager(_db, _db.careerAnswers);
  $$PrefsTableTableManager get prefs => $$PrefsTableTableManager(_db, _db.prefs);
  $$OutboxTableTableManager get outbox => $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncCursorsTableTableManager get syncCursors => $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
}
