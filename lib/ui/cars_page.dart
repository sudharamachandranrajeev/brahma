import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/book.dart';
import '../domain/car_finance.dart';
import '../domain/car_sources.dart';
import '../domain/contact_links.dart';
import '../domain/pipeline.dart';
import '../domain/vehicles.dart';
import 'common.dart';

enum _Tab { search, garage, finance, guide }

/// Buying a car, new or used: where to look, what you have found, how to
/// pay for it and what to check.
class CarsPage extends ConsumerStatefulWidget {
  const CarsPage({super.key});

  @override
  ConsumerState<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends ConsumerState<CarsPage> {
  var tab = _Tab.search;

  /// The car the finance tab works from, when picked from the garage.
  Vehicle? forFinance;

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Cars',
    banner: 'page.cars',
    fab: tab == _Tab.garage
        ? Hint(
            'cars.add',
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          )
        : null,
    children: [
      SegmentedButton<_Tab>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _Tab.search, label: Text('Search'), icon: Icon(Icons.search)),
          ButtonSegment(value: _Tab.garage, label: Text('Garage'), icon: Icon(Icons.directions_car_outlined)),
          ButtonSegment(value: _Tab.finance, label: Text('Finance'), icon: Icon(Icons.payments_outlined)),
          ButtonSegment(value: _Tab.guide, label: Text('Guide'), icon: Icon(Icons.fact_check_outlined)),
        ],
        selected: {tab},
        onSelectionChanged: (s) => setState(() => tab = s.first),
      ),
      const SizedBox(height: 12),
      switch (tab) {
        _Tab.search => const _SearchTab(),
        _Tab.garage => _GarageTab(
          onFinance: (v) => setState(() {
            forFinance = v;
            tab = _Tab.finance;
          }),
        ),
        _Tab.finance => _FinanceTab(key: ValueKey(forFinance?.id), vehicle: forFinance),
        _Tab.guide => const _GuideTab(),
      },
    ],
  );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final how = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('From an advert link'),
              subtitle: const Text('Any site: reads the price, mileage and photo where the page shares them'),
              onTap: () => Navigator.pop(context, 'link'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Type it in'),
              subtitle: const Text('From a forecourt, a sign or a site that blocks links'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (how) {
      case 'link':
        await _importLink(context, ref);
      case 'manual':
        await editVehicle(context, ref);
    }
  }
}

// Search ------------------------------------------------------------------

class _SearchTab extends ConsumerStatefulWidget {
  const _SearchTab();

