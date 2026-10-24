import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';
import 'car_owning.dart';
import 'nation.dart';
import 'pipeline.dart';
import 'vehicles.dart';

/// Pref keys. The prefs table is shared by every Brahma app, so Vahana's
/// keys carry its prefix.
abstract final class PrefKeys {
  static const carSearch = 'vahana.search';
  static const carSources = 'vahana.sources';
}

/// Vahana's write path.
class CarBook {
  CarBook(this.store);
  final Store store;

  AppDatabase get db => store.db as AppDatabase;

  Future<T> pref<T>(String key, T fallback) async {
    final row = await (db.select(db.prefs)..where((p) => p.id.equals(key))).getSingleOrNull();
    if (row == null || row.deleted) return fallback;
    final v = jsonDecode(row.value);
    return v is T ? v : fallback;
  }

  Future<void> setPref(String key, Object value) => store.save(
    db.prefs,
    PrefsCompanion.insert(id: key, value: jsonEncode(value), deleted: const Value(false)),
    key,
  );

  /// Saves a row of any Vahana table.
  Future<void> save<T extends Table, D>(TableInfo<T, D> table, Insertable<D> row, String id) =>
      store.save(table, row, id);

  Future<void> remove(TableInfo table, String id) => store.remove(table, id);

  /// Adds a car advert, or refreshes the one already saved from the same
  /// link (price, mileage, photo), keeping the user's stage, rating, notes
  /// and checks. Returns its id and whether it was new.
  Future<({String id, bool added})> importCar(CarAdvert a, {String? today}) => db.transaction(() async {
    final existing = a.url.isEmpty
        ? null
        : await (db.select(db.vehicles)
                ..where((v) => v.url.equals(a.url) & v.deleted.not())
                ..limit(1))
              .getSingleOrNull();
    final meta = <String, Object?>{
      if (existing != null) ...(jsonDecode(existing.meta) as Map).cast<String, Object?>(),
      if (a.description.isNotEmpty) 'description': a.description,
      if (a.colour.isNotEmpty) 'colour': a.colour,
      if (existing != null && a.price != null && a.price != existing.price)
        'prices': [
          ...(((jsonDecode(existing.meta) as Map)['prices'] as List?) ??
              [
                if (existing.price != null) {'date': existing.added, 'price': existing.price},
              ]),
          {'date': today ?? DateTime.now().toIso8601String().substring(0, 10), 'price': a.price},
        ],
    };
    String keep(String fresh, String? old) => fresh.isNotEmpty ? fresh : old ?? '';
    final id = existing?.id ?? newId();
    await save(
      db.vehicles,
      VehiclesCompanion(
        id: Value(id),
        title: Value(a.title),
        make: Value(keep(a.make, existing?.make)),
        model: Value(keep(a.model, existing?.model)),
        year: Value(a.year ?? existing?.year),
        mileage: Value(a.mileage ?? existing?.mileage),
        price: Value(a.price ?? existing?.price),
        fuel: Value(keep(a.fuel, existing?.fuel)),
        transmission: Value(keep(a.transmission, existing?.transmission)),
        body: Value(keep(a.body, existing?.body)),
        condition: Value(a.condition),
        sellerType: Value(a.sellerType != 'unknown' ? a.sellerType : existing?.sellerType ?? 'unknown'),
        seller: Value(keep(a.seller, existing?.seller)),
        sellerPhone: Value(keep(a.sellerPhone, existing?.sellerPhone)),
        location: Value(keep(a.location, existing?.location)),
        source: Value(a.source),
        url: Value(a.url),
        imageUrl: Value(a.image ?? existing?.imageUrl),
        added: Value(existing?.added ?? today ?? DateTime.now().toIso8601String().substring(0, 10)),
        meta: Value(jsonEncode(meta)),
      ),
      id,
    );
    return (id: id, added: existing == null);
  });

  /// Moves a car along. Buying it starts its ownership.
  Future<void> setVehicleStage(Vehicle v, Stage stage, {String? today}) {
    final buying = stage == Stage.agreed && v.boughtOn == null;
    final day = today ?? DateTime.now().toIso8601String().substring(0, 10);
    return save(
      db.vehicles,
      v.copyWith(stage: stage.id, boughtOn: buying ? Value(day) : const Value.absent()),
      v.id,
    );
  }

  /// Writes a logbook entry and moves on the car's due dates and mileage
  /// that it settles (an MOT pass, a service, a renewal).
  Future<String> addCarLog(
    Vehicle v, {
    required LogKind kind,
    required String date,
    int? odometer,
    int? costPence,
    double? amount,
    String provider = '',
    String notes = '',
    Nation? nation,
  }) => db.transaction(() async {
    final id = newId();
    await save(
      db.carLogs,
      CarLogsCompanion.insert(
        id: id,
        vehicleId: v.id,
        date: date,
        kind: kind.name,
        odometer: Value(odometer),
        costPence: Value(costPence),
        amount: Value(amount),
        provider: Value(provider),
        notes: Value(notes),
      ),
      id,
    );
    var car = afterLog(v, kind, date, nation: nation);
    if (odometer != null && (car.mileage ?? 0) < odometer && v.soldOn == null) {
      car = car.copyWith(mileage: Value(odometer));
    }
    if (car != v) await save(db.vehicles, car, v.id);
    return id;
  });

  /// Removes a car with its logbook.
  Future<void> removeVehicle(String id) => db.transaction(() async {
    final logs = await (db.select(db.carLogs)..where((l) => l.vehicleId.equals(id) & l.deleted.not())).get();
    for (final l in logs) {
      await store.remove(db.carLogs, l.id);
    }
    await store.remove(db.vehicles, id);
  });

  /// Updates the car's meta JSON with [change].
  Future<void> setVehicleMeta(Vehicle v, Map<String, Object?> change) =>
      save(db.vehicles, v.copyWith(meta: jsonEncode({...(jsonDecode(v.meta) as Map), ...change})), v.id);
}
