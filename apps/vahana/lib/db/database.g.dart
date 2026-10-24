// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $VehiclesTable extends Vehicles with TableInfo<$VehiclesTable, Vehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiclesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  @override
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
    'make',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mileageMeta = const VerificationMeta('mileage');
  @override
  late final GeneratedColumn<int> mileage = GeneratedColumn<int>(
    'mileage',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelMeta = const VerificationMeta('fuel');
  @override
  late final GeneratedColumn<String> fuel = GeneratedColumn<String>(
    'fuel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _transmissionMeta = const VerificationMeta('transmission');
  @override
  late final GeneratedColumn<String> transmission = GeneratedColumn<String>(
    'transmission',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _registrationMeta = const VerificationMeta('registration');
  @override
  late final GeneratedColumn<String> registration = GeneratedColumn<String>(
    'registration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _conditionMeta = const VerificationMeta('condition');
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
    'condition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('used'),
  );
  static const VerificationMeta _sellerTypeMeta = const VerificationMeta('sellerType');
  @override
  late final GeneratedColumn<String> sellerType = GeneratedColumn<String>(
    'seller_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _sellerMeta = const VerificationMeta('seller');
  @override
  late final GeneratedColumn<String> seller = GeneratedColumn<String>(
    'seller',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sellerPhoneMeta = const VerificationMeta('sellerPhone');
  @override
  late final GeneratedColumn<String> sellerPhone = GeneratedColumn<String>(
    'seller_phone',
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
  static const VerificationMeta _imageUrlMeta = const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('new'),
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<String> added = GeneratedColumn<String>(
    'added',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstRegisteredMeta = const VerificationMeta('firstRegistered');
  @override
  late final GeneratedColumn<String> firstRegistered = GeneratedColumn<String>(
    'first_registered',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _motDueMeta = const VerificationMeta('motDue');
  @override
  late final GeneratedColumn<String> motDue = GeneratedColumn<String>(
    'mot_due',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxDueMeta = const VerificationMeta('taxDue');
  @override
  late final GeneratedColumn<String> taxDue = GeneratedColumn<String>(
    'tax_due',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _insuranceDueMeta = const VerificationMeta('insuranceDue');
  @override
  late final GeneratedColumn<String> insuranceDue = GeneratedColumn<String>(
    'insurance_due',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serviceDueMeta = const VerificationMeta('serviceDue');
  @override
  late final GeneratedColumn<String> serviceDue = GeneratedColumn<String>(
    'service_due',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _boughtOnMeta = const VerificationMeta('boughtOn');
  @override
  late final GeneratedColumn<String> boughtOn = GeneratedColumn<String>(
    'bought_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soldOnMeta = const VerificationMeta('soldOn');
  @override
  late final GeneratedColumn<String> soldOn = GeneratedColumn<String>(
    'sold_on',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soldPriceMeta = const VerificationMeta('soldPrice');
  @override
  late final GeneratedColumn<int> soldPrice = GeneratedColumn<int>(
    'sold_price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaMeta = const VerificationMeta('meta');
  @override
  late final GeneratedColumn<String> meta = GeneratedColumn<String>(
    'meta',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hlc,
    deleted,
    title,
    make,
    model,
    year,
    mileage,
    price,
    fuel,
    transmission,
    body,
    registration,
    condition,
    sellerType,
    seller,
    sellerPhone,
    location,
    source,
    url,
    imageUrl,
    stage,
    rating,
    notes,
    added,
    firstRegistered,
    motDue,
    taxDue,
    insuranceDue,
    serviceDue,
    boughtOn,
    soldOn,
    soldPrice,
    meta,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehicles';
  @override
  VerificationContext validateIntegrity(Insertable<Vehicle> instance, {bool isInserting = false}) {
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
    if (data.containsKey('make')) {
      context.handle(_makeMeta, make.isAcceptableOrUnknown(data['make']!, _makeMeta));
    }
    if (data.containsKey('model')) {
      context.handle(_modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('year')) {
      context.handle(_yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('mileage')) {
      context.handle(_mileageMeta, mileage.isAcceptableOrUnknown(data['mileage']!, _mileageMeta));
    }
    if (data.containsKey('price')) {
      context.handle(_priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    }
    if (data.containsKey('fuel')) {
      context.handle(_fuelMeta, fuel.isAcceptableOrUnknown(data['fuel']!, _fuelMeta));
    }
    if (data.containsKey('transmission')) {
      context.handle(
        _transmissionMeta,
        transmission.isAcceptableOrUnknown(data['transmission']!, _transmissionMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    }
    if (data.containsKey('registration')) {
      context.handle(
        _registrationMeta,
        registration.isAcceptableOrUnknown(data['registration']!, _registrationMeta),
      );
    }
    if (data.containsKey('condition')) {
      context.handle(_conditionMeta, condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta));
    }
    if (data.containsKey('seller_type')) {
      context.handle(
        _sellerTypeMeta,
        sellerType.isAcceptableOrUnknown(data['seller_type']!, _sellerTypeMeta),
      );
    }
    if (data.containsKey('seller')) {
      context.handle(_sellerMeta, seller.isAcceptableOrUnknown(data['seller']!, _sellerMeta));
    }
    if (data.containsKey('seller_phone')) {
      context.handle(
        _sellerPhoneMeta,
        sellerPhone.isAcceptableOrUnknown(data['seller_phone']!, _sellerPhoneMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(_locationMeta, location.isAcceptableOrUnknown(data['location']!, _locationMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta, imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('stage')) {
      context.handle(_stageMeta, stage.isAcceptableOrUnknown(data['stage']!, _stageMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta, rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('added')) {
      context.handle(_addedMeta, added.isAcceptableOrUnknown(data['added']!, _addedMeta));
    } else if (isInserting) {
      context.missing(_addedMeta);
    }
    if (data.containsKey('first_registered')) {
      context.handle(
        _firstRegisteredMeta,
        firstRegistered.isAcceptableOrUnknown(data['first_registered']!, _firstRegisteredMeta),
      );
    }
    if (data.containsKey('mot_due')) {
      context.handle(_motDueMeta, motDue.isAcceptableOrUnknown(data['mot_due']!, _motDueMeta));
    }
    if (data.containsKey('tax_due')) {
      context.handle(_taxDueMeta, taxDue.isAcceptableOrUnknown(data['tax_due']!, _taxDueMeta));
    }
    if (data.containsKey('insurance_due')) {
      context.handle(
        _insuranceDueMeta,
        insuranceDue.isAcceptableOrUnknown(data['insurance_due']!, _insuranceDueMeta),
      );
    }
    if (data.containsKey('service_due')) {
      context.handle(
        _serviceDueMeta,
        serviceDue.isAcceptableOrUnknown(data['service_due']!, _serviceDueMeta),
      );
    }
    if (data.containsKey('bought_on')) {
      context.handle(_boughtOnMeta, boughtOn.isAcceptableOrUnknown(data['bought_on']!, _boughtOnMeta));
    }
    if (data.containsKey('sold_on')) {
      context.handle(_soldOnMeta, soldOn.isAcceptableOrUnknown(data['sold_on']!, _soldOnMeta));
    }
    if (data.containsKey('sold_price')) {
      context.handle(_soldPriceMeta, soldPrice.isAcceptableOrUnknown(data['sold_price']!, _soldPriceMeta));
    }
    if (data.containsKey('meta')) {
      context.handle(_metaMeta, meta.isAcceptableOrUnknown(data['meta']!, _metaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Vehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Vehicle(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      make: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}make'])!,
      model: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}model'])!,
      year: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}year']),
      mileage: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}mileage']),
      price: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}price']),
      fuel: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fuel'])!,
      transmission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transmission'],
      )!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      registration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registration'],
      )!,
      condition: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}condition'])!,
      sellerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seller_type'],
      )!,
      seller: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}seller'])!,
      sellerPhone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seller_phone'],
      )!,
      location: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}location'])!,
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      imageUrl: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      stage: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}stage'])!,
      rating: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}rating'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      added: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}added'])!,
      firstRegistered: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_registered'],
      ),
      motDue: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mot_due']),
      taxDue: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tax_due']),
      insuranceDue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insurance_due'],
      ),
      serviceDue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}service_due'],
      ),
      boughtOn: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}bought_on']),
      soldOn: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}sold_on']),
      soldPrice: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sold_price']),
      meta: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}meta'])!,
    );
  }

  @override
  $VehiclesTable createAlias(String alias) {
    return $VehiclesTable(attachedDatabase, alias);
  }
}

class Vehicle extends DataClass implements Insertable<Vehicle> {
  final String id;
  final String hlc;
  final bool deleted;

  /// What the advert calls it ("2019 Ford Focus 1.0 EcoBoost Titanium").
  final String title;
  final String make;
  final String model;
  final int? year;
  final int? mileage;
  final int? price;
  final String fuel;
  final String transmission;
  final String body;
  final String registration;

  /// used | new
  final String condition;

  /// dealer | private | store (an online car shop) | unknown
  final String sellerType;
  final String seller;
  final String sellerPhone;
  final String location;

  /// The site's id (autotrader, gumtree...) or its host; with the link.
  final String source;
  final String url;
  final String? imageUrl;

  /// Same steps as a property hunt (domain/pipeline.dart), read for cars.
  final String stage;
  final int rating;
  final String notes;
  final String added;

  /// Owning it (yyyy-MM-dd): first registered (sets the first MOT), the
  /// dates things fall due, and when it was bought and sold.
  final String? firstRegistered;
  final String? motDue;
  final String? taxDue;
  final String? insuranceDue;
  final String? serviceDue;
  final String? boughtOn;
  final String? soldOn;
  final int? soldPrice;

  /// JSON extras: description, colour, price history, checklists ticked,
  /// a PCP's mileage allowance.
  final String meta;
  const Vehicle({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.title,
    required this.make,
    required this.model,
    this.year,
    this.mileage,
    this.price,
    required this.fuel,
    required this.transmission,
    required this.body,
    required this.registration,
    required this.condition,
    required this.sellerType,
    required this.seller,
    required this.sellerPhone,
    required this.location,
    required this.source,
    required this.url,
    this.imageUrl,
    required this.stage,
    required this.rating,
    required this.notes,
    required this.added,
    this.firstRegistered,
    this.motDue,
    this.taxDue,
    this.insuranceDue,
    this.serviceDue,
    this.boughtOn,
    this.soldOn,
    this.soldPrice,
    required this.meta,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['title'] = Variable<String>(title);
    map['make'] = Variable<String>(make);
    map['model'] = Variable<String>(model);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || mileage != null) {
      map['mileage'] = Variable<int>(mileage);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    map['fuel'] = Variable<String>(fuel);
    map['transmission'] = Variable<String>(transmission);
    map['body'] = Variable<String>(body);
    map['registration'] = Variable<String>(registration);
    map['condition'] = Variable<String>(condition);
    map['seller_type'] = Variable<String>(sellerType);
    map['seller'] = Variable<String>(seller);
    map['seller_phone'] = Variable<String>(sellerPhone);
    map['location'] = Variable<String>(location);
    map['source'] = Variable<String>(source);
    map['url'] = Variable<String>(url);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['stage'] = Variable<String>(stage);
    map['rating'] = Variable<int>(rating);
    map['notes'] = Variable<String>(notes);
    map['added'] = Variable<String>(added);
    if (!nullToAbsent || firstRegistered != null) {
      map['first_registered'] = Variable<String>(firstRegistered);
    }
    if (!nullToAbsent || motDue != null) {
      map['mot_due'] = Variable<String>(motDue);
    }
    if (!nullToAbsent || taxDue != null) {
      map['tax_due'] = Variable<String>(taxDue);
    }
    if (!nullToAbsent || insuranceDue != null) {
      map['insurance_due'] = Variable<String>(insuranceDue);
    }
    if (!nullToAbsent || serviceDue != null) {
      map['service_due'] = Variable<String>(serviceDue);
    }
    if (!nullToAbsent || boughtOn != null) {
      map['bought_on'] = Variable<String>(boughtOn);
    }
    if (!nullToAbsent || soldOn != null) {
      map['sold_on'] = Variable<String>(soldOn);
    }
    if (!nullToAbsent || soldPrice != null) {
      map['sold_price'] = Variable<int>(soldPrice);
    }
    map['meta'] = Variable<String>(meta);
    return map;
  }

  VehiclesCompanion toCompanion(bool nullToAbsent) {
    return VehiclesCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      title: Value(title),
      make: Value(make),
      model: Value(model),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      mileage: mileage == null && nullToAbsent ? const Value.absent() : Value(mileage),
      price: price == null && nullToAbsent ? const Value.absent() : Value(price),
      fuel: Value(fuel),
      transmission: Value(transmission),
      body: Value(body),
      registration: Value(registration),
      condition: Value(condition),
      sellerType: Value(sellerType),
      seller: Value(seller),
      sellerPhone: Value(sellerPhone),
      location: Value(location),
      source: Value(source),
      url: Value(url),
      imageUrl: imageUrl == null && nullToAbsent ? const Value.absent() : Value(imageUrl),
      stage: Value(stage),
      rating: Value(rating),
      notes: Value(notes),
      added: Value(added),
      firstRegistered: firstRegistered == null && nullToAbsent
          ? const Value.absent()
          : Value(firstRegistered),
      motDue: motDue == null && nullToAbsent ? const Value.absent() : Value(motDue),
      taxDue: taxDue == null && nullToAbsent ? const Value.absent() : Value(taxDue),
      insuranceDue: insuranceDue == null && nullToAbsent ? const Value.absent() : Value(insuranceDue),
      serviceDue: serviceDue == null && nullToAbsent ? const Value.absent() : Value(serviceDue),
      boughtOn: boughtOn == null && nullToAbsent ? const Value.absent() : Value(boughtOn),
      soldOn: soldOn == null && nullToAbsent ? const Value.absent() : Value(soldOn),
      soldPrice: soldPrice == null && nullToAbsent ? const Value.absent() : Value(soldPrice),
      meta: Value(meta),
    );
  }

  factory Vehicle.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Vehicle(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      title: serializer.fromJson<String>(json['title']),
      make: serializer.fromJson<String>(json['make']),
      model: serializer.fromJson<String>(json['model']),
      year: serializer.fromJson<int?>(json['year']),
      mileage: serializer.fromJson<int?>(json['mileage']),
      price: serializer.fromJson<int?>(json['price']),
      fuel: serializer.fromJson<String>(json['fuel']),
      transmission: serializer.fromJson<String>(json['transmission']),
      body: serializer.fromJson<String>(json['body']),
      registration: serializer.fromJson<String>(json['registration']),
      condition: serializer.fromJson<String>(json['condition']),
      sellerType: serializer.fromJson<String>(json['sellerType']),
      seller: serializer.fromJson<String>(json['seller']),
      sellerPhone: serializer.fromJson<String>(json['sellerPhone']),
      location: serializer.fromJson<String>(json['location']),
      source: serializer.fromJson<String>(json['source']),
      url: serializer.fromJson<String>(json['url']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      stage: serializer.fromJson<String>(json['stage']),
      rating: serializer.fromJson<int>(json['rating']),
      notes: serializer.fromJson<String>(json['notes']),
      added: serializer.fromJson<String>(json['added']),
      firstRegistered: serializer.fromJson<String?>(json['firstRegistered']),
      motDue: serializer.fromJson<String?>(json['motDue']),
      taxDue: serializer.fromJson<String?>(json['taxDue']),
      insuranceDue: serializer.fromJson<String?>(json['insuranceDue']),
      serviceDue: serializer.fromJson<String?>(json['serviceDue']),
      boughtOn: serializer.fromJson<String?>(json['boughtOn']),
      soldOn: serializer.fromJson<String?>(json['soldOn']),
      soldPrice: serializer.fromJson<int?>(json['soldPrice']),
      meta: serializer.fromJson<String>(json['meta']),
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
      'make': serializer.toJson<String>(make),
      'model': serializer.toJson<String>(model),
      'year': serializer.toJson<int?>(year),
      'mileage': serializer.toJson<int?>(mileage),
      'price': serializer.toJson<int?>(price),
      'fuel': serializer.toJson<String>(fuel),
      'transmission': serializer.toJson<String>(transmission),
      'body': serializer.toJson<String>(body),
      'registration': serializer.toJson<String>(registration),
      'condition': serializer.toJson<String>(condition),
      'sellerType': serializer.toJson<String>(sellerType),
      'seller': serializer.toJson<String>(seller),
      'sellerPhone': serializer.toJson<String>(sellerPhone),
      'location': serializer.toJson<String>(location),
      'source': serializer.toJson<String>(source),
      'url': serializer.toJson<String>(url),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'stage': serializer.toJson<String>(stage),
      'rating': serializer.toJson<int>(rating),
      'notes': serializer.toJson<String>(notes),
      'added': serializer.toJson<String>(added),
      'firstRegistered': serializer.toJson<String?>(firstRegistered),
      'motDue': serializer.toJson<String?>(motDue),
      'taxDue': serializer.toJson<String?>(taxDue),
      'insuranceDue': serializer.toJson<String?>(insuranceDue),
      'serviceDue': serializer.toJson<String?>(serviceDue),
      'boughtOn': serializer.toJson<String?>(boughtOn),
      'soldOn': serializer.toJson<String?>(soldOn),
      'soldPrice': serializer.toJson<int?>(soldPrice),
      'meta': serializer.toJson<String>(meta),
    };
  }

  Vehicle copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? title,
    String? make,
    String? model,
    Value<int?> year = const Value.absent(),
    Value<int?> mileage = const Value.absent(),
    Value<int?> price = const Value.absent(),
    String? fuel,
    String? transmission,
    String? body,
    String? registration,
    String? condition,
    String? sellerType,
    String? seller,
    String? sellerPhone,
    String? location,
    String? source,
    String? url,
    Value<String?> imageUrl = const Value.absent(),
    String? stage,
    int? rating,
    String? notes,
    String? added,
    Value<String?> firstRegistered = const Value.absent(),
    Value<String?> motDue = const Value.absent(),
    Value<String?> taxDue = const Value.absent(),
    Value<String?> insuranceDue = const Value.absent(),
    Value<String?> serviceDue = const Value.absent(),
    Value<String?> boughtOn = const Value.absent(),
    Value<String?> soldOn = const Value.absent(),
    Value<int?> soldPrice = const Value.absent(),
    String? meta,
  }) => Vehicle(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    title: title ?? this.title,
    make: make ?? this.make,
    model: model ?? this.model,
    year: year.present ? year.value : this.year,
    mileage: mileage.present ? mileage.value : this.mileage,
    price: price.present ? price.value : this.price,
    fuel: fuel ?? this.fuel,
    transmission: transmission ?? this.transmission,
    body: body ?? this.body,
    registration: registration ?? this.registration,
    condition: condition ?? this.condition,
    sellerType: sellerType ?? this.sellerType,
    seller: seller ?? this.seller,
    sellerPhone: sellerPhone ?? this.sellerPhone,
    location: location ?? this.location,
    source: source ?? this.source,
    url: url ?? this.url,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    stage: stage ?? this.stage,
    rating: rating ?? this.rating,
    notes: notes ?? this.notes,
    added: added ?? this.added,
    firstRegistered: firstRegistered.present ? firstRegistered.value : this.firstRegistered,
    motDue: motDue.present ? motDue.value : this.motDue,
    taxDue: taxDue.present ? taxDue.value : this.taxDue,
    insuranceDue: insuranceDue.present ? insuranceDue.value : this.insuranceDue,
    serviceDue: serviceDue.present ? serviceDue.value : this.serviceDue,
    boughtOn: boughtOn.present ? boughtOn.value : this.boughtOn,
    soldOn: soldOn.present ? soldOn.value : this.soldOn,
    soldPrice: soldPrice.present ? soldPrice.value : this.soldPrice,
    meta: meta ?? this.meta,
  );
  Vehicle copyWithCompanion(VehiclesCompanion data) {
    return Vehicle(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      title: data.title.present ? data.title.value : this.title,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      year: data.year.present ? data.year.value : this.year,
      mileage: data.mileage.present ? data.mileage.value : this.mileage,
      price: data.price.present ? data.price.value : this.price,
      fuel: data.fuel.present ? data.fuel.value : this.fuel,
      transmission: data.transmission.present ? data.transmission.value : this.transmission,
      body: data.body.present ? data.body.value : this.body,
      registration: data.registration.present ? data.registration.value : this.registration,
      condition: data.condition.present ? data.condition.value : this.condition,
      sellerType: data.sellerType.present ? data.sellerType.value : this.sellerType,
      seller: data.seller.present ? data.seller.value : this.seller,
      sellerPhone: data.sellerPhone.present ? data.sellerPhone.value : this.sellerPhone,
      location: data.location.present ? data.location.value : this.location,
      source: data.source.present ? data.source.value : this.source,
      url: data.url.present ? data.url.value : this.url,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      stage: data.stage.present ? data.stage.value : this.stage,
      rating: data.rating.present ? data.rating.value : this.rating,
      notes: data.notes.present ? data.notes.value : this.notes,
      added: data.added.present ? data.added.value : this.added,
      firstRegistered: data.firstRegistered.present ? data.firstRegistered.value : this.firstRegistered,
      motDue: data.motDue.present ? data.motDue.value : this.motDue,
      taxDue: data.taxDue.present ? data.taxDue.value : this.taxDue,
      insuranceDue: data.insuranceDue.present ? data.insuranceDue.value : this.insuranceDue,
      serviceDue: data.serviceDue.present ? data.serviceDue.value : this.serviceDue,
      boughtOn: data.boughtOn.present ? data.boughtOn.value : this.boughtOn,
      soldOn: data.soldOn.present ? data.soldOn.value : this.soldOn,
      soldPrice: data.soldPrice.present ? data.soldPrice.value : this.soldPrice,
      meta: data.meta.present ? data.meta.value : this.meta,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Vehicle(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('title: $title, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('mileage: $mileage, ')
          ..write('price: $price, ')
          ..write('fuel: $fuel, ')
          ..write('transmission: $transmission, ')
          ..write('body: $body, ')
          ..write('registration: $registration, ')
          ..write('condition: $condition, ')
          ..write('sellerType: $sellerType, ')
          ..write('seller: $seller, ')
          ..write('sellerPhone: $sellerPhone, ')
          ..write('location: $location, ')
          ..write('source: $source, ')
          ..write('url: $url, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('stage: $stage, ')
          ..write('rating: $rating, ')
          ..write('notes: $notes, ')
          ..write('added: $added, ')
          ..write('firstRegistered: $firstRegistered, ')
          ..write('motDue: $motDue, ')
          ..write('taxDue: $taxDue, ')
          ..write('insuranceDue: $insuranceDue, ')
          ..write('serviceDue: $serviceDue, ')
          ..write('boughtOn: $boughtOn, ')
          ..write('soldOn: $soldOn, ')
          ..write('soldPrice: $soldPrice, ')
          ..write('meta: $meta')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    hlc,
    deleted,
    title,
    make,
    model,
    year,
    mileage,
    price,
    fuel,
    transmission,
    body,
    registration,
    condition,
    sellerType,
    seller,
    sellerPhone,
    location,
    source,
    url,
    imageUrl,
    stage,
    rating,
    notes,
    added,
    firstRegistered,
    motDue,
    taxDue,
    insuranceDue,
    serviceDue,
    boughtOn,
    soldOn,
    soldPrice,
    meta,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Vehicle &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.title == this.title &&
          other.make == this.make &&
          other.model == this.model &&
          other.year == this.year &&
          other.mileage == this.mileage &&
          other.price == this.price &&
          other.fuel == this.fuel &&
          other.transmission == this.transmission &&
          other.body == this.body &&
          other.registration == this.registration &&
          other.condition == this.condition &&
          other.sellerType == this.sellerType &&
          other.seller == this.seller &&
          other.sellerPhone == this.sellerPhone &&
          other.location == this.location &&
          other.source == this.source &&
          other.url == this.url &&
          other.imageUrl == this.imageUrl &&
          other.stage == this.stage &&
          other.rating == this.rating &&
          other.notes == this.notes &&
          other.added == this.added &&
          other.firstRegistered == this.firstRegistered &&
          other.motDue == this.motDue &&
          other.taxDue == this.taxDue &&
          other.insuranceDue == this.insuranceDue &&
          other.serviceDue == this.serviceDue &&
          other.boughtOn == this.boughtOn &&
          other.soldOn == this.soldOn &&
          other.soldPrice == this.soldPrice &&
          other.meta == this.meta);
}

class VehiclesCompanion extends UpdateCompanion<Vehicle> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> title;
  final Value<String> make;
  final Value<String> model;
  final Value<int?> year;
  final Value<int?> mileage;
  final Value<int?> price;
  final Value<String> fuel;
  final Value<String> transmission;
  final Value<String> body;
  final Value<String> registration;
  final Value<String> condition;
  final Value<String> sellerType;
  final Value<String> seller;
  final Value<String> sellerPhone;
  final Value<String> location;
  final Value<String> source;
  final Value<String> url;
  final Value<String?> imageUrl;
  final Value<String> stage;
  final Value<int> rating;
  final Value<String> notes;
  final Value<String> added;
  final Value<String?> firstRegistered;
  final Value<String?> motDue;
  final Value<String?> taxDue;
  final Value<String?> insuranceDue;
  final Value<String?> serviceDue;
  final Value<String?> boughtOn;
  final Value<String?> soldOn;
  final Value<int?> soldPrice;
  final Value<String> meta;
  final Value<int> rowid;
  const VehiclesCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.title = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.mileage = const Value.absent(),
    this.price = const Value.absent(),
    this.fuel = const Value.absent(),
    this.transmission = const Value.absent(),
    this.body = const Value.absent(),
    this.registration = const Value.absent(),
    this.condition = const Value.absent(),
    this.sellerType = const Value.absent(),
    this.seller = const Value.absent(),
    this.sellerPhone = const Value.absent(),
    this.location = const Value.absent(),
    this.source = const Value.absent(),
    this.url = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.stage = const Value.absent(),
    this.rating = const Value.absent(),
    this.notes = const Value.absent(),
    this.added = const Value.absent(),
    this.firstRegistered = const Value.absent(),
    this.motDue = const Value.absent(),
    this.taxDue = const Value.absent(),
    this.insuranceDue = const Value.absent(),
    this.serviceDue = const Value.absent(),
    this.boughtOn = const Value.absent(),
    this.soldOn = const Value.absent(),
    this.soldPrice = const Value.absent(),
    this.meta = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiclesCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String title,
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.year = const Value.absent(),
    this.mileage = const Value.absent(),
    this.price = const Value.absent(),
    this.fuel = const Value.absent(),
    this.transmission = const Value.absent(),
    this.body = const Value.absent(),
    this.registration = const Value.absent(),
    this.condition = const Value.absent(),
    this.sellerType = const Value.absent(),
    this.seller = const Value.absent(),
    this.sellerPhone = const Value.absent(),
    this.location = const Value.absent(),
    this.source = const Value.absent(),
    this.url = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.stage = const Value.absent(),
    this.rating = const Value.absent(),
    this.notes = const Value.absent(),
    required String added,
    this.firstRegistered = const Value.absent(),
    this.motDue = const Value.absent(),
    this.taxDue = const Value.absent(),
    this.insuranceDue = const Value.absent(),
    this.serviceDue = const Value.absent(),
    this.boughtOn = const Value.absent(),
    this.soldOn = const Value.absent(),
    this.soldPrice = const Value.absent(),
    this.meta = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       added = Value(added);
  static Insertable<Vehicle> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? title,
    Expression<String>? make,
    Expression<String>? model,
    Expression<int>? year,
    Expression<int>? mileage,
    Expression<int>? price,
    Expression<String>? fuel,
    Expression<String>? transmission,
    Expression<String>? body,
    Expression<String>? registration,
    Expression<String>? condition,
    Expression<String>? sellerType,
    Expression<String>? seller,
    Expression<String>? sellerPhone,
    Expression<String>? location,
    Expression<String>? source,
    Expression<String>? url,
    Expression<String>? imageUrl,
    Expression<String>? stage,
    Expression<int>? rating,
    Expression<String>? notes,
    Expression<String>? added,
    Expression<String>? firstRegistered,
    Expression<String>? motDue,
    Expression<String>? taxDue,
    Expression<String>? insuranceDue,
    Expression<String>? serviceDue,
    Expression<String>? boughtOn,
    Expression<String>? soldOn,
    Expression<int>? soldPrice,
    Expression<String>? meta,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (title != null) 'title': title,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (year != null) 'year': year,
      if (mileage != null) 'mileage': mileage,
      if (price != null) 'price': price,
      if (fuel != null) 'fuel': fuel,
      if (transmission != null) 'transmission': transmission,
      if (body != null) 'body': body,
      if (registration != null) 'registration': registration,
      if (condition != null) 'condition': condition,
      if (sellerType != null) 'seller_type': sellerType,
      if (seller != null) 'seller': seller,
      if (sellerPhone != null) 'seller_phone': sellerPhone,
      if (location != null) 'location': location,
      if (source != null) 'source': source,
      if (url != null) 'url': url,
      if (imageUrl != null) 'image_url': imageUrl,
      if (stage != null) 'stage': stage,
      if (rating != null) 'rating': rating,
      if (notes != null) 'notes': notes,
      if (added != null) 'added': added,
      if (firstRegistered != null) 'first_registered': firstRegistered,
      if (motDue != null) 'mot_due': motDue,
      if (taxDue != null) 'tax_due': taxDue,
      if (insuranceDue != null) 'insurance_due': insuranceDue,
      if (serviceDue != null) 'service_due': serviceDue,
      if (boughtOn != null) 'bought_on': boughtOn,
      if (soldOn != null) 'sold_on': soldOn,
      if (soldPrice != null) 'sold_price': soldPrice,
      if (meta != null) 'meta': meta,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiclesCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? title,
    Value<String>? make,
    Value<String>? model,
    Value<int?>? year,
    Value<int?>? mileage,
    Value<int?>? price,
    Value<String>? fuel,
    Value<String>? transmission,
    Value<String>? body,
    Value<String>? registration,
    Value<String>? condition,
    Value<String>? sellerType,
    Value<String>? seller,
    Value<String>? sellerPhone,
    Value<String>? location,
    Value<String>? source,
    Value<String>? url,
    Value<String?>? imageUrl,
    Value<String>? stage,
    Value<int>? rating,
    Value<String>? notes,
    Value<String>? added,
    Value<String?>? firstRegistered,
    Value<String?>? motDue,
    Value<String?>? taxDue,
    Value<String?>? insuranceDue,
    Value<String?>? serviceDue,
    Value<String?>? boughtOn,
    Value<String?>? soldOn,
    Value<int?>? soldPrice,
    Value<String>? meta,
    Value<int>? rowid,
  }) {
    return VehiclesCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      title: title ?? this.title,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      mileage: mileage ?? this.mileage,
      price: price ?? this.price,
      fuel: fuel ?? this.fuel,
      transmission: transmission ?? this.transmission,
      body: body ?? this.body,
      registration: registration ?? this.registration,
      condition: condition ?? this.condition,
      sellerType: sellerType ?? this.sellerType,
      seller: seller ?? this.seller,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      location: location ?? this.location,
      source: source ?? this.source,
      url: url ?? this.url,
      imageUrl: imageUrl ?? this.imageUrl,
      stage: stage ?? this.stage,
      rating: rating ?? this.rating,
      notes: notes ?? this.notes,
      added: added ?? this.added,
      firstRegistered: firstRegistered ?? this.firstRegistered,
      motDue: motDue ?? this.motDue,
      taxDue: taxDue ?? this.taxDue,
      insuranceDue: insuranceDue ?? this.insuranceDue,
      serviceDue: serviceDue ?? this.serviceDue,
      boughtOn: boughtOn ?? this.boughtOn,
      soldOn: soldOn ?? this.soldOn,
      soldPrice: soldPrice ?? this.soldPrice,
      meta: meta ?? this.meta,
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
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (mileage.present) {
      map['mileage'] = Variable<int>(mileage.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (fuel.present) {
      map['fuel'] = Variable<String>(fuel.value);
    }
    if (transmission.present) {
      map['transmission'] = Variable<String>(transmission.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (registration.present) {
      map['registration'] = Variable<String>(registration.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (sellerType.present) {
      map['seller_type'] = Variable<String>(sellerType.value);
    }
    if (seller.present) {
      map['seller'] = Variable<String>(seller.value);
    }
    if (sellerPhone.present) {
      map['seller_phone'] = Variable<String>(sellerPhone.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (added.present) {
      map['added'] = Variable<String>(added.value);
    }
    if (firstRegistered.present) {
      map['first_registered'] = Variable<String>(firstRegistered.value);
    }
    if (motDue.present) {
      map['mot_due'] = Variable<String>(motDue.value);
    }
    if (taxDue.present) {
      map['tax_due'] = Variable<String>(taxDue.value);
    }
    if (insuranceDue.present) {
      map['insurance_due'] = Variable<String>(insuranceDue.value);
    }
    if (serviceDue.present) {
      map['service_due'] = Variable<String>(serviceDue.value);
    }
    if (boughtOn.present) {
      map['bought_on'] = Variable<String>(boughtOn.value);
    }
    if (soldOn.present) {
      map['sold_on'] = Variable<String>(soldOn.value);
    }
    if (soldPrice.present) {
      map['sold_price'] = Variable<int>(soldPrice.value);
    }
    if (meta.present) {
      map['meta'] = Variable<String>(meta.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiclesCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('title: $title, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('year: $year, ')
          ..write('mileage: $mileage, ')
          ..write('price: $price, ')
          ..write('fuel: $fuel, ')
          ..write('transmission: $transmission, ')
          ..write('body: $body, ')
          ..write('registration: $registration, ')
          ..write('condition: $condition, ')
          ..write('sellerType: $sellerType, ')
          ..write('seller: $seller, ')
          ..write('sellerPhone: $sellerPhone, ')
          ..write('location: $location, ')
          ..write('source: $source, ')
          ..write('url: $url, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('stage: $stage, ')
          ..write('rating: $rating, ')
          ..write('notes: $notes, ')
          ..write('added: $added, ')
          ..write('firstRegistered: $firstRegistered, ')
          ..write('motDue: $motDue, ')
          ..write('taxDue: $taxDue, ')
          ..write('insuranceDue: $insuranceDue, ')
          ..write('serviceDue: $serviceDue, ')
          ..write('boughtOn: $boughtOn, ')
          ..write('soldOn: $soldOn, ')
          ..write('soldPrice: $soldPrice, ')
          ..write('meta: $meta, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CarLogsTable extends CarLogs with TableInfo<$CarLogsTable, CarLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CarLogsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _vehicleIdMeta = const VerificationMeta('vehicleId');
  @override
  late final GeneratedColumn<String> vehicleId = GeneratedColumn<String>(
    'vehicle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
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
  static const VerificationMeta _odometerMeta = const VerificationMeta('odometer');
  @override
  late final GeneratedColumn<int> odometer = GeneratedColumn<int>(
    'odometer',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costPenceMeta = const VerificationMeta('costPence');
  @override
  late final GeneratedColumn<int> costPence = GeneratedColumn<int>(
    'cost_pence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
    vehicleId,
    date,
    kind,
    odometer,
    costPence,
    amount,
    provider,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'car_logs';
  @override
  VerificationContext validateIntegrity(Insertable<CarLog> instance, {bool isInserting = false}) {
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
    if (data.containsKey('vehicle_id')) {
      context.handle(_vehicleIdMeta, vehicleId.isAcceptableOrUnknown(data['vehicle_id']!, _vehicleIdMeta));
    } else if (isInserting) {
      context.missing(_vehicleIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('odometer')) {
      context.handle(_odometerMeta, odometer.isAcceptableOrUnknown(data['odometer']!, _odometerMeta));
    }
    if (data.containsKey('cost_pence')) {
      context.handle(_costPenceMeta, costPence.isAcceptableOrUnknown(data['cost_pence']!, _costPenceMeta));
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta, amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    }
    if (data.containsKey('provider')) {
      context.handle(_providerMeta, provider.isAcceptableOrUnknown(data['provider']!, _providerMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CarLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CarLog(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      vehicleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_id'],
      )!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      odometer: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}odometer']),
      costPence: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}cost_pence']),
      amount: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}amount']),
      provider: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}provider'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
    );
  }

  @override
  $CarLogsTable createAlias(String alias) {
    return $CarLogsTable(attachedDatabase, alias);
  }
}

class CarLog extends DataClass implements Insertable<CarLog> {
  final String id;
  final String hlc;
  final bool deleted;
  final String vehicleId;
  final String date;

  /// See domain/car_owning.dart (LogKind).
  final String kind;
  final int? odometer;
  final int? costPence;

  /// Litres, kWh, or tread depth in mm, by kind.
  final double? amount;

  /// The garage, insurer or buyer.
  final String provider;
  final String notes;
  const CarLog({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.vehicleId,
    required this.date,
    required this.kind,
    this.odometer,
    this.costPence,
    this.amount,
    required this.provider,
    required this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['vehicle_id'] = Variable<String>(vehicleId);
    map['date'] = Variable<String>(date);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || odometer != null) {
      map['odometer'] = Variable<int>(odometer);
    }
    if (!nullToAbsent || costPence != null) {
      map['cost_pence'] = Variable<int>(costPence);
    }
    if (!nullToAbsent || amount != null) {
      map['amount'] = Variable<double>(amount);
    }
    map['provider'] = Variable<String>(provider);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  CarLogsCompanion toCompanion(bool nullToAbsent) {
    return CarLogsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      vehicleId: Value(vehicleId),
      date: Value(date),
      kind: Value(kind),
      odometer: odometer == null && nullToAbsent ? const Value.absent() : Value(odometer),
      costPence: costPence == null && nullToAbsent ? const Value.absent() : Value(costPence),
      amount: amount == null && nullToAbsent ? const Value.absent() : Value(amount),
      provider: Value(provider),
      notes: Value(notes),
    );
  }

  factory CarLog.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CarLog(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      vehicleId: serializer.fromJson<String>(json['vehicleId']),
      date: serializer.fromJson<String>(json['date']),
      kind: serializer.fromJson<String>(json['kind']),
      odometer: serializer.fromJson<int?>(json['odometer']),
      costPence: serializer.fromJson<int?>(json['costPence']),
      amount: serializer.fromJson<double?>(json['amount']),
      provider: serializer.fromJson<String>(json['provider']),
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
      'vehicleId': serializer.toJson<String>(vehicleId),
      'date': serializer.toJson<String>(date),
      'kind': serializer.toJson<String>(kind),
      'odometer': serializer.toJson<int?>(odometer),
      'costPence': serializer.toJson<int?>(costPence),
      'amount': serializer.toJson<double?>(amount),
      'provider': serializer.toJson<String>(provider),
      'notes': serializer.toJson<String>(notes),
    };
  }

  CarLog copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? vehicleId,
    String? date,
    String? kind,
    Value<int?> odometer = const Value.absent(),
    Value<int?> costPence = const Value.absent(),
    Value<double?> amount = const Value.absent(),
    String? provider,
    String? notes,
  }) => CarLog(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    vehicleId: vehicleId ?? this.vehicleId,
    date: date ?? this.date,
    kind: kind ?? this.kind,
    odometer: odometer.present ? odometer.value : this.odometer,
    costPence: costPence.present ? costPence.value : this.costPence,
    amount: amount.present ? amount.value : this.amount,
    provider: provider ?? this.provider,
    notes: notes ?? this.notes,
  );
  CarLog copyWithCompanion(CarLogsCompanion data) {
    return CarLog(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      vehicleId: data.vehicleId.present ? data.vehicleId.value : this.vehicleId,
      date: data.date.present ? data.date.value : this.date,
      kind: data.kind.present ? data.kind.value : this.kind,
      odometer: data.odometer.present ? data.odometer.value : this.odometer,
      costPence: data.costPence.present ? data.costPence.value : this.costPence,
      amount: data.amount.present ? data.amount.value : this.amount,
      provider: data.provider.present ? data.provider.value : this.provider,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CarLog(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('odometer: $odometer, ')
          ..write('costPence: $costPence, ')
          ..write('amount: $amount, ')
          ..write('provider: $provider, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, hlc, deleted, vehicleId, date, kind, odometer, costPence, amount, provider, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CarLog &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.vehicleId == this.vehicleId &&
          other.date == this.date &&
          other.kind == this.kind &&
          other.odometer == this.odometer &&
          other.costPence == this.costPence &&
          other.amount == this.amount &&
          other.provider == this.provider &&
          other.notes == this.notes);
}

class CarLogsCompanion extends UpdateCompanion<CarLog> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> vehicleId;
  final Value<String> date;
  final Value<String> kind;
  final Value<int?> odometer;
  final Value<int?> costPence;
  final Value<double?> amount;
  final Value<String> provider;
  final Value<String> notes;
  final Value<int> rowid;
  const CarLogsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.vehicleId = const Value.absent(),
    this.date = const Value.absent(),
    this.kind = const Value.absent(),
    this.odometer = const Value.absent(),
    this.costPence = const Value.absent(),
    this.amount = const Value.absent(),
    this.provider = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CarLogsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String vehicleId,
    required String date,
    required String kind,
    this.odometer = const Value.absent(),
    this.costPence = const Value.absent(),
    this.amount = const Value.absent(),
    this.provider = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehicleId = Value(vehicleId),
       date = Value(date),
       kind = Value(kind);
  static Insertable<CarLog> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? vehicleId,
    Expression<String>? date,
    Expression<String>? kind,
    Expression<int>? odometer,
    Expression<int>? costPence,
    Expression<double>? amount,
    Expression<String>? provider,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (date != null) 'date': date,
      if (kind != null) 'kind': kind,
      if (odometer != null) 'odometer': odometer,
      if (costPence != null) 'cost_pence': costPence,
      if (amount != null) 'amount': amount,
      if (provider != null) 'provider': provider,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CarLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? vehicleId,
    Value<String>? date,
    Value<String>? kind,
    Value<int?>? odometer,
    Value<int?>? costPence,
    Value<double?>? amount,
    Value<String>? provider,
    Value<String>? notes,
    Value<int>? rowid,
  }) {
    return CarLogsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      vehicleId: vehicleId ?? this.vehicleId,
      date: date ?? this.date,
      kind: kind ?? this.kind,
      odometer: odometer ?? this.odometer,
      costPence: costPence ?? this.costPence,
      amount: amount ?? this.amount,
      provider: provider ?? this.provider,
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
    if (vehicleId.present) {
      map['vehicle_id'] = Variable<String>(vehicleId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (odometer.present) {
      map['odometer'] = Variable<int>(odometer.value);
    }
    if (costPence.present) {
      map['cost_pence'] = Variable<int>(costPence.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
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
    return (StringBuffer('CarLogsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('vehicleId: $vehicleId, ')
          ..write('date: $date, ')
          ..write('kind: $kind, ')
          ..write('odometer: $odometer, ')
          ..write('costPence: $costPence, ')
          ..write('amount: $amount, ')
          ..write('provider: $provider, ')
          ..write('notes: $notes, ')
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
  late final $VehiclesTable vehicles = $VehiclesTable(this);
  late final $CarLogsTable carLogs = $CarLogsTable(this);
  late final $PrefsTable prefs = $PrefsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vehicles,
    carLogs,
    prefs,
    outbox,
    syncCursors,
    localSettings,
  ];
}

typedef $$VehiclesTableCreateCompanionBuilder = VehiclesCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String title,
  Value<String> make,
  Value<String> model,
  Value<int?> year,
  Value<int?> mileage,
  Value<int?> price,
  Value<String> fuel,
  Value<String> transmission,
  Value<String> body,
  Value<String> registration,
  Value<String> condition,
  Value<String> sellerType,
  Value<String> seller,
  Value<String> sellerPhone,
  Value<String> location,
  Value<String> source,
  Value<String> url,
  Value<String?> imageUrl,
  Value<String> stage,
  Value<int> rating,
  Value<String> notes,
  required String added,
  Value<String?> firstRegistered,
  Value<String?> motDue,
  Value<String?> taxDue,
  Value<String?> insuranceDue,
  Value<String?> serviceDue,
  Value<String?> boughtOn,
  Value<String?> soldOn,
  Value<int?> soldPrice,
  Value<String> meta,
  Value<int> rowid,
});
typedef $$VehiclesTableUpdateCompanionBuilder = VehiclesCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> title,
  Value<String> make,
  Value<String> model,
  Value<int?> year,
  Value<int?> mileage,
  Value<int?> price,
  Value<String> fuel,
  Value<String> transmission,
  Value<String> body,
  Value<String> registration,
  Value<String> condition,
  Value<String> sellerType,
  Value<String> seller,
  Value<String> sellerPhone,
  Value<String> location,
  Value<String> source,
  Value<String> url,
  Value<String?> imageUrl,
  Value<String> stage,
  Value<int> rating,
  Value<String> notes,
  Value<String> added,
  Value<String?> firstRegistered,
  Value<String?> motDue,
  Value<String?> taxDue,
  Value<String?> insuranceDue,
  Value<String?> serviceDue,
  Value<String?> boughtOn,
  Value<String?> soldOn,
  Value<int?> soldPrice,
  Value<String> meta,
  Value<int> rowid,
});

class $$VehiclesTableFilterComposer extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableFilterComposer({
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

  ColumnFilters<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mileage =>
      $composableBuilder(column: $table.mileage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fuel =>
      $composableBuilder(column: $table.fuel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get transmission =>
      $composableBuilder(column: $table.transmission, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get registration =>
      $composableBuilder(column: $table.registration, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sellerType =>
      $composableBuilder(column: $table.sellerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seller =>
      $composableBuilder(column: $table.seller, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sellerPhone =>
      $composableBuilder(column: $table.sellerPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get added =>
      $composableBuilder(column: $table.added, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get firstRegistered =>
      $composableBuilder(column: $table.firstRegistered, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get motDue =>
      $composableBuilder(column: $table.motDue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taxDue =>
      $composableBuilder(column: $table.taxDue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get insuranceDue =>
      $composableBuilder(column: $table.insuranceDue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serviceDue =>
      $composableBuilder(column: $table.serviceDue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get boughtOn =>
      $composableBuilder(column: $table.boughtOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get soldOn =>
      $composableBuilder(column: $table.soldOn, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get soldPrice =>
      $composableBuilder(column: $table.soldPrice, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => ColumnFilters(column));
}

class $$VehiclesTableOrderingComposer extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableOrderingComposer({
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

  ColumnOrderings<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mileage =>
      $composableBuilder(column: $table.mileage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fuel =>
      $composableBuilder(column: $table.fuel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get transmission =>
      $composableBuilder(column: $table.transmission, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get registration =>
      $composableBuilder(column: $table.registration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sellerType =>
      $composableBuilder(column: $table.sellerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seller =>
      $composableBuilder(column: $table.seller, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sellerPhone =>
      $composableBuilder(column: $table.sellerPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get added =>
      $composableBuilder(column: $table.added, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get firstRegistered =>
      $composableBuilder(column: $table.firstRegistered, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get motDue =>
      $composableBuilder(column: $table.motDue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taxDue =>
      $composableBuilder(column: $table.taxDue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get insuranceDue =>
      $composableBuilder(column: $table.insuranceDue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serviceDue =>
      $composableBuilder(column: $table.serviceDue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get boughtOn =>
      $composableBuilder(column: $table.boughtOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get soldOn =>
      $composableBuilder(column: $table.soldOn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get soldPrice =>
      $composableBuilder(column: $table.soldPrice, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get meta =>
      $composableBuilder(column: $table.meta, builder: (column) => ColumnOrderings(column));
}

class $$VehiclesTableAnnotationComposer extends Composer<_$AppDatabase, $VehiclesTable> {
  $$VehiclesTableAnnotationComposer({
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

  GeneratedColumn<String> get make => $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model => $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get year => $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get mileage => $composableBuilder(column: $table.mileage, builder: (column) => column);

  GeneratedColumn<int> get price => $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get fuel => $composableBuilder(column: $table.fuel, builder: (column) => column);

  GeneratedColumn<String> get transmission =>
      $composableBuilder(column: $table.transmission, builder: (column) => column);

  GeneratedColumn<String> get body => $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get registration =>
      $composableBuilder(column: $table.registration, builder: (column) => column);

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get sellerType =>
      $composableBuilder(column: $table.sellerType, builder: (column) => column);

  GeneratedColumn<String> get seller =>
      $composableBuilder(column: $table.seller, builder: (column) => column);

  GeneratedColumn<String> get sellerPhone =>
      $composableBuilder(column: $table.sellerPhone, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get stage => $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get rating => $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get added => $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<String> get firstRegistered =>
      $composableBuilder(column: $table.firstRegistered, builder: (column) => column);

  GeneratedColumn<String> get motDue =>
      $composableBuilder(column: $table.motDue, builder: (column) => column);

  GeneratedColumn<String> get taxDue =>
      $composableBuilder(column: $table.taxDue, builder: (column) => column);

  GeneratedColumn<String> get insuranceDue =>
      $composableBuilder(column: $table.insuranceDue, builder: (column) => column);

  GeneratedColumn<String> get serviceDue =>
      $composableBuilder(column: $table.serviceDue, builder: (column) => column);

  GeneratedColumn<String> get boughtOn =>
      $composableBuilder(column: $table.boughtOn, builder: (column) => column);

  GeneratedColumn<String> get soldOn =>
      $composableBuilder(column: $table.soldOn, builder: (column) => column);

  GeneratedColumn<int> get soldPrice =>
      $composableBuilder(column: $table.soldPrice, builder: (column) => column);

  GeneratedColumn<String> get meta => $composableBuilder(column: $table.meta, builder: (column) => column);
}

class $$VehiclesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiclesTable,
          Vehicle,
          $$VehiclesTableFilterComposer,
          $$VehiclesTableOrderingComposer,
          $$VehiclesTableAnnotationComposer,
          $$VehiclesTableCreateCompanionBuilder,
          $$VehiclesTableUpdateCompanionBuilder,
          (Vehicle, BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle>),
          Vehicle,
          PrefetchHooks Function()
        > {
  $$VehiclesTableTableManager(_$AppDatabase db, $VehiclesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$VehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$VehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$VehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> make = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> mileage = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String> fuel = const Value.absent(),
                Value<String> transmission = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> registration = const Value.absent(),
                Value<String> condition = const Value.absent(),
                Value<String> sellerType = const Value.absent(),
                Value<String> seller = const Value.absent(),
                Value<String> sellerPhone = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> added = const Value.absent(),
                Value<String?> firstRegistered = const Value.absent(),
                Value<String?> motDue = const Value.absent(),
                Value<String?> taxDue = const Value.absent(),
                Value<String?> insuranceDue = const Value.absent(),
                Value<String?> serviceDue = const Value.absent(),
                Value<String?> boughtOn = const Value.absent(),
                Value<String?> soldOn = const Value.absent(),
                Value<int?> soldPrice = const Value.absent(),
                Value<String> meta = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                title: title,
                make: make,
                model: model,
                year: year,
                mileage: mileage,
                price: price,
                fuel: fuel,
                transmission: transmission,
                body: body,
                registration: registration,
                condition: condition,
                sellerType: sellerType,
                seller: seller,
                sellerPhone: sellerPhone,
                location: location,
                source: source,
                url: url,
                imageUrl: imageUrl,
                stage: stage,
                rating: rating,
                notes: notes,
                added: added,
                firstRegistered: firstRegistered,
                motDue: motDue,
                taxDue: taxDue,
                insuranceDue: insuranceDue,
                serviceDue: serviceDue,
                boughtOn: boughtOn,
                soldOn: soldOn,
                soldPrice: soldPrice,
                meta: meta,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String title,
                Value<String> make = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> mileage = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String> fuel = const Value.absent(),
                Value<String> transmission = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> registration = const Value.absent(),
                Value<String> condition = const Value.absent(),
                Value<String> sellerType = const Value.absent(),
                Value<String> seller = const Value.absent(),
                Value<String> sellerPhone = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<String> notes = const Value.absent(),
                required String added,
                Value<String?> firstRegistered = const Value.absent(),
                Value<String?> motDue = const Value.absent(),
                Value<String?> taxDue = const Value.absent(),
                Value<String?> insuranceDue = const Value.absent(),
                Value<String?> serviceDue = const Value.absent(),
                Value<String?> boughtOn = const Value.absent(),
                Value<String?> soldOn = const Value.absent(),
                Value<int?> soldPrice = const Value.absent(),
                Value<String> meta = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiclesCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                title: title,
                make: make,
                model: model,
                year: year,
                mileage: mileage,
                price: price,
                fuel: fuel,
                transmission: transmission,
                body: body,
                registration: registration,
                condition: condition,
                sellerType: sellerType,
                seller: seller,
                sellerPhone: sellerPhone,
                location: location,
                source: source,
                url: url,
                imageUrl: imageUrl,
                stage: stage,
                rating: rating,
                notes: notes,
                added: added,
                firstRegistered: firstRegistered,
                motDue: motDue,
                taxDue: taxDue,
                insuranceDue: insuranceDue,
                serviceDue: serviceDue,
                boughtOn: boughtOn,
                soldOn: soldOn,
                soldPrice: soldPrice,
                meta: meta,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VehiclesTable, Vehicle>(table),
                  BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VehiclesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiclesTable,
      Vehicle,
      $$VehiclesTableFilterComposer,
      $$VehiclesTableOrderingComposer,
      $$VehiclesTableAnnotationComposer,
      $$VehiclesTableCreateCompanionBuilder,
      $$VehiclesTableUpdateCompanionBuilder,
      (Vehicle, BaseReferences<_$AppDatabase, $VehiclesTable, Vehicle>),
      Vehicle,
      PrefetchHooks Function()
    >;
typedef $$CarLogsTableCreateCompanionBuilder = CarLogsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String vehicleId,
  required String date,
  required String kind,
  Value<int?> odometer,
  Value<int?> costPence,
  Value<double?> amount,
  Value<String> provider,
  Value<String> notes,
  Value<int> rowid,
});
typedef $$CarLogsTableUpdateCompanionBuilder = CarLogsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> vehicleId,
  Value<String> date,
  Value<String> kind,
  Value<int?> odometer,
  Value<int?> costPence,
  Value<double?> amount,
  Value<String> provider,
  Value<String> notes,
  Value<int> rowid,
});

class $$CarLogsTableFilterComposer extends Composer<_$AppDatabase, $CarLogsTable> {
  $$CarLogsTableFilterComposer({
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

  ColumnFilters<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get costPence =>
      $composableBuilder(column: $table.costPence, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$CarLogsTableOrderingComposer extends Composer<_$AppDatabase, $CarLogsTable> {
  $$CarLogsTableOrderingComposer({
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

  ColumnOrderings<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get costPence =>
      $composableBuilder(column: $table.costPence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$CarLogsTableAnnotationComposer extends Composer<_$AppDatabase, $CarLogsTable> {
  $$CarLogsTableAnnotationComposer({
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

  GeneratedColumn<String> get vehicleId =>
      $composableBuilder(column: $table.vehicleId, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get odometer =>
      $composableBuilder(column: $table.odometer, builder: (column) => column);

  GeneratedColumn<int> get costPence =>
      $composableBuilder(column: $table.costPence, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$CarLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CarLogsTable,
          CarLog,
          $$CarLogsTableFilterComposer,
          $$CarLogsTableOrderingComposer,
          $$CarLogsTableAnnotationComposer,
          $$CarLogsTableCreateCompanionBuilder,
          $$CarLogsTableUpdateCompanionBuilder,
          (CarLog, BaseReferences<_$AppDatabase, $CarLogsTable, CarLog>),
          CarLog,
          PrefetchHooks Function()
        > {
  $$CarLogsTableTableManager(_$AppDatabase db, $CarLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CarLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CarLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CarLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> vehicleId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> odometer = const Value.absent(),
                Value<int?> costPence = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarLogsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                vehicleId: vehicleId,
                date: date,
                kind: kind,
                odometer: odometer,
                costPence: costPence,
                amount: amount,
                provider: provider,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String vehicleId,
                required String date,
                required String kind,
                Value<int?> odometer = const Value.absent(),
                Value<int?> costPence = const Value.absent(),
                Value<double?> amount = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CarLogsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                vehicleId: vehicleId,
                date: date,
                kind: kind,
                odometer: odometer,
                costPence: costPence,
                amount: amount,
                provider: provider,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CarLogsTable, CarLog>(table),
                  BaseReferences<_$AppDatabase, $CarLogsTable, CarLog>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CarLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CarLogsTable,
      CarLog,
      $$CarLogsTableFilterComposer,
      $$CarLogsTableOrderingComposer,
      $$CarLogsTableAnnotationComposer,
      $$CarLogsTableCreateCompanionBuilder,
      $$CarLogsTableUpdateCompanionBuilder,
      (CarLog, BaseReferences<_$AppDatabase, $CarLogsTable, CarLog>),
      CarLog,
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
  $$VehiclesTableTableManager get vehicles => $$VehiclesTableTableManager(_db, _db.vehicles);
  $$CarLogsTableTableManager get carLogs => $$CarLogsTableTableManager(_db, _db.carLogs);
  $$PrefsTableTableManager get prefs => $$PrefsTableTableManager(_db, _db.prefs);
  $$OutboxTableTableManager get outbox => $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncCursorsTableTableManager get syncCursors => $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
}