  @override
  ConsumerState<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<_SearchTab> {
  final make = TextEditingController(), model = TextEditingController();
  final price = TextEditingController(), postcode = TextEditingController(), radius = TextEditingController();
  var condition = 'used';
  var loaded = false;

  @override
  void dispose() {
    for (final c in [make, model, price, postcode, radius]) {
      c.dispose();
    }
    super.dispose();
  }

  CarSearch get search => CarSearch(
    make: make.text.trim(),
    model: model.text.trim(),
    maxPrice: intIn(price),
    postcode: postcode.text.trim(),
    radius: intIn(radius) ?? 30,
    condition: condition,
  );

  Future<void> _save() async {
    await ref.mutate((s) => s.book.setPref(PrefKeys.carSearch, search.toJson()));
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(carSearchProvider);
    final home = ref.watch(homeProvider).value;
    if (!loaded && saved.hasValue) {
      loaded = true;
      final s = saved.value!;
      make.text = s.make;
      model.text = s.model;
      price.text = s.maxPrice?.toString() ?? '';
      postcode.text = s.postcode;
      radius.text = '${s.radius}';
      condition = s.condition;
    }
    final s = search;
    final custom = ref.watch(customSourcesProvider).value ?? const <CustomSource>[];
    final sources = sourcesFor(s);
    final region = s.inNorthernIreland
        ? 'Northern Ireland: local sites first. UK-wide sites show cars from Great Britain too; check '
              'delivery and whether you can collect.'
        : s.postcode.isEmpty
        ? 'Add your postcode to search near you.'
        : 'Great Britain.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'What you want',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'used', label: Text('Used')),
                  ButtonSegment(value: 'new', label: Text('New')),
                ],
                selected: {condition},
                onSelectionChanged: (v) => setState(() => condition = v.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Field(make, 'Make', hint: 'Ford')),
                  const SizedBox(width: 12),
                  Expanded(child: Field(model, 'Model', hint: 'Focus')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Field(price, 'Most you will pay', number: true, prefix: '£')),
                  const SizedBox(width: 12),
                  Expanded(child: Field(postcode, 'Your postcode', hint: home?.label)),
                  const SizedBox(width: 12),
                  SizedBox(width: 90, child: Field(radius, 'Miles', number: true)),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => guarded(context, _save).then((ok) {
                    if (ok && context.mounted) showMessage(context, 'Saved.');
                  }),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Remember this'),
                ),
              ),
              if (region.isNotEmpty) Text(region, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        for (final kind in SourceKind.values)
          if (sources.any((c) => c.kind == kind))
            SectionCard(
              title: kind.label,
              hint: null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kind.about, style: Theme.of(context).textTheme.bodySmall),
                  for (final c in sources.where((c) => c.kind == kind))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      subtitle: Text(
                        [
                          if (c.note.isNotEmpty) c.note,
                          if (!c.exact) 'Set the other filters on the site.',
                        ].join(' '),
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => openUri(context, c.url(s)),
                    ),
                ],
              ),
            ),
        SectionCard(
          title: 'Your own sites',
          hint: 'cars.custom',
          trailing: TextButton.icon(
            onPressed: () => _addCustom(context, custom),
            icon: const Icon(Icons.add_link),
            label: const Text('Add'),
          ),
          child: custom.isEmpty
              ? const Text('A local dealer, a group, a saved search on any site. Add its link.')
              : Column(
                  children: [
                    for (final (i, c) in custom.indexed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        subtitle: Text(c.link, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          final uri = c.resolve(s);
                          uri == null
                              ? showMessage(context, 'That link is not a web address.')
                              : openUri(context, uri);
                        },
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _saveCustom([...custom]..removeAt(i)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _saveCustom(List<CustomSource> list) =>
      ref.mutate((s) => s.book.setPref(PrefKeys.carSources, [for (final c in list) c.toJson()]));

  Future<void> _addCustom(BuildContext context, List<CustomSource> list) async {
    final name = TextEditingController(), link = TextEditingController();
    await showFormDialog(
      context,
      title: 'Add a site',
      fields: (_) => [
        Field(name, 'Name', hint: 'Smyth Motors', autofocus: true),
        Field(link, 'Link', hint: 'https://…'),
        const Text(
          'Use {make}, {model}, {query}, {postcode} or {maxPrice} in the link and each is filled in from '
          'your search. A plain link opens as it is.',
        ),
      ],
      onSave: () async {
        final c = CustomSource(name: name.text.trim(), link: link.text.trim());
        if (c.name.isEmpty) return 'Give the site a name.';
        if (c.resolve(const CarSearch()) == null) return 'Enter a full web address starting https://.';
        await _saveCustom([...list, c]);
        return null;
      },
    );
  }
}

// Garage ------------------------------------------------------------------

class _GarageTab extends ConsumerWidget {
  const _GarageTab({required this.onFinance});
  final void Function(Vehicle v) onFinance;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    ref.watch(vehiclesProvider),
    builder: (all) {
      if (all.isEmpty) {
        return EmptyState(
          icon: Icons.directions_car_outlined,
          title: 'No cars saved yet',
          message: 'Paste an advert link from any site, or type a car in, to compare and keep notes.',
          actions: [
            FilledButton(onPressed: () => _importLink(context, ref), child: const Text('Add from a link')),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final stage in Stage.values)
            ...() {
              final rows = all.where((v) => Stage.of(v.stage) == stage).toList();
              if (rows.isEmpty) return const <Widget>[];
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(
                    '${carStageLabel(stage)} (${rows.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final v in rows) _VehicleCard(v, onFinance: () => onFinance(v)),
              ];
            }(),
        ],
      );
    },
  );
}

String vehicleFacts(Vehicle v) => [
  if (v.year != null) '${v.year}',
  if (v.mileage != null) '${_miles.format(v.mileage)} miles',
  if (v.fuel.isNotEmpty) v.fuel,
  if (v.transmission.isNotEmpty) v.transmission,
  if (v.body.isNotEmpty) v.body,
].join(' · ');

final _miles = NumberFormat.decimalPattern('en_GB');

class _VehicleCard extends ConsumerWidget {
  const _VehicleCard(this.v, {required this.onFinance});
  final Vehicle v;
  final VoidCallback onFinance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final checks = (jsonDecode(v.meta) as Map)['checks'] as List? ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (v.imageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 96,
                        height: 72,
                        child: Image.network(
                          v.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(Icons.directions_car_outlined),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.title, style: t.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (v.price != null) gbp(v.price!) else 'Price not shown',
                          vehicleFacts(v),
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: t.bodyMedium?.merge(tabular),
                      ),
                      Text(
                        [
                          sellerTypes[v.sellerType] ?? '',
                          if (v.seller.isNotEmpty) v.seller,
                          if (v.location.isNotEmpty) v.location,
                          if (v.source != 'manual') v.source,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: t.bodySmall?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (a) async {
                    switch (a) {
                      case 'open':
                        await openUri(context, Uri.parse(v.url));
                      case 'edit':
                        await editVehicle(context, ref, v: v);
                      case 'call':
                        await openUri(context, callUri(v.sellerPhone));
                      case 'remove':
                        await ref.mutate((s) => s.book.remove(s.db.vehicles, v.id));
                    }
                  },
                  itemBuilder: (_) => [
                    if (v.url.isNotEmpty) const PopupMenuItem(value: 'open', child: Text('Open the advert')),
                    if (v.sellerPhone.isNotEmpty)
                      const PopupMenuItem(value: 'call', child: Text('Call the seller')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in Stage.values)
                  ChoiceChip(
                    label: Text(carStageLabel(s)),
                    selected: Stage.of(v.stage) == s,
                    onSelected: (_) =>
                        ref.mutate((x) => x.book.save(x.db.vehicles, v.copyWith(stage: s.id), v.id)),
                  ),
              ],
            ),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '$i of 5',
                    icon: Icon(i <= v.rating ? Icons.star : Icons.star_border, color: amber),
                    onPressed: () => ref.mutate(
                      (x) => x.book.save(x.db.vehicles, v.copyWith(rating: i == v.rating ? 0 : i), v.id),
                    ),
                  ),
                const Spacer(),
                Text('${checks.length} of ${vehicleChecks.length} checks', style: t.bodySmall),
                TextButton(onPressed: () => _checks(context, ref), child: const Text('Checks')),
                TextButton(onPressed: onFinance, child: const Text('Finance')),
              ],
            ),
            if (v.notes.isNotEmpty) Text(v.notes, style: t.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _checks(BuildContext context, WidgetRef ref) async {
    final meta = (jsonDecode(v.meta) as Map).cast<String, Object?>();
    final done = {for (final c in (meta['checks'] as List? ?? const [])) '$c'};
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Checks: ${v.title}'),
          scrollable: true,
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final c in vehicleChecks)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: done.contains(c.id),
                    title: Text(c.title),
                    subtitle: Text(c.body),
                    onChanged: (on) async {
                      on == true ? done.add(c.id) : done.remove(c.id);
                      setState(() {});
                      await ref.mutate(
                        (x) => x.book.save(
                          x.db.vehicles,
                          v.copyWith(meta: jsonEncode({...meta, 'checks': done.toList()})),
                          v.id,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      ),
    );
  }
}

/// Reads an advert link into the garage.
Future<void> _importLink(BuildContext context, WidgetRef ref) async {
  final link = TextEditingController();
  var added = true;
  final ok = await showFormDialog(
    context,
    title: 'Add from an advert link',
    action: 'Add',
    fields: (_) => [
      Field(link, 'Link', hint: 'https://…', autofocus: true),
      const Text(
        'Reads the details the page shares with search engines. Some sites block this or need a '
        'sign-in (Facebook); type those in.',
      ),
    ],
    onSave: () async {
      final CarAdvert advert;
      try {
        advert = await fetchCarAdvert(link.text);
      } on FormatException catch (e) {
        return e.message;
      }
      added = (await ref.mutate((s) => s.book.importCar(advert))).added;
      return null;
    },
  );
  if (ok && context.mounted) showMessage(context, added ? 'Added.' : 'Updated.');
}

/// Adds a car by hand, or edits one.
Future<void> editVehicle(BuildContext context, WidgetRef ref, {Vehicle? v}) {
  final title = TextEditingController(text: v?.title);
  final price = TextEditingController(text: v?.price?.toString());
  final year = TextEditingController(text: v?.year?.toString());
  final mileage = TextEditingController(text: v?.mileage?.toString());
  final fuel = TextEditingController(text: v?.fuel);
  final seller = TextEditingController(text: v?.seller);
  final phone = TextEditingController(text: v?.sellerPhone);
  final location = TextEditingController(text: v?.location);
  final url = TextEditingController(text: v?.url);
  final notes = TextEditingController(text: v?.notes);
  var condition = v?.condition ?? 'used';
  var sellerType = v?.sellerType ?? 'dealer';
  return showFormDialog(
    context,
    title: v == null ? 'New car' : 'Edit car',
    fields: (setState) => [
      Field(title, 'Car', hint: '2019 Ford Focus 1.0 Titanium', autofocus: v == null),
      Choice(
        label: 'Condition',
        value: condition,
        options: const {'used': 'Used', 'new': 'New'},
        onChanged: (x) => setState(() => condition = x),
      ),
      Row(
        children: [
          Expanded(child: Field(price, 'Price', number: true, prefix: '£')),
          const SizedBox(width: 12),
          Expanded(child: Field(year, 'Year', number: true)),
          const SizedBox(width: 12),
          Expanded(child: Field(mileage, 'Miles', number: true)),
        ],
      ),
      Field(fuel, 'Fuel', hint: 'Petrol, diesel, hybrid, electric'),
      Choice(
        label: 'Seller',
        value: sellerType,
        options: sellerTypes,
        onChanged: (x) => setState(() => sellerType = x),
      ),
      Field(seller, 'Seller name'),
      Field(phone, 'Seller phone'),
      Field(location, 'Where'),
      Field(url, 'Advert link'),
      Field(notes, 'Notes', lines: 2),
    ],
    onSave: () async {
      if (title.text.trim().isEmpty) return 'Enter the car.';
      await ref.mutate((s) async {
        final id = v?.id ?? newId();
        await s.book.save(
          s.db.vehicles,
          VehiclesCompanion(
            id: Value(id),
            title: Value(title.text.trim()),
            condition: Value(condition),
            price: Value(intIn(price)),
            year: Value(intIn(year)),
            mileage: Value(intIn(mileage)),
            fuel: Value(fuel.text.trim()),
            sellerType: Value(sellerType),
            seller: Value(seller.text.trim()),
            sellerPhone: Value(phone.text.trim()),
            location: Value(location.text.trim()),
            url: Value(url.text.trim()),
            source: Value(sourceOf(url.text)),
            notes: Value(notes.text.trim()),
            added: Value(v?.added ?? today()),
          ),
          id,
        );
      });
      return null;
    },
  );
}

// Finance -----------------------------------------------------------------

class _FinanceTab extends StatefulWidget {
  const _FinanceTab({super.key, this.vehicle});
  final Vehicle? vehicle;

  @override
  State<_FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<_FinanceTab> {
  late double price = widget.vehicle?.price?.toDouble() ?? 12000;
  late double age = widget.vehicle?.year == null
      ? 0
      : (DateTime.now().year - widget.vehicle!.year!).clamp(0, 30).toDouble();
  late Fuel fuel = Fuel.guess(widget.vehicle?.fuel ?? '');
  double deposit = 1000, apr = 0.099, loanApr = 0.069, balloon = 0, fees = 0;
  double leaseMonthly = 0, leaseInitial = 6, leaseFee = 0;
  double endValue = 0;
  int months = 48;
  double miles = 8000, economy = 45, energy = 135, insurance = 600, tax = 200, servicing = 350;

  CarDeal get deal => CarDeal(
    price: price,
    deposit: deposit,
    months: months,
    apr: apr,
    loanApr: loanApr,
    balloon: balloon,
    fees: fees,
    endValue: endValue > 0 ? endValue : null,
    age: age,
    leaseMonthly: leaseMonthly,
    leaseInitial: leaseInitial.round(),
    leaseFee: leaseFee,
  );

  Widget _n(String key, String label, Unit unit, double value, void Function(double) set, {String? helper}) =>
      NumberInput(
        key: ValueKey('$key/${widget.vehicle?.id}'),
        value: value,
        label: label,
        unit: unit,
        helper: helper,
        onChanged: (v) => setState(() => set(v)),
      );

  @override
  Widget build(BuildContext context) {
    final d = deal;
    final results = comparePlans(d);
    final running = Running(
      milesPerYear: miles,
      fuel: fuel,
      economy: economy,
      energyPrice: energy,
      insurance: insurance,
      tax: tax,
      servicing: servicing,
    );
    final cheapest =
        (results.where((r) => r.missing == null).toList()..sort((a, b) => a.netCost.compareTo(b.netCost)))
            .first;
    final form = SectionCard(
      title: widget.vehicle == null ? 'The deal' : widget.vehicle!.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _n('price', 'Price', Unit.pounds, price, (v) => price = v),
          _n('age', 'Age of the car (years, 0 if new)', Unit.number, age, (v) => age = v),
          _n('deposit', 'Deposit and part-exchange', Unit.pounds, deposit, (v) => deposit = v),
          Choice<int>(
            label: 'Term',
            value: months,
            options: {
              for (final m in const [24, 36, 48, 60]) m: '$m months',
            },
            onChanged: (m) => setState(() => months = m),
          ),
          _n(
            'apr',
            'Dealer finance APR (HP, PCP)',
            Unit.percent,
            apr,
            (v) => apr = v,
            helper: 'Typically 6–10% new, 10–15% used with good credit.',
          ),
          _n(
            'loanApr',
            'Bank loan APR',
            Unit.percent,
            loanApr,
            (v) => loanApr = v,
            helper: 'Compare a loan quote: about 6.5–12% for £10,000.',
          ),
          _n(
            'balloon',
            'PCP final payment (0 to estimate)',
            Unit.pounds,
            balloon,
            (v) => balloon = v,
            helper: 'The "guaranteed future value" in the quote.',
          ),
          _n('fees', 'Arrangement fees', Unit.pounds, fees, (v) => fees = v),
          _n(
            'endValue',
            'Worth at the end (0 to estimate)',
            Unit.pounds,
            endValue,
            (v) => endValue = v,
            helper: 'Estimated ${gbp(d.valueAtEnd)} from typical depreciation.',
          ),
          const Divider(),
          Text('A lease quote, to compare', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _n('leaseMonthly', 'Monthly rental', Unit.pounds, leaseMonthly, (v) => leaseMonthly = v),
          _n(
            'leaseInitial',
            'Initial payment (months of rental)',
            Unit.number,
            leaseInitial,
            (v) => leaseInitial = v,
          ),
          _n('leaseFee', 'Broker or admin fee', Unit.pounds, leaseFee, (v) => leaseFee = v),
        ],
      ),
    );
    final out = SectionCard(
      title: 'The plans compared',
      hint: 'cars.compare',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lowest real cost over $months months: ${cheapest.plan.label}.',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final r in results) _PlanTile(r, months, best: identical(r, cheapest)),
        ],
      ),
    );
    final runningCard = SectionCard(
      title: 'Running costs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Choice<Fuel>(
            label: 'Fuel',
            value: fuel,
            options: {for (final f in Fuel.values) f: f.label},
            onChanged: (f) => setState(() {
              fuel = f;
              economy = f == Fuel.electric ? 3.5 : 45;
              energy = f == Fuel.electric
                  ? 28
                  : f == Fuel.diesel
                  ? 142
                  : 135;
            }),
          ),
          _n('miles', 'Miles a year', Unit.number, miles, (v) => miles = v),
          _n('economy', 'Economy (${fuel.economyUnit})', Unit.number, economy, (v) => economy = v),
          _n('energy', 'Energy price (${fuel.priceUnit})', Unit.number, energy, (v) => energy = v),
          _n(
            'insurance',
            'Insurance a year',
            Unit.pounds,
            insurance,
            (v) => insurance = v,
            helper: 'Get quotes for this exact car before buying.',
          ),
          _n('tax', 'Road tax (VED) a year', Unit.pounds, tax, (v) => tax = v),
          _n('servicing', 'Servicing and tyres a year', Unit.pounds, servicing, (v) => servicing = v),
          const Divider(),
          FigureRow('Energy a year', gbp(running.energyPerYear)),
          FigureRow('Running costs a year', gbp(running.perYear)),
          FigureRow('A month', gbp(running.perMonth), strong: true),
          FigureRow('A mile', '${(running.perMile * 100).toStringAsFixed(1)}p'),
          FigureRow(
            'With the plan\'s net cost, a month',
            gbp(running.perMonth + cheapest.netPerMonth(months)),
            strong: true,
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 800) {
          return Column(children: [out, runningCard, form]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: form),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [out, runningCard])),
          ],
        );
      },
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile(this.r, this.months, {required this.best});
  final PlanResult r;
  final int months;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(child: Text(r.plan.label)),
          if (best)
            const Padding(padding: EdgeInsets.only(right: 8), child: StatusLabel(Status.good, 'Lowest')),
          Text(r.missing != null ? '–' : gbp(r.netCost), style: t.titleSmall?.merge(tabular)),
        ],
      ),
      subtitle: Text(
        r.missing ??
            (r.monthly > 0
                ? '${gbp(r.monthly)} × ${r.payments} months, ${gbp(r.upfront)} up front'
                : '${gbp(r.upfront)} on the day'),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(r.plan.about, style: t.bodySmall),
        ),
        const SizedBox(height: 8),
        if (r.missing == null) ...[
          FigureRow('Paid in total', gbp(r.totalPaid)),
          FigureRow(r.plan == Plan.lease ? 'Fees' : 'Interest and fees', gbp(r.interest)),
          if (r.finalPayment > 0) FigureRow('Final payment', gbp(r.finalPayment)),
          FigureRow('Car worth at the end', r.ownedValue > 0 ? gbp(r.ownedValue) : 'Not yours'),
          FigureRow('Real cost (paid less value)', gbp(r.netCost), strong: true),
          FigureRow('Real cost a month', gbp(r.netPerMonth(months))),
          if (r.handBackCost != null) FigureRow('Paid if you hand it back', gbp(r.handBackCost!)),
          if (r.equity != null)
            FigureRow(
              'Value less final payment',
              gbp(r.equity!),
              status: r.equity! >= 0 ? Status.good : Status.warning,
            ),
          if (r.terminationMonth != null)
            FigureRow('Can hand back (half paid) after', 'payment ${r.terminationMonth}'),
        ],
      ],
    );
  }
}

