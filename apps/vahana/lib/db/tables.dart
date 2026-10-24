import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

// Table names are unique across the Brahma suite: every app on an account
// reads the same change log and applies only its own tables. These two
// began in Anveshana (0.2.0), so rows synced from it carry over.

/// A car (or van, motorbike) being looked at to buy, new or used. Prices
/// are whole pounds.
@DataClassName('Vehicle')
class Vehicles extends Table with SyncedRow {
  /// What the advert calls it ("2019 Ford Focus 1.0 EcoBoost Titanium").
  TextColumn get title => text()();
  TextColumn get make => text().withDefault(const Constant(''))();
  TextColumn get model => text().withDefault(const Constant(''))();
  IntColumn get year => integer().nullable()();
  IntColumn get mileage => integer().nullable()();
  IntColumn get price => integer().nullable()();
  TextColumn get fuel => text().withDefault(const Constant(''))();
  TextColumn get transmission => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get registration => text().withDefault(const Constant(''))();

  /// used | new
  TextColumn get condition => text().withDefault(const Constant('used'))();

  /// dealer | private | store (an online car shop) | unknown
  TextColumn get sellerType => text().withDefault(const Constant('unknown'))();
  TextColumn get seller => text().withDefault(const Constant(''))();
  TextColumn get sellerPhone => text().withDefault(const Constant(''))();
  TextColumn get location => text().withDefault(const Constant(''))();

  /// The site's id (autotrader, gumtree...) or its host; with the link.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();

  /// Same steps as a property hunt (domain/pipeline.dart), read for cars.
  TextColumn get stage => text().withDefault(const Constant('new'))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get added => text()();

  /// Owning it (yyyy-MM-dd): first registered (sets the first MOT), the
  /// dates things fall due, and when it was bought and sold.
  TextColumn get firstRegistered => text().nullable()();
  TextColumn get motDue => text().nullable()();
  TextColumn get taxDue => text().nullable()();
  TextColumn get insuranceDue => text().nullable()();
  TextColumn get serviceDue => text().nullable()();
  TextColumn get boughtOn => text().nullable()();
  TextColumn get soldOn => text().nullable()();
  IntColumn get soldPrice => integer().nullable()();

  /// JSON extras: description, colour, price history, checklists ticked,
  /// a PCP's mileage allowance.
  TextColumn get meta => text().withDefault(const Constant('{}'))();
}

/// A car's logbook: fuel, services, repairs, MOTs, tyres, insurance, tax,
/// valuations. Costs in pence.
@DataClassName('CarLog')
class CarLogs extends Table with SyncedRow {
  TextColumn get vehicleId => text()();
  TextColumn get date => text()();

  /// See domain/car_owning.dart (LogKind).
  TextColumn get kind => text()();
  IntColumn get odometer => integer().nullable()();
  IntColumn get costPence => integer().nullable()();

  /// Litres, kWh, or tread depth in mm, by kind.
  RealColumn get amount => real().nullable()();

  /// The garage, insurer or buyer.
  TextColumn get provider => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

// The tables sync needs; their columns come from brahma_core.

@DataClassName('Pref')
class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}
