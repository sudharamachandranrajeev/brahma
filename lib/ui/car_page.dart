import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../db/database.dart';
import '../domain/car_buying.dart';
import '../domain/car_owning.dart';
import '../domain/pipeline.dart';
import '../domain/nation.dart';
import '../domain/vehicles.dart';
import 'cars_page.dart';
import 'common.dart';
import 'look.dart';

const _govLinks = <(String, String)>[
  ('Vehicle check (tax, MOT, make, colour)', 'https://vehicleenquiry.service.gov.uk/'),
  ('MOT history', 'https://www.check-mot.service.gov.uk/'),
  ('Recalls', 'https://www.check-vehicle-recalls.service.gov.uk/'),
];

/// One car: its dates, the checks for each stage, its logbook and its sale.
class CarPage extends ConsumerWidget {
  const CarPage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(vehiclesProvider);
    final v = all.value?.where((v) => v.id == id).firstOrNull;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: all.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const EmptyState(icon: Icons.directions_car_outlined, title: 'This car was removed'),
      );
    }
    final cars = all.value!;
    final logs = (ref.watch(carLogsProvider).value ?? const <CarLog>[])
        .where((l) => l.vehicleId == id)
        .toList();
    final nation = ref.watch(carSearchProvider).value?.nation;
    final day = today();
    final bought = v.boughtOn != null;
    final sold = v.soldOn != null;
    return PageScaffold(
      title: v.title,
      actions: [
        if (v.url.isNotEmpty)
          IconButton(
            tooltip: 'Open the advert',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => openUri(context, Uri.parse(v.url)),
          ),
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => editVehicle(context, ref, v: v),
        ),
        IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _remove(context, ref, v),
        ),
      ],
      children: [
        FigureCard(
          eyebrow: [
            carStageLabel(Stage.of(v.stage)),
            if (v.registration.isNotEmpty) v.registration,
          ].join(' · '),
          value: v.price == null ? '–' : gbp(v.price!),
          caption: v.title,
          detail: [vehicleFacts(v), v.location].where((s) => s.isNotEmpty).join(' · '),
        ),
        if (deadlines(v, nation: nation, today: day) case final dates when dates.isNotEmpty)
          StatStrip([
            for (final d in dates)
              StatTile(
                d.kind.label,
                d.overdue
                    ? '${-d.days}d late'
                    : d.days == 0
                    ? 'Today'
                    : '${d.days}d',
                detail: niceDate(d.date),
                alert: d.soon,
              ),
          ]),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in Stage.values)
              ChoiceChip(
                label: Text(carStageLabel(s)),
                selected: Stage.of(v.stage) == s,
                onSelected: (_) => ref.mutate((x) => x.book.setVehicleStage(v, s)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _Dates(v, nation, day),
        if (!bought) _Looking(v, cars, day) else _Owned(v, logs, nation, day),
        if (bought) ...[_Logbook(v, logs, nation, day), _Selling(v, logs)],
        if (sold) const SizedBox.shrink(),
      ],
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${v.title}?'),
        content: const Text('Its logbook goes too.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.mutate((s) => s.book.removeVehicle(v.id));
    if (context.mounted) Navigator.pop(context);
  }
}

/// Ticks for a checklist, kept in the car's meta.
class _Checks extends ConsumerWidget {
  const _Checks(this.v, this.list);
  final Vehicle v;
  final Checklist list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = list.done(v);
    return SectionCard(
      title: list.title,
      trailing: Text('${done.length} of ${list.items.length}'),
      child: Column(
        children: [
          for (final c in list.items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: done.contains(c.id),
              title: Text(c.title),
              subtitle: Text(c.body),
              onChanged: (on) {
                final next = {...done};
                on == true ? next.add(c.id) : next.remove(c.id);
                ref.mutate((x) => x.book.setVehicleMeta(v, {list.id: next.toList()}));
              },
            ),
        ],
      ),
    );
  }
}

// Dates ---------------------------------------------------------------------

