import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/listing.dart';
import '../domain/pipeline.dart';
import 'common.dart';
import 'property_page.dart';

class HuntPage extends ConsumerStatefulWidget {
  const HuntPage({super.key});

  @override
  ConsumerState<HuntPage> createState() => _HuntPageState();
}

class _HuntPageState extends ConsumerState<HuntPage> {
  var kind = PropertyKind.rent;
  var showDropped = false;

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider).value;
    return PageScaffold(
      title: 'Hunt',
      banner: 'page.hunt',
      actions: [
        HintIconButton(
          'hunt.watch',
          icon: Icons.notifications_active_outlined,
          label: 'Check Brahma Watch',
          onPressed: () => _checkWatch(context, ref),
        ),
      ],
      fab: Hint(
        'hunt.add',
        child: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => _add(context, ref, kind),
          icon: const Icon(Icons.add_home_outlined),
          label: const Text('Add'),
        ),
      ),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<PropertyKind>(
              segments: const [
                ButtonSegment(
                  value: PropertyKind.rent,
                  label: Text('To rent'),
                  icon: Icon(Icons.key_outlined),
                ),
                ButtonSegment(
                  value: PropertyKind.buy,
                  label: Text('To buy'),
                  icon: Icon(Icons.sell_outlined),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (s) => setState(() => kind = s.first),
            ),
            FilterChip(
              label: const Text('Not for us'),
              selected: showDropped,
              onSelected: (v) => setState(() => showDropped = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncView(
          ref.watch(propertiesProvider),
          builder: (all) {
            final mine = all.where((p) => p.kind == kind.name).toList();
            if (mine.isEmpty) {
              return EmptyState(
                icon: Icons.travel_explore,
                title: kind == PropertyKind.rent ? 'No homes to rent yet' : 'No homes to buy yet',
                message:
                    'Paste a PropertyPal link, type one in, or set up a search and let Brahma Watch bring new '
                    'listings here.',
                actions: [
                  FilledButton(
                    onPressed: () => _add(context, ref, kind),
                    child: const Text('Add a property'),
                  ),
                ],
              );
            }
            double? dist(Property p) => distanceFromHome(home, p.lat, p.lon);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final stage in Stage.values)
                  if (stage.active || showDropped)
                    ...() {
                      final rows = mine.where((p) => Stage.of(p.stage) == stage).toList()
                        ..sort((a, b) => (dist(a) ?? 1e9).compareTo(dist(b) ?? 1e9));
                      if (rows.isEmpty) return const <Widget>[];
                      return [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                          child: Text(
                            '${stage.label(kind)} (${rows.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        for (final p in rows) PropertyCard(p, distance: dist(p)),
                      ];
                    }(),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _checkWatch(BuildContext context, WidgetRef ref) async {
    final watch = await ref.read(watchProvider.future);
    if (!context.mounted) return;
    if (watch == null) {
      showMessage(context, 'Set up Brahma Watch in Settings first.');
      return;
    }
    var added = 0;
    if (await guarded(context, () async => added = await ref.mutate((s) => pullWatchEvents(s, watch))) &&
        context.mounted) {
      showMessage(context, added == 0 ? 'Nothing new from Brahma Watch.' : 'Added $added new properties.');
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref, PropertyKind kind) async {
    final how = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('From a PropertyPal link'),
              subtitle: const Text('An advert, or a whole search page'),
              onTap: () => Navigator.pop(context, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Type it in'),
              subtitle: const Text('From a sign, a paper or another site'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (how) {
      case 'link':
        await importFromLink(context, ref, kind);
      case 'manual':
        await editProperty(context, ref, kind: kind);
    }
  }
}

/// Asks for a PropertyPal link and imports its adverts.
Future<void> importFromLink(BuildContext context, WidgetRef ref, PropertyKind kind) async {
  final link = TextEditingController();
  var added = 0, updated = 0;
  final ok = await showFormDialog(
    context,
    title: 'Add from PropertyPal',
    action: 'Add',
    fields: (_) => [
      Field(link, 'Link', hint: 'https://www.propertypal.com/…', autofocus: true),
      const Text(
        'PropertyPal sometimes asks for a browser check. If it does, Brahma Watch can bring the listing in '
        'instead, or type it in.',
      ),
    ],
    onSave: () async {
      final List<Listing> listings;
      try {
        listings = await fetchPropertyPal(link.text);
      } on FormatException catch (e) {
        return e.message;
      }
      await ref.mutate((s) async {
        for (final l in listings) {
          (await s.book.importListing(l, kind: kind)).added ? added++ : updated++;
        }
      });
      return null;
    },
  );
  if (ok && context.mounted) {
    showMessage(context, ['Added $added', if (updated > 0) 'updated $updated'].join(', '));
  }
}

/// Adds a property by hand, or edits one.
Future<void> editProperty(
  BuildContext context,
  WidgetRef ref, {
  Property? p,
  PropertyKind kind = PropertyKind.rent,
}) {
  final address = TextEditingController(text: p?.address);
  final postcode = TextEditingController(text: p?.postcode);
  final price = TextEditingController(text: p?.price?.toString());
  final beds = TextEditingController(text: p?.beds?.toString());
  final style = TextEditingController(text: p?.style);
  final url = TextEditingController(text: p?.url);
  var k = p == null ? kind : PropertyKind.of(p.kind);
  return showFormDialog(
    context,
    title: p == null ? 'New property' : 'Edit property',
    fields: (setState) => [
      Field(address, 'Address', autofocus: p == null),
      Field(postcode, 'Postcode'),
      Choice(
        label: 'What for',
        value: k,
        options: {for (final x in PropertyKind.values) x: x.label},
        onChanged: (v) => setState(() => k = v),
      ),
      Field(price, k == PropertyKind.rent ? 'Rent a month' : 'Price', number: true, prefix: '£'),
      Field(beds, 'Bedrooms', number: true, helper: '0 for a studio'),
      Field(style, 'Type', hint: 'Apartment, terrace, semi-detached…'),
      Field(url, 'Advert link'),
    ],
    onSave: () async {
      if (address.text.trim().isEmpty) return 'Enter the address.';
      final pc = postcode.text.trim().isEmpty ? postcodeIn(address.text) : postcodeIn(postcode.text);
      await ref.mutate((s) async {
        final id = p?.id ?? newId();
        await s.book.save(
          s.db.properties,
          PropertiesCompanion(
            id: Value(id),
            address: Value(address.text.trim()),
            postcode: Value(pc ?? postcode.text.trim().toUpperCase()),
            kind: Value(k.name),
            price: Value(intIn(price)),
            beds: Value(intIn(beds)),
            style: Value(style.text.trim()),
            url: Value(url.text.trim()),
            added: Value(p?.added ?? today()),
          ),
          id,
        );
      });
      return null;
    },
  );
}

class PropertyCard extends StatelessWidget {
  const PropertyCard(this.p, {super.key, this.distance});
  final Property p;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final gone = listingGone(p.listingStatus);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyPage(p.id))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 72,
                    child: p.imageUrl == null
                        ? ColoredBox(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.home_outlined),
                          )
                        : Image.network(
                            p.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.home_outlined),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.address, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        [priceLabel(p), propertyFacts(p)].where((s) => s.isNotEmpty).join(' · '),
                        style: t.bodyMedium?.merge(tabular),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 12,
                        children: [
                          if (distance != null)
                            Hint(
                              'hunt.distance',
                              child: Text(km(distance!), style: t.bodySmall?.copyWith(color: muted)),
                            ),
                          if (gone)
                            Hint(
                              'hunt.gone',
                              child: StatusLabel(Status.warning, listingStatusLabel(p.listingStatus)),
                            ),
                          if (p.rating > 0) Text('★' * p.rating, style: t.bodySmall?.copyWith(color: amber)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
