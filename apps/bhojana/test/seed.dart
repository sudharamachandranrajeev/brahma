import 'package:bhojana/domain/book.dart';
import 'package:bhojana/domain/reader.dart';

/// A weekly shop with a few prices kept.
Future<void> seedBook(ShoppingBook book) async {
  const day = '2026-10-25';
  final list = await book.addList('Weekly shop', today: day);
  final milk = await book.addItem(list, '2 semi-skimmed milk', today: day);
  final bread = await book.addItem(list, 'wholemeal bread', today: day);
  await book.addItem(list, 'bananas', today: day);
  final done = await book.addItem(list, 'washing-up liquid', today: day);
  await book.tick((await book.items(list)).firstWhere((i) => i.id == done), true);
  await book.keepOffer(
    const Offer(shop: 'tesco', title: 'Tesco Semi Skimmed Milk 4 Pints', pence: 145, offer: 'Clubcard Price'),
    itemId: milk,
    query: 'semi-skimmed milk',
    source: 'signed-in',
  );
  await book.keepOffer(
    const Offer(shop: 'aldi', title: 'Cowbelle Semi Skimmed Milk 4 Pints', pence: 139),
    itemId: milk,
    query: 'semi-skimmed milk',
    source: 'web',
  );
  await book.keepOffer(
    const Offer(shop: 'tesco', title: 'Hovis Wholemeal 800g', pence: 140),
    itemId: bread,
    query: 'wholemeal bread',
    source: 'web',
  );
  await book.setPref('bhojana.postcode', 'BT74 7AA');
}