// Guide -------------------------------------------------------------------

/// Checks before paying for a used car.
const vehicleChecks = <({String id, String title, String body})>[
  (
    id: 'history',
    title: 'History check',
    body:
        'Finance owing, stolen, written off, scrapped, plate changes, mileage records (HPI, Experian, RAC).',
  ),
  (
    id: 'mot',
    title: 'MOT history',
    body: 'Free on GOV.UK: past failures, advisories and mileage at each test.',
  ),
  (
    id: 'recall',
    title: 'Recalls',
    body: 'Free on GOV.UK by registration. Open recalls should be fixed free by a dealer.',
  ),
  (
    id: 'v5c',
    title: 'V5C logbook',
    body: 'Seller\'s name and address match, chassis number matches the car, keeper history makes sense.',
  ),
  (
    id: 'service',
    title: 'Service history',
    body: 'Stamped book or invoices, cambelt and major work done on time.',
  ),
  (
    id: 'drive',
    title: 'Test drive',
    body: 'Cold start, brakes, steering, clutch, warning lights, noises, all electrics.',
  ),
  (
    id: 'inspect',
    title: 'Independent inspection',
    body: 'AA or RAC inspection, or a trusted garage, for anything of value.',
  ),
  (
    id: 'insurance',
    title: 'Insurance quote',
    body: 'Quote the exact car first; it can change the price you can afford.',
  ),
  (
    id: 'payment',
    title: 'Safe payment',
    body:
        'Bank transfer or credit card after seeing the car. Never pay a deposit to someone you have not met.',
  ),
];