class _Dates extends ConsumerWidget {
  const _Dates(this.v, this.nation, this.day);
  final Vehicle v;
  final Nation? nation;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = deadlines(v, nation: nation, today: day);
    return SectionCard(
      title: 'Dates that matter',
      hint: 'cars.dates',
      trailing: TextButton.icon(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('Set'),
      ),
      child: list.isEmpty
          ? const Text(
              'Add the MOT, tax, insurance and service dates, or the date first registered (the first MOT '
              'follows). They show here and on the Garage list as they come close.',
            )
          : Column(
              children: [
                for (final d in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      d.overdue
                          ? Icons.error_outline
                          : d.soon
                          ? Icons.warning_amber_rounded
                          : Icons.event_available_outlined,
                      color: d.overdue
                          ? Status.critical.color
                          : d.soon
                          ? Status.warning.color
                          : Status.good.color,
                    ),
                    title: Text('${d.kind.label}: ${niceDate(d.date)}${d.estimated ? ' (worked out)' : ''}'),
                    subtitle: Text(
                      '${d.overdue
                          ? '${-d.days} days overdue'
                          : d.days == 0
                          ? 'Today'
                          : 'In ${d.days} days'}. '
                      '${d.overdue || d.soon ? d.kind.risk : ''}'
                      '${d.kind == DueKind.mot && nation == Nation.northernIreland && d.soon ? ' Northern Ireland test slots can be weeks away: book now.' : ''}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Add a reminder to your calendar',
                      icon: const Icon(Icons.notifications_active_outlined),
                      onPressed: () => openUri(
                        context,
                        calendarLink(
                          '${d.kind.label} due: ${v.title}',
                          addDays(d.date, d.kind == DueKind.mot ? -14 : -7),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) {
    final c = {
      'reg': TextEditingController(text: v.registration),
      'first': TextEditingController(text: v.firstRegistered),
      'mot': TextEditingController(text: v.motDue),
      'tax': TextEditingController(text: v.taxDue),
      'ins': TextEditingController(text: v.insuranceDue),
      'svc': TextEditingController(text: v.serviceDue),
    };
    return showFormDialog(
      context,
      title: 'Dates',
      fields: (_) => [
        Field(c['reg']!, 'Registration'),
        Field(
          c['first']!,
          'First registered',
          hint: 'yyyy-mm-dd',
          helper: 'Sets the first MOT: 3 years (4 in Northern Ireland).',
        ),
        Field(c['mot']!, 'MOT expires', hint: 'yyyy-mm-dd'),
        Field(c['tax']!, 'Road tax expires', hint: 'yyyy-mm-dd'),
        Field(c['ins']!, 'Insurance renews', hint: 'yyyy-mm-dd'),
        Field(c['svc']!, 'Next service', hint: 'yyyy-mm-dd'),
      ],
      onSave: () async {
        String? date(String key) => c[key]!.text.trim().isEmpty ? null : c[key]!.text.trim();
        for (final k in ['first', 'mot', 'tax', 'ins', 'svc']) {
          final d = date(k);
          if (d != null && !isValidIsoDate(d)) return 'Write dates as yyyy-mm-dd, e.g. 2027-03-14.';
        }
        await ref.mutate(
          (s) => s.book.save(
            s.db.vehicles,
            v.copyWith(
              registration: c['reg']!.text.trim().toUpperCase(),
              firstRegistered: Value(date('first')),
              motDue: Value(date('mot')),
              taxDue: Value(date('tax')),
              insuranceDue: Value(date('ins')),
              serviceDue: Value(date('svc')),
            ),
            v.id,
          ),
        );
        return null;
      },
    );
  }
}

// Before buying ---------------------------------------------------------------

class _Looking extends ConsumerWidget {
  const _Looking(this.v, this.cars, this.day);
  final Vehicle v;
  final List<Vehicle> cars;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = fairPrice(v, cars);
    final flags = redFlags(v, cars, thisYear: int.parse(day.substring(0, 4)));
    final history = priceHistory(v);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (price != null || history.length > 1 || flags.isNotEmpty)
          SectionCard(
            title: 'Worth a second look',
            hint: 'cars.flags',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (price != null)
                  FigureRow(
                    'Against ${price.count} similar cars you saved (median ${gbp(price.median)})',
                    '${price.diff >= 0 ? '+' : ''}${(price.diff * 100).round()}%',
                    status: price.diff <= -0.25 ? Status.warning : null,
                  ),
                if (history.length > 1)
                  FigureRow(
                    'Asking price changed',
                    history.map((p) => gbp(p.price)).join(' → '),
                    status: history.last.price < history.first.price ? Status.good : null,
                  ),
                for (final f in flags)
                  Padding(padding: const EdgeInsets.only(top: 8), child: StatusLabelWrap(f)),
              ],
            ),
          ),
        SectionCard(
          title: 'Free official checks',
          child: Column(
            children: [
              for (final (label, link) in _govLinks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(label),
                  subtitle: v.registration.isEmpty ? null : Text('Registration ${v.registration}'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => openUri(context, Uri.parse(link)),
                ),
              Text('Scam or fraud? Report it to Action Fraud: 0300 123 2040.', style: t.bodySmall),
            ],
          ),
        ),
        _Checks(v, buyChecks),
        SectionCard(
          title: 'Bought it?',
          child: Row(
            children: [
              const Expanded(child: Text('Mark it bought to start its logbook, dates and rights.')),
              FilledButton(
                onPressed: () => ref.mutate((x) => x.book.setVehicleStage(v, Stage.agreed)),
                child: const Text('I bought it'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A warning line with its icon, wrapping.
class StatusLabelWrap extends StatelessWidget {
  const StatusLabelWrap(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Status.warning.icon, size: 18, color: Status.warning.color),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

// Owned -----------------------------------------------------------------------

class _Owned extends ConsumerWidget {
  const _Owned(this.v, this.logs, this.nation, this.day);
  final Vehicle v;
  final List<CarLog> logs;
  final Nation? nation;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rights = buyerRights(v, day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Your rights as the buyer',
          trailing: TextButton(
            onPressed: () async {
              final d = TextEditingController(text: v.boughtOn);
              await showFormDialog(
                context,
                title: 'Bought on',
                fields: (_) => [Field(d, 'Date', hint: 'yyyy-mm-dd')],
                onSave: () async {
                  if (!isValidIsoDate(d.text.trim())) return 'Write the date as yyyy-mm-dd.';
                  await ref.mutate(
                    (s) => s.book.save(s.db.vehicles, v.copyWith(boughtOn: Value(d.text.trim())), v.id),
                  );
                  return null;
                },
              );
            },
            child: Text('Bought ${niceDate(v.boughtOn!)}'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in rights) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(r)),
            ],
          ),
        ),
        if (daysUntil(v.boughtOn!, day) <= 30 || collectChecks.done(v).isNotEmpty) _Checks(v, collectChecks),
      ],
    );
  }
}

// Logbook ---------------------------------------------------------------------

class _Logbook extends ConsumerWidget {
  const _Logbook(this.v, this.logs, this.nation, this.day);
  final Vehicle v;
  final List<CarLog> logs;
  final Nation? nation;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = carStats(logs, today: day);
    final pcp = PcpAllowance.fromMeta(v.meta);
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Running it',
          hint: 'cars.logbook',
          child: Column(
            children: [
              if (logs.isEmpty)
                const Text(
                  'Log fuel, services, repairs, the MOT, insurance and tyres. Totals and the dates above follow.',
                )
              else ...[
                StatStrip([
                  StatTile('This year', gbp(st.spentThisYear)),
                  StatTile('In all', gbp(st.spentTotal)),
                  if (st.perMile != null)
                    StatTile(
                      'A mile',
                      '${(st.perMile! * 100).toStringAsFixed(1)}p',
                      detail: 'over the miles logged',
                    ),
                  if (st.mpg != null) StatTile('Real economy', '${st.mpg!.toStringAsFixed(1)} mpg'),
                  if (st.milesPerKwh != null)
                    StatTile('Real economy', '${st.milesPerKwh!.toStringAsFixed(1)} mi/kWh'),
                ]),
                if (st.insuranceChange != null)
                  FigureRow(
                    'Insurance against last time',
                    '${st.insuranceChange! >= 0 ? '+' : ''}${(st.insuranceChange! * 100).round()}%',
                    status: st.insuranceChange! > 0.1 ? Status.warning : null,
                  ),
                if (st.tread != null)
                  FigureRow(
                    'Tyre tread at the last check',
                    '${st.tread!.toStringAsFixed(1)} mm',
                    status: st.tread! <= legalTread
                        ? Status.critical
                        : st.tread! <= adviseTread
                        ? Status.warning
                        : Status.good,
                  ),
              ],
              if (st.insuranceChange != null && st.insuranceChange! > 0.1)
                Text(
                  'Renewal prices cannot be higher than a new customer\'s for the same cover: get quotes and '
                  'quote that back.',
                  style: t.bodySmall,
                ),
              if (st.tread != null && st.tread! <= adviseTread)
                Text(
                  st.tread! <= legalTread
                      ? 'At or under the legal 1.6 mm: up to £2,500 and 3 points per tyre.'
                      : 'Under 3 mm: stopping distances grow. Plan new tyres.',
                  style: t.bodySmall,
                ),
            ],
          ),
        ),
        if (pcp != null && st.lastOdometer != null) _PcpPace(pcp, st.lastOdometer!, day),
        SectionCard(
          title: 'Logbook',
          trailing: Wrap(
            children: [
              if (pcp == null)
                TextButton(onPressed: () => _pcp(context, ref), child: const Text('PCP miles')),
              TextButton.icon(
                onPressed: () => _add(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          child: logs.isEmpty
              ? const Text('Nothing yet.')
              : Column(
                  children: [
                    for (final l in logs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          '${LogKind.of(l.kind).label}${l.provider.isEmpty ? '' : ' · ${l.provider}'}'
                          '${l.costPence == null ? '' : ' · ${gbp(l.costPence! / 100)}'}',
                        ),
                        subtitle: Text(
                          [
                            niceDate(l.date),
                            if (l.odometer != null) '${l.odometer} miles',
                            if (l.amount != null && LogKind.of(l.kind).unit != null)
                              '${l.amount} ${LogKind.of(l.kind).unit}',
                            if (l.notes.isNotEmpty) l.notes,
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref.mutate((s) => s.book.remove(s.db.carLogs, l.id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) {
    var kind = LogKind.fuel;
    final date = TextEditingController(text: day);
    final odo = TextEditingController(text: v.mileage?.toString());
    final cost = TextEditingController(), amount = TextEditingController();
    final who = TextEditingController(), notes = TextEditingController();
    return showFormDialog(
      context,
      title: 'Add to the logbook',
      fields: (setState) => [
        Choice<LogKind>(
          label: 'What',
          value: kind,
          options: {for (final k in LogKind.values) k: k.label},
          onChanged: (k) => setState(() => kind = k),
        ),
        Field(date, 'Date', hint: 'yyyy-mm-dd'),
        Row(
          children: [
            Expanded(child: Field(odo, 'Miles on the clock', number: true)),
            const SizedBox(width: 12),
            Expanded(child: Field(cost, 'Cost', number: true, prefix: '£')),
          ],
        ),
        if (kind.unit != null) Field(amount, kind.unit!, number: true),
        Field(who, switch (kind) {
          LogKind.insurance => 'Insurer',
          LogKind.fuel || LogKind.charge => 'Station',
          LogKind.valuation => 'Who offered',
          _ => 'Garage or supplier',
        }),
        Field(notes, 'Notes', lines: 2),
        if (const {LogKind.mot, LogKind.service, LogKind.insurance, LogKind.tax}.contains(kind))
          Text(switch (kind) {
            LogKind.mot =>
              'Moves the MOT date on a year${nation == Nation.northernIreland ? '' : ' (keeping the old date if done within a month before it)'}.',
            LogKind.service => 'Sets the next service a year on.',
            _ => 'Moves the renewal date on a year.',
          }, style: Theme.of(context).textTheme.bodySmall),
      ],
      onSave: () async {
        if (!isValidIsoDate(date.text.trim())) return 'Write the date as yyyy-mm-dd.';
        final pounds = numberIn(cost);
        await ref.mutate(
          (s) => s.book.addCarLog(
            v,
            kind: kind,
            date: date.text.trim(),
            odometer: intIn(odo),
            costPence: pounds == null ? null : (pounds * 100).round(),
            amount: numberIn(amount)?.toDouble(),
            provider: who.text.trim(),
            notes: notes.text.trim(),
            nation: nation,
          ),
        );
        return null;
      },
    );
  }

  Future<void> _pcp(BuildContext context, WidgetRef ref) {
    final start = TextEditingController(text: v.boughtOn), end = TextEditingController();
    final perYear = TextEditingController(text: '8000'),
        startMiles = TextEditingController(text: v.mileage?.toString());
    final pence = TextEditingController(text: '10');
    return showFormDialog(
      context,
      title: 'PCP mileage allowance',
      fields: (_) => [
        Field(start, 'Agreement starts', hint: 'yyyy-mm-dd'),
        Field(end, 'Agreement ends', hint: 'yyyy-mm-dd'),
        Field(perYear, 'Allowed miles a year', number: true),
        Field(startMiles, 'Miles on the clock at the start', number: true),
        Field(
          pence,
          'Excess charge',
          number: true,
          suffix: 'p a mile',
          helper: 'Typically 3–30p; in your contract.',
        ),
      ],
      onSave: () async {
        if (!isValidIsoDate(start.text.trim()) || !isValidIsoDate(end.text.trim())) {
          return 'Write both dates as yyyy-mm-dd.';
        }
        if (end.text.trim().compareTo(start.text.trim()) <= 0) return 'The end must come after the start.';
        final p = PcpAllowance(
          start: start.text.trim(),
          end: end.text.trim(),
          milesPerYear: intIn(perYear) ?? 8000,
          startMiles: intIn(startMiles) ?? 0,
          pencePerMile: numberIn(pence)?.toDouble() ?? 10,
        );
        await ref.mutate((s) => s.book.setVehicleMeta(v, {'pcp': p.toJson()}));
        return null;
      },
    );
  }
}

class _PcpPace extends StatelessWidget {
  const _PcpPace(this.p, this.odometer, this.day);
  final PcpAllowance p;
  final int odometer;
  final String day;

  @override
  Widget build(BuildContext context) {
    final pace = p.pace(odometer, day);
    final over = pace.projected - pace.allowedTotal;
    return SectionCard(
      title: 'PCP mileage',
      child: Column(
        children: [
          FigureRow('Allowed so far', '${pace.allowed} miles'),
          FigureRow(
            'Driven so far',
            '${pace.driven} miles',
            status: pace.driven > pace.allowed ? Status.warning : Status.good,
          ),
          FigureRow('At this pace by ${niceDate(p.end)}', '${pace.projected} of ${pace.allowedTotal} miles'),
          FigureRow(
            over > 0 ? 'Projected excess charge' : 'Spare miles',
            over > 0 ? gbp(pace.excessCost) : '${-over} miles',
            strong: true,
            status: over > 0 ? Status.warning : Status.good,
          ),
          Text(
            'Damage is judged against the BVRLA fair wear and tear guide: photograph the car before it goes back.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// Selling -----------------------------------------------------------------------

class _Selling extends ConsumerWidget {
  const _Selling(this.v, this.logs);
  final Vehicle v;
  final List<CarLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = logs.where((l) => l.kind == LogKind.valuation.name && l.costPence != null).toList();
    final spent = carStats(logs, today: today()).spentTotal;
    final sold = v.soldPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: v.soldOn == null ? 'Selling it' : 'Sold ${niceDate(v.soldOn!)}',
          trailing: v.soldOn == null
              ? TextButton(onPressed: () => _sold(context, ref), child: const Text('Mark sold'))
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (offers.isNotEmpty) ...[
                for (final o in offers)
                  FigureRow(
                    '${o.provider.isEmpty ? 'Offer' : o.provider}, ${niceDate(o.date)}',
                    gbp(o.costPence! / 100),
                  ),
                if (offers.length > 1)
                  FigureRow(
                    'Gap between best and worst',
                    gbp(
                      (offers.map((o) => o.costPence!).reduce((a, b) => a > b ? a : b) -
                              offers.map((o) => o.costPence!).reduce((a, b) => a < b ? a : b)) /
                          100,
                    ),
                  ),
              ] else
                const Text(
                  'Log offers and valuations in the logbook (type: Valuation or offer) to see the gap between '
                  'a private sale, a part-exchange and an instant buyer. Instant offers often drop at inspection.',
                ),
              if (sold != null) ...[
                const Divider(),
                FigureRow('Paid', v.price == null ? '–' : gbp(v.price!)),
                FigureRow('Sold for', gbp(sold)),
                FigureRow('Running costs logged', gbp(spent)),
                if (v.price != null)
                  FigureRow('Cost of owning it', gbp(v.price! - sold + spent), strong: true),
                if (v.price != null &&
                    v.boughtOn != null &&
                    v.soldOn != null &&
                    daysUntil(v.boughtOn!, v.soldOn!) > 30)
                  FigureRow(
                    'A month',
                    gbp((v.price! - sold + spent) / (daysUntil(v.boughtOn!, v.soldOn!) / 30.4)),
                  ),
              ],
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => copyText(context, serviceHistory(v, logs), what: 'Service history copied.'),
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy service history for an advert'),
              ),
            ],
          ),
        ),
        _Checks(v, sellChecks),
      ],
    );
  }

  Future<void> _sold(BuildContext context, WidgetRef ref) {
    final date = TextEditingController(text: today()), price = TextEditingController();
    return showFormDialog(
      context,
      title: 'Sold',
      fields: (_) => [
        Field(date, 'Date', hint: 'yyyy-mm-dd'),
        Field(price, 'Sold for', number: true, prefix: '£'),
        const Text('Tell DVLA the same day: the Selling list has the steps.'),
      ],
      onSave: () async {
        if (!isValidIsoDate(date.text.trim())) return 'Write the date as yyyy-mm-dd.';
        await ref.mutate(
          (s) => s.book.save(
            s.db.vehicles,
            v.copyWith(soldOn: Value(date.text.trim()), soldPrice: Value(intIn(price))),
            v.id,
          ),
        );
        return null;
      },
    );
  }
}
