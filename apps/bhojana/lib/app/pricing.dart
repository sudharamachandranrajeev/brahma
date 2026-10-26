import 'dart:async';

import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../domain/reader.dart';
import '../domain/shops.dart';
import 'providers.dart';

/// Where the automatic search for one item at one shop has got to.
enum Lookup { searching, found, nothing, failed }

/// Prices list items by itself: it searches every compared shop for each
/// item and keeps one product per shop, the same size everywhere it can
/// (pickAcross), so the list is costed without the user comparing item by
/// item. State is keyed by (item id, shop id).
class ListPricer extends Notifier<Map<(String, String), Lookup>> {
  var _running = 0;
  final _waiting = <Completer<void>>[];

  /// Each shop is a whole web page, so only a few load at once.
  static const _parallel = 3;

  @override
  Map<(String, String), Lookup> build() => const {};

  /// Searches [shops] for [items], skipping any item already priced today at
  /// a shop (the user's own pick, or an earlier automatic one) and any
  /// search already under way.
  Future<void> price(List<Item> items, List<Shop> shops) async {
    if (!ref.read(searcherProvider).available) return;
    final day = today();
    final prices = await ref.read(sessionProvider).book.prices();
    final priced = {
      for (final p in prices)
        if (p.itemId != null && p.day == day) (p.itemId!, p.shop),
    };
    final next = {...state};
    final jobs = <(Item, List<Shop>)>[];
    for (final i in items) {
      if (i.done) continue;
      final todo = [
        for (final s in shops)
          if (s.searchable && !priced.contains((i.id, s.id)) && next[(i.id, s.id)] != Lookup.searching) s,
      ];
      if (todo.isEmpty) continue;
      for (final s in todo) {
        next[(i.id, s.id)] = Lookup.searching;
      }
      jobs.add((i, todo));
    }
    state = next;
    await Future.wait([for (final (i, todo) in jobs) _priceItem(i, todo)]);
  }

  Future<void> _priceItem(Item item, List<Shop> shops) async {
    final searcher = ref.read(searcherProvider);
    final found = <String, List<Offer>>{};
    final failed = <String>{};
    await Future.wait([
      for (final s in shops)
        _limited(() => searcher.search(s, item.name))
            .then<void>((o) => found[s.id] = o, onError: (Object _) => failed.add(s.id)),
    ]);
    final picks = pickAcross(item.name, found);
    if (!ref.mounted) return;
    final book = ref.read(sessionProvider).book;
    for (final o in picks.values) {
      await book.keepOffer(o, itemId: item.id, query: item.name, source: 'auto');
    }
    if (!ref.mounted) return;
    if (picks.isNotEmpty) {
      ref.read(revisionProvider.notifier).bump();
      ref.read(syncProvider.notifier).soon();
    }
    state = {
      ...state,
      for (final s in shops)
        (item.id, s.id): failed.contains(s.id)
            ? Lookup.failed
            : picks.containsKey(s.id)
            ? Lookup.found
            : Lookup.nothing,
    };
  }

  /// Runs [job] when one of the [_parallel] slots is free.
  Future<T> _limited<T>(Future<T> Function() job) async {
    if (_running < _parallel) {
      _running++;
    } else {
      // The slot is handed over by the job that frees it.
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    try {
      return await job();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _running--;
      }
    }
  }
}

final pricerProvider = NotifierProvider<ListPricer, Map<(String, String), Lookup>>(ListPricer.new);
