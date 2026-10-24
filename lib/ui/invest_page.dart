import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/appraisal.dart';
import '../domain/tax.dart';
import 'common.dart';

const _kinds = {'btl': 'Buy-to-let', 'home': 'Buy a home', 'dev': 'Development'};

Map<String, Object?> _normalised(String kind, Map<String, Object?> j) => switch (kind) {
  'home' => HomeInput.fromJson(j).toJson(),
  'dev' => DevInput.fromJson(j).toJson(),
  _ => BtlInput.fromJson(j).toJson(),
};

Object? _get(Object? j, String path) {
  for (final k in path.split('.')) {
    j = switch (j) {
      Map m => m[k],
      List l => l[int.parse(k)],
      _ => null,
    };
  }
  return j;
}

/// A copy of [j] with [value] at [path] ("mortgage.rate", "units.0.price").
Map<String, Object?> _set(Map<String, Object?> j, String path, Object? value) {
  final copy = (jsonDecode(jsonEncode(j)) as Map).cast<String, Object?>();
  final keys = path.split('.');
  Object? at = copy;
  for (final k in keys.take(keys.length - 1)) {
    at = switch (at) {
      Map m => m.putIfAbsent(k, () => <String, Object?>{}),
      List l => l[int.parse(k)],
      _ => null,
    };
  }
  switch (at) {
    case Map m:
      m[keys.last] = value;
    case List l:
      l[int.parse(keys.last)] = value;
  }
  return copy;
}

/// Appraisals: buy-to-let, buying a home, a development. Opened from a
/// property with [start] to appraise that one.
class InvestPage extends ConsumerStatefulWidget {
  const InvestPage({super.key, this.start, this.propertyId});
  final ({String kind, Map<String, Object?> inputs})? start;
  final String? propertyId;

  @override
  ConsumerState<InvestPage> createState() => _InvestPageState();
}

class _InvestPageState extends ConsumerState<InvestPage> {
  late String kind = widget.start?.kind ?? 'btl';
  late final inputs = {
    for (final k in _kinds.keys) k: _normalised(k, k == widget.start?.kind ? widget.start!.inputs : const {}),
  };
  bool saved = false;

  /// The saved appraisal on screen, if any.
  Appraisal? current;

  /// Bumped when inputs are replaced wholesale, so the fields re-read them.
  int generation = 0;

  Map<String, Object?> get j => inputs[kind]!;

