import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

// Table names are unique across the Brahma suite: every app on an account
// reads the same change log and applies only its own tables. Bhojana's all
// start with `food_`. Dates are yyyy-MM-dd; prices are in pence.

/// A shopping list: the weekly shop, a party, a trip to Primark.
@DataClassName('ShopList')
class FoodLists extends Table with SyncedRow {
  TextColumn get name => text()();
  TextColumn get created => text()();
}

/// One thing to buy.
@DataClassName('Item')
class FoodItems extends Table with SyncedRow {
  TextColumn get listId => text()();
  TextColumn get name => text()();
  IntColumn get qty => integer().withDefault(const Constant(1))();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get ord => integer().withDefault(const Constant(0))();
  TextColumn get added => text()();
}

/// A price seen at a shop, kept so lists can be costed and shops compared.
@DataClassName('Price')
class FoodPrices extends Table with SyncedRow {
  /// The list item it was found for, or null for a free search.
  TextColumn get itemId => text().nullable()();

  /// What was searched for.
  TextColumn get query => text()();

  /// A shop id from the catalogue (lib/domain/shops.dart).
  TextColumn get shop => text()();
  TextColumn get title => text()();
  IntColumn get pence => integer()();

  /// "£1.20/kg" as the shop writes it, or empty.
  TextColumn get unitPrice => text().withDefault(const Constant(''))();

  /// "Clubcard Price", "3 for £5" and the like, or empty.
  TextColumn get offer => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();
  BoolColumn get inStock => boolean().withDefault(const Constant(true))();

  /// The day it was seen.
  TextColumn get day => text()();

  /// signed-in (read from the user's own shop session) | auto (picked by the
  /// automatic list pricing) | web | typed
  TextColumn get source => text().withDefault(const Constant('web'))();
}

class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}