const _links = <(String, String)>[
  ('MOT history', 'https://www.check-mot.service.gov.uk/'),
  ('Vehicle recalls', 'https://www.check-vehicle-recalls.service.gov.uk/'),
  ('Check vehicle tax', 'https://vehicleenquiry.service.gov.uk/'),
  ('Vehicle tax rates (VED)', 'https://www.gov.uk/vehicle-tax-rate-tables'),
  (
    'Financial Ombudsman: car finance',
    'https://www.financial-ombudsman.org.uk/consumers/complaints-can-help/car-vehicle-finance',
  ),
];

class _GuideTab extends StatelessWidget {
  const _GuideTab();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget points(List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(i)),
              ],
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Ways to pay',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in Plan.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.label, style: t.titleSmall),
                      Text(p.about),
                    ],
                  ),
                ),
              const Text(
                'Compare the real cost (paid less what the car is worth at the end), not the monthly figure. '
                'PCP and leasing look cheap monthly because you are not paying off the whole car.',
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Your rights',
          child: points(const [
            'From a dealer or online store: the car must be as described, of satisfactory quality and fit for '
                'purpose (Consumer Rights Act 2015). You have 30 days to reject a faulty car for a full refund, '
                'then a repair or replacement, then a price reduction. Distance sales also get a 14-day cancellation.',
            'From a private seller: the car must match its description and the seller must own it. There is no '
                '"satisfactory quality" duty, so check it yourself first.',
            'Finance: you can withdraw from a credit agreement within 14 days. On HP and PCP you can hand the car '
                'back once you have paid half the total payable (voluntary termination), if you kept it in good order.',
            'Paying £100 to £30,000 on a credit card makes the card company jointly liable if the car is not as '
                'sold (Section 75). A debit card may allow a chargeback.',
            'Motor finance commission: the FCA\'s redress scheme covers agreements from April 2007 to November '
                '2024 where the lender paid the dealer a commission. Final rules were published in March 2026 and '
                'the scheme has been partly paused during legal challenges (hearing February 2027). Average '
                'payouts are expected near £830. Check the FCA site before using a claims firm: you can claim '
                'free.',
          ]),
        ),
        SectionCard(
          title: 'Tax and costs to know',
          child: points(const [
            'Road tax (VED) for cars first registered since April 2017: £200 a year in 2026/27 (£210 by monthly '
                'direct debit), with a first-year rate set by CO2 from £10 to over £5,000.',
            'A supplement of £440 a year for five years applies to cars with a list price over £40,000 (£50,000 '
                'for electric cars registered since April 2025).',
            'Electric cars pay VED since April 2025 (£10 first year, then the standard rate). Pay-per-mile eVED '
                'is planned from April 2028: 3p a mile for electric, 1.5p for plug-in hybrids.',
            'A car loses roughly a third of its value in the first year and half or more by year three, and a '
                'nearly new car costs far less than a new one for most of the same life.',
            'Insurance varies widely by car, age, postcode and history: always quote first. Warranty add-ons and '
                'GAP insurance are often cheaper bought separately.',
          ]),
        ),
        SectionCard(
          title: 'Checks before you pay',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in vehicleChecks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: t.titleSmall),
                      Text(c.body),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              for (final (label, link) in _links)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(label),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => openUri(context, Uri.parse(link)),
                ),
            ],
          ),
        ),
        Text(
          'Figures are as of October 2026 and a starting point for your own checks, not advice.',
          style: t.bodySmall,
        ),
      ],
    );
  }
}
