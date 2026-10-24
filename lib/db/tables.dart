import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

// Table names are unique across the Brahma suite: every app on an account
// reads the same change log and applies only its own tables.

/// A property being looked at, bought or owned. Rents and prices are whole
/// pounds (a month's rent for lets).
@DataClassName('Property')
class Properties extends Table with SyncedRow {
  TextColumn get address => text()();
  TextColumn get postcode => text().withDefault(const Constant(''))();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();

  /// rent | buy | owned: what the user is doing with it.
  TextColumn get kind => text()();

  /// Where it is in the hunt (see domain/pipeline.dart).
  TextColumn get stage => text().withDefault(const Constant('new'))();
  IntColumn get price => integer().nullable()();
  IntColumn get beds => integer().nullable()();
  IntColumn get baths => integer().nullable()();
  TextColumn get style => text().withDefault(const Constant(''))();
  TextColumn get furnished => text().withDefault(const Constant(''))();
  TextColumn get availableFrom => text().nullable()();

  /// manual | propertypal; with the advert's id and link.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceId => text().nullable()();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get imageUrl => text().nullable()();

  /// The advert's own status (toLet, letAgreed, forSale...).
  TextColumn get listingStatus => text().withDefault(const Constant(''))();
  TextColumn get agentId => text().nullable()();

  /// 0 (unrated) to 5.
  IntColumn get rating => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get added => text()();

  /// JSON extras: description, heating, purchase price and date when owned.
  TextColumn get meta => text().withDefault(const Constant('{}'))();
}

/// Agents, landlords, tenants, solicitors, brokers, trades.
@DataClassName('Contact')
class Contacts extends Table with SyncedRow {
  TextColumn get name => text()();
  TextColumn get role => text().withDefault(const Constant('agent'))();
  TextColumn get organisation => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// The contact log: calls, messages, e-mails, notes.
@DataClassName('Interaction')
class Interactions extends Table with SyncedRow {
  TextColumn get propertyId => text().nullable()();
  TextColumn get contactId => text().nullable()();

  /// Local date and time, yyyy-MM-ddTHH:mm.
  TextColumn get at => text()();

  /// call | sms | whatsapp | email | visit | note
  TextColumn get channel => text()();

  /// out | in
  TextColumn get direction => text().withDefault(const Constant('out'))();
  TextColumn get summary => text().withDefault(const Constant(''))();

  /// Date to chase it up, yyyy-MM-dd.
  TextColumn get followUp => text().nullable()();
}

@DataClassName('Viewing')
class Viewings extends Table with SyncedRow {
  TextColumn get propertyId => text()();

  /// Local date and time, yyyy-MM-ddTHH:mm.
  TextColumn get at => text()();

  /// booked | done | cancelled
  TextColumn get status => text().withDefault(const Constant('booked'))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// Saved searches. Brahma Watch runs them in the cloud and pushes alerts.
@DataClassName('Search')
class Searches extends Table with SyncedRow {
  TextColumn get name => text()();

  /// PropertyPal search path, e.g. /property-to-rent/enniskillen.
  TextColumn get path => text()();
  IntColumn get maxPrice => integer().nullable()();
  IntColumn get minBeds => integer().nullable()();
  IntColumn get maxBeds => integer().nullable()();
  RealColumn get centreLat => real().nullable()();
  RealColumn get centreLon => real().nullable()();
  TextColumn get centreLabel => text().withDefault(const Constant(''))();
  RealColumn get radiusKm => real().nullable()();
  BoolColumn get includeUnpriced => boolean().withDefault(const Constant(true))();
  BoolColumn get paused => boolean().withDefault(const Constant(false))();
}

/// Saved what-ifs: buy-to-let, buying a home, a development.
@DataClassName('Appraisal')
class Appraisals extends Table with SyncedRow {
  TextColumn get name => text()();

  /// btl | home | dev
  TextColumn get kind => text()();
  TextColumn get propertyId => text().nullable()();

  /// The inputs as JSON (see domain/appraisal.dart).
  TextColumn get inputs => text().withDefault(const Constant('{}'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get updated => text()();
}

/// A let: the user as landlord of an owned property, or as tenant.
@DataClassName('Tenancy')
class Tenancies extends Table with SyncedRow {
  TextColumn get propertyId => text()();

  /// landlord | tenant
  TextColumn get role => text()();

  /// The tenant (or the landlord, when the user rents).
  TextColumn get otherParty => text().withDefault(const Constant(''))();
  TextColumn get contactId => text().nullable()();
  TextColumn get start => text()();
  TextColumn get end => text().nullable()();

  /// A month's rent and the day of the month it is due.
  IntColumn get rent => integer()();
  IntColumn get rentDay => integer().withDefault(const Constant(1))();
  IntColumn get deposit => integer().withDefault(const Constant(0))();
  TextColumn get depositScheme => text().withDefault(const Constant(''))();
  TextColumn get depositRef => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// Rent received (or paid) on a tenancy.
@DataClassName('RentPayment')
class RentPayments extends Table with SyncedRow {
  TextColumn get tenancyId => text()();
  TextColumn get date => text()();
  IntColumn get amount => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

/// Landlord checks with due dates: gas safety, electrical, EPC, deposit...
@DataClassName('ComplianceItem')
class ComplianceItems extends Table with SyncedRow {
  TextColumn get propertyId => text()();
  TextColumn get kind => text()();
  TextColumn get due => text()();
  TextColumn get done => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// Saved area research for a postcode.
@DataClassName('Area')
class Areas extends Table with SyncedRow {
  TextColumn get postcode => text()();
  TextColumn get label => text().withDefault(const Constant(''))();

  /// AreaReport as JSON (see domain/research.dart).
  TextColumn get report => text().withDefault(const Constant('{}'))();
  TextColumn get fetched => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

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

  /// JSON extras: description, colour, the checks done.
  TextColumn get meta => text().withDefault(const Constant('{}'))();
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