  void put(String path, Object? v) => setState(() => inputs[kind] = _normalised(kind, _set(j, path, v)));

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: current?.name ?? 'Invest',
      banner: 'page.invest',
      actions: [
        HintIconButton('invest.save', icon: Icons.bookmark_add_outlined, label: 'Save', onPressed: _save),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            SegmentedButton<String>(
              segments: [for (final e in _kinds.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: saved ? const {} : {kind},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) => setState(() {
                if (s.isEmpty) return;
                kind = s.first;
                saved = false;
              }),
            ),
            FilterChip(
              avatar: const Icon(Icons.bookmarks_outlined),
              label: const Text('Saved'),
              selected: saved,
              onSelected: (v) => setState(() => saved = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (saved) _savedList() else _calculator(),
      ],
    );
  }

  Widget _calculator() => LayoutBuilder(
    builder: (context, c) {
      final form = SectionCard(
        title: 'Figures',
        child: Column(
          key: ValueKey('$kind/$generation'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (kind) {
            'home' => _homeForm(),
            'dev' => _devForm(),
            _ => _btlForm(),
          },
        ),
      );
      final results = SectionCard(
        title: 'Results',
        child: switch (kind) {
          'home' => _homeResults(appraiseHome(HomeInput.fromJson(j))),
          'dev' => _devResults(DevInput.fromJson(j), appraiseDev(DevInput.fromJson(j))),
          _ => _btlResults(BtlInput.fromJson(j), appraiseBtl(BtlInput.fromJson(j))),
        },
      );
      if (c.maxWidth < 800) return Column(children: [results, const SizedBox(height: 12), form]);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: form),
          const SizedBox(width: 12),
          Expanded(child: results),
        ],
      );
    },
  );

  Widget _num(String path, String label, Unit unit, {String? helper}) => NumberInput(
    key: ValueKey('$kind/$generation/$path'),
    value: (_get(j, path) as num?)?.toDouble() ?? 0,
    label: label,
    unit: unit,
    helper: helper,
    onChanged: (v) => put(path, v),
  );

  Widget _nation() => Choice(
    label: 'Where',
    value: Nation.values.byName(j['nation'] as String),
    options: {for (final n in Nation.values) n: n.label},
    onChanged: (v) => put('nation', v.name),
  );

  Widget _buyer() => Choice(
    label: 'Buyer',
    value: BuyerType.values.byName(j['buyer'] as String),
    options: {for (final b in BuyerType.values) b: b.label},
    onChanged: (v) => put('buyer', v.name),
  );

  List<Widget> _mortgage({bool interestOnlyChoice = true}) => [
    _num('mortgage.depositPct', 'Deposit', Unit.percent),
    _num('mortgage.rate', 'Mortgage rate', Unit.percent),
    _num('mortgage.years', 'Term in years', Unit.number),
    _num('mortgage.fee', 'Arrangement fee', Unit.pounds),
    if (interestOnlyChoice)
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Interest only'),
        value: _get(j, 'mortgage.interestOnly') == true,
        onChanged: (v) => put('mortgage.interestOnly', v),
      ),
  ];

  List<Widget> _btlForm() => [
    _num('price', 'Price', Unit.pounds),
    _nation(),
    _buyer(),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Buyer lives outside the UK'),
      value: j['nonResident'] == true,
      onChanged: (v) => put('nonResident', v),
    ),
    ..._mortgage(),
    _num('legal', 'Legal fees', Unit.pounds),
    _num('survey', 'Survey', Unit.pounds),
    _num('refurb', 'Works before letting', Unit.pounds),
    _num('rent', 'Rent a month', Unit.pounds),
    _num('voidWeeks', 'Empty weeks a year', Unit.number),
    _num('agentPct', 'Agent fee', Unit.percent, helper: 'Share of rent, with VAT'),
    _num('maintenancePct', 'Repairs', Unit.percent, helper: 'Share of rent'),
    _num('insurance', 'Insurance a year', Unit.pounds),
    _num('serviceCharge', 'Service charge and ground rent a year', Unit.pounds),
    _num('otherCosts', 'Other costs a year', Unit.pounds, helper: 'Certificates, registration, accountant'),
    Choice(
      label: 'Owned by',
      value: Ownership.values.byName(j['ownership'] as String),
      options: {for (final o in Ownership.values) o: o.label},
      onChanged: (v) => put('ownership', v.name),
    ),
    if (j['ownership'] == Ownership.personal.name)
      Choice(
        label: 'Your income tax rate',
        value: propertyIncomeRates.containsValue(j['taxRate'])
            ? (j['taxRate'] as num).toDouble()
            : financeCreditRate,
        options: {for (final e in propertyIncomeRates.entries) e.value: e.key},
        onChanged: (v) => put('taxRate', v),
      ),
    _num('icr', 'Lender interest cover', Unit.percent, helper: 'Often 125%; 145% for higher-rate taxpayers'),
    _num('stressRate', 'Lender stress rate', Unit.percent),
    _num('growth', 'Price growth a year', Unit.percent),
    _num('years', 'Years to look ahead', Unit.number),
  ];

  List<Widget> _homeForm() => [
    _num('price', 'Price', Unit.pounds),
    _nation(),
    _buyer(),
    ..._mortgage(interestOnlyChoice: false),
    _num('legal', 'Legal fees', Unit.pounds),
    _num('survey', 'Survey', Unit.pounds),
    _num('income', 'Household income a year', Unit.pounds),
    _num('multiple', 'Lender income multiple', Unit.number, helper: 'Usually 4 to 4.5 times'),
    _num('currentRent', 'Rent you pay now', Unit.pounds),
    _num('upkeep', 'Upkeep a year', Unit.pounds),
    _num('insurance', 'Buildings insurance a year', Unit.pounds),
    _num('letRent', 'Rent if you let it later', Unit.pounds, helper: '0 if not planned'),
  ];

  List<Widget> _devForm() {
    final units = (j['units'] as List).cast<Map>();
    return [
      _nation(),
      _num('land', 'Land price', Unit.pounds),
      _num('planning', 'Planning, surveys and contributions', Unit.pounds),
      Text('Homes', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      for (var i = 0; i < units.length; i++)
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TextInput(
                        key: ValueKey('$kind/$generation/units.$i.name'),
                        value: '${units[i]['name']}',
                        label: 'Type',
                        onChanged: (v) => put('units.$i.name', v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close),
                      onPressed: units.length == 1
                          ? null
                          : () => setState(() {
                              inputs[kind] = _normalised(kind, {
                                ...j,
                                'units': [...units]..removeAt(i),
                              });
                              generation++;
                            }),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _num('units.$i.count', 'How many', Unit.number)),
                    const SizedBox(width: 8),
                    Expanded(child: _num('units.$i.sizeM2', 'm² each', Unit.number)),
                    const SizedBox(width: 8),
                    Expanded(child: _num('units.$i.price', 'Sells for', Unit.pounds)),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => put('units', [
            ...units,
            const UnitType(name: 'Apartment', count: 2, sizeM2: 65, price: 160000).toJson(),
          ]),
          icon: const Icon(Icons.add),
          label: const Text('Add a type of home'),
        ),
      ),
      const SizedBox(height: 12),
      _num('buildCostM2', 'Build cost per m²', Unit.pounds, helper: 'From BCIS or a local builder'),
      _num('externalsPct', 'Roads, drainage, gardens', Unit.percent, helper: 'Share of build cost'),
      _num('feesPct', 'Professional fees', Unit.percent, helper: 'Architect, engineer, warranty'),
      _num('contingencyPct', 'Contingency', Unit.percent),
      _num('financeRate', 'Finance rate', Unit.percent),
      _num('buildMonths', 'Months to build', Unit.number),
      _num('saleMonths', 'Months to sell', Unit.number),
      _num('salesPct', 'Sales costs', Unit.percent, helper: 'Agents and legal'),
      _num('targetMargin', 'Target profit on sales', Unit.percent, helper: 'Lenders look for 15–20%'),
    ];
  }

  Widget _btlResults(BtlInput i, BtlResult r) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FigureRow('Cash needed', gbp(r.cashIn), strong: true),
      PurchaseTaxView(r.purchaseTax),
      FigureRow('Loan', gbp(r.loan)),
      const Divider(),
      FigureRow('Rent collected a year', gbp(r.rentCollected)),
      FigureRow('Running costs', '−${gbp(r.runningCosts)}'),
      FigureRow('Mortgage payments', '−${gbp(r.mortgagePayments)}'),
      FigureRow('Tax', '−${gbp(r.tax)}'),
      FigureRow(
        'Cash flow a year',
        gbp(r.cashFlow),
        strong: true,
        status: r.cashFlow >= 0 ? Status.good : Status.critical,
      ),
      FigureRow('A month', gbp(r.monthlyCashFlow)),
      const Divider(),
      FigureRow('Gross yield', percent(r.grossYield)),
      FigureRow('Net yield (before mortgage)', percent(r.netYield)),
      FigureRow('Return on cash', percent(r.cashOnCash)),
      FigureRow('Break-even rent', '${gbp(r.breakEvenRent)} pcm'),
      Hint(
        'invest.icr',
        child: FigureRow(
          'Largest loan the stress test allows',
          gbp(r.maxLoanByIcr),
          status: r.passesStressTest ? Status.good : Status.warning,
        ),
      ),
      const Divider(),
      FigureRow('Value in ${i.years} years', gbp(r.futureValue)),
      FigureRow('Your equity then', gbp(r.futureEquity), strong: true),
      const SizedBox(height: 8),
      Text(
        i.ownership == Ownership.personal
            ? 'Mortgage interest earns a ${percent(financeCreditRate, digits: 0)} tax credit (Section 24). '
                  'Property income rates from April 2027.'
            : 'Company: corporation tax on profit after interest; taking money out is taxed again.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _homeResults(HomeResult r) {
    final i = HomeInput.fromJson(j);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FigureRow('Cash needed', gbp(r.cashIn), strong: true),
        PurchaseTaxView(r.purchaseTax),
        FigureRow('Loan', '${gbp(r.loan)} (${percent(r.ltv, digits: 0)} of the price)'),
        FigureRow(
          'Lenders might lend up to',
          gbp(r.maxLoan),
          status: r.affordable ? Status.good : Status.warning,
        ),
        const Divider(),
        FigureRow('Mortgage a month', gbp(r.monthly), strong: true),
        FigureRow('If rates rose 3 points', gbp(r.stressedMonthly)),
        FigureRow('Cost of owning a month', gbp(r.monthlyOwnCost)),
        FigureRow('Rent you pay now', gbp(i.currentRent)),
        Text(
          'The cost of owning is interest, upkeep and insurance: the part of the payment that is not saving.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (i.letRent > 0) ...[
          const Divider(),
          FigureRow('Gross yield if let', percent(r.letGrossYield)),
          FigureRow(
            'Rent over stressed interest',
            percent(r.letStressCover, digits: 0),
            status: r.letStressCover >= 1.25 ? Status.good : Status.warning,
          ),
          Text(
            'Letting a home with a residential mortgage needs the lender\'s consent to let, or a buy-to-let remortgage.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _devResults(DevInput i, DevResult r) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FigureRow('Sales (GDV)', gbp(r.gdv), strong: true),
      FigureRow('Floor area', '${r.areaM2.round()} m²'),
      const Divider(),
      FigureRow('Land', gbp(i.land)),
      FigureRow('Tax on the land', gbp(r.landTax)),
      FigureRow('Planning and surveys', gbp(i.planning)),
      FigureRow('Building, with fees and contingency', gbp(r.build)),
      FigureRow('Finance', gbp(r.finance)),
      FigureRow('Sales costs', gbp(r.sales)),
      FigureRow('Total cost', gbp(r.totalCost), strong: true),
      const Divider(),
      FigureRow('Profit', gbp(r.profit), strong: true, status: r.profit >= 0 ? Status.good : Status.critical),
      FigureRow(
        'Profit on sales',
        percent(r.marginOnGdv),
        status: r.marginOnGdv >= i.targetMargin ? Status.good : Status.warning,
      ),
      FigureRow('Profit on cost', percent(r.marginOnCost)),
      Hint(
        'invest.residual',
        child: FigureRow(
          'Most to pay for the land',
          r.residualLand <= 0 ? 'Does not work' : gbp(r.residualLand),
          strong: true,
        ),
      ),
    ],
  );

  Widget _savedList() => AsyncView(
    ref.watch(appraisalsProvider),
    builder: (list) => list.isEmpty
        ? const EmptyState(
            icon: Icons.bookmarks_outlined,
            title: 'Nothing saved',
            message: 'Save an appraisal to keep it here.',
          )
        : Column(
            children: [
              for (final a in list)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(a.name),
                    subtitle: Text('${_kinds[a.kind] ?? a.kind} · ${niceDate(a.updated)}'),
                    onTap: () => setState(() {
                      kind = _kinds.containsKey(a.kind) ? a.kind : 'btl';
                      inputs[kind] = _normalised(kind, (jsonDecode(a.inputs) as Map).cast());
                      current = a;
                      saved = false;
                      generation++;
                    }),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref.mutate((s) => s.book.remove(s.db.appraisals, a.id));
                        if (current?.id == a.id) setState(() => current = null);
                      },
                    ),
                  ),
                ),
            ],
          ),
  );

  Future<void> _save() async {
    final name = TextEditingController(text: current?.kind == kind ? current!.name : '');
    final reuse = current?.kind == kind;
    await showFormDialog(
      context,
      title: 'Save appraisal',
      fields: (_) => [Field(name, 'Name', autofocus: true, hint: 'Two-bed flat, Main Street')],
      onSave: () async {
        if (name.text.trim().isEmpty) return 'Enter a name.';
        final id = reuse ? current!.id : newId();
        await ref.mutate(
          (s) => s.book.save(
            s.db.appraisals,
            AppraisalsCompanion(
              id: Value(id),
              name: Value(name.text.trim()),
              kind: Value(kind),
              propertyId: Value(reuse ? current!.propertyId : widget.propertyId),
              inputs: Value(jsonEncode(j)),
              updated: Value(today()),
            ),
            id,
          ),
        );
        final rows = await ref.read(appraisalsProvider.future);
        if (mounted) setState(() => current = rows.where((a) => a.id == id).firstOrNull);
        return null;
      },
    );
  }
}

/// A purchase tax total with how it is worked out.
class PurchaseTaxView extends StatelessWidget {
  const PurchaseTaxView(this.t, {super.key});
  final PurchaseTax t;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: FigureRow(t.name, gbp(t.total)),
        children: [
          for (final s in t.slices)
            if (s.to > s.from)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${gbp(s.from)} to ${gbp(s.to)} at ${percent(s.rate)}: ${gbp(s.tax)}',
                  style: small?.merge(tabular),
                ),
              ),
          if (t.extra > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${t.extraLabel}: ${gbp(t.extra)}', style: small),
            ),
          if (t.note.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(t.note, style: small),
            ),
        ],
      ),
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({super.key, required this.value, required this.label, required this.onChanged});
  final String value, label;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: widget.onChanged,
    ),
  );
}
