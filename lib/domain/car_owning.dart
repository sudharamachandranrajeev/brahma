import 'dart:convert';

import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart' show Value;

import '../db/database.dart';
import 'tax.dart';

/// What a logbook entry records. [unit] names its amount, when it has one.
enum LogKind {
  fuel('Fuel', 'litres'),
  charge('Charging', 'kWh'),
  service('Service', null),
  repair('Repair', null),
  mot('MOT', null),
  tyres('Tyres', 'mm tread'),
  insurance('Insurance', null),
  tax('Road tax', null),
  valuation('Valuation or offer', null),
  other('Other', null);

  const LogKind(this.label, this.unit);
  final String label;
  final String? unit;

  static LogKind of(String name) => values.where((k) => k.name == name).firstOrNull ?? other;

  /// Counts towards the cost of running the car (a valuation does not).
  bool get isCost => this != valuation;
}

/// Signed days from [from] to [to] (negative when [to] is earlier).
int daysUntil(String from, String to) => (to.compareTo(from) < 0 ? -1 : 1) * daysBetween(from, to);

// Deadlines --------------------------------------------------------------

enum DueKind {
  mot('MOT', 'Driving without a valid MOT: fine up to £1,000.'),
  tax('Road tax', 'Untaxed: £80 penalty, up to £1,000 at court. Tax does not pass to a new owner.'),
  insurance('Insurance', 'Uninsured: £300 fixed penalty and 6 points. Check auto-renewal and shop around.'),
  service('Service', 'Missed services weaken the service history buyers ask for.');

  const DueKind(this.label, this.risk);
  final String label, risk;
}

class Deadline {
  const Deadline(this.kind, this.date, this.days, {this.estimated = false});
  final DueKind kind;
  final String date;

  /// Days left; negative when overdue.
  final int days;

  /// Worked out (first MOT from registration) rather than entered.
  final bool estimated;

  bool get overdue => days < 0;
  bool get soon => days <= 30;
}

/// The first MOT: three years after first registration in Great Britain, four
/// for a car in Northern Ireland.
String firstMotDue(String firstRegistered, Nation? nation) =>
    addMonths(firstRegistered, nation == Nation.northernIreland ? 48 : 36);

/// When the next MOT falls due after a pass on [tested]. In Great Britain a
/// test up to a month (less a day) early keeps the old date a year on; in
/// Northern Ireland, and otherwise, it runs a year from the test.
String nextMotDue(String tested, {String? previousDue, Nation? nation}) {
  if (previousDue != null &&
      nation != Nation.northernIreland &&
      tested.compareTo(addDays(addMonths(previousDue, -1), 1)) >= 0 &&
      tested.compareTo(previousDue) <= 0) {
    return addMonths(previousDue, 12);
  }
  return addMonths(tested, 12);
}

/// The car's dates, soonest first.
List<Deadline> deadlines(Vehicle v, {Nation? nation, required String today}) {
  final mot = v.motDue ?? (v.firstRegistered == null ? null : firstMotDue(v.firstRegistered!, nation));
  return [
    if (mot != null) Deadline(DueKind.mot, mot, daysUntil(today, mot), estimated: v.motDue == null),
    if (v.taxDue != null) Deadline(DueKind.tax, v.taxDue!, daysUntil(today, v.taxDue!)),
    if (v.insuranceDue != null)
      Deadline(DueKind.insurance, v.insuranceDue!, daysUntil(today, v.insuranceDue!)),
    if (v.serviceDue != null) Deadline(DueKind.service, v.serviceDue!, daysUntil(today, v.serviceDue!)),
  ]..sort((a, b) => a.date.compareTo(b.date));
}

/// The car with the due date a new log entry moves on: an MOT pass, a
/// service, a renewed policy or tax.
Vehicle afterLog(Vehicle v, LogKind kind, String date, {Nation? nation}) => switch (kind) {
  LogKind.mot => v.copyWith(
    motDue: Value(nextMotDue(date, previousDue: v.motDue, nation: nation)),
  ),
  LogKind.service => v.copyWith(serviceDue: Value(addMonths(date, 12))),
  // A renewal logged ahead of the old date runs on from it.
  LogKind.insurance => v.copyWith(insuranceDue: Value(_renewed(v.insuranceDue, date))),
  LogKind.tax => v.copyWith(taxDue: Value(_renewed(v.taxDue, date))),
  _ => v,
};

String _renewed(String? due, String date) =>
    due != null && date.compareTo(due) <= 0 && daysUntil(date, due) <= 60
    ? addMonths(due, 12)
    : addMonths(date, 12);

/// A Google Calendar link that adds an all-day reminder; it opens in the
/// browser or the calendar app, so no notifications are needed here.
Uri calendarLink(String title, String date, {String details = ''}) {
  final d = date.replaceAll('-', '');
  final next = addDays(date, 1).replaceAll('-', '');
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '$d/$next',
    'details': details,
  });
}

// Rights after buying -------------------------------------------------------

/// What the law gives the buyer of [v], with the dates that matter.
List<String> buyerRights(Vehicle v, String today) {
  final bought = v.boughtOn;
  if (bought == null) return const [];
  if (v.sellerType == 'private') {
    return const [
      'Private sale: the car must match its description and be the seller\'s to sell. Keep the advert '
          'and messages.',
    ];
  }
  final reject = addDays(bought, 30);
  final six = addMonths(bought, 6);
  return [
    if (today.compareTo(reject) <= 0)
      'Right to reject a faulty car for a full refund until ${niceDate(reject)} '
          '(${daysUntil(today, reject)} days).',
    if (today.compareTo(six) <= 0)
      'Until ${niceDate(six)} a fault is presumed to have been there at sale: the dealer must repair or '
          'replace it, then refund or reduce the price if that fails.',
    if (today.compareTo(six) > 0)
      'After six months you can still claim (up to six years) but must show the fault was there at sale.',
    if (v.sellerType == 'store') 'Bought online or by phone: 14 days to cancel from delivery, as well.',
  ];
}

// The logbook in figures ------------------------------------------------------

class CarStats {
  const CarStats({
    required this.spentThisYear,
    required this.spentTotal,
    this.perMile,
    this.mpg,
    this.milesPerKwh,
    this.lastOdometer,
    this.insuranceChange,
    this.tread,
    this.latestValue,
  });

  /// Pounds, by calendar year to date and in all.
  final double spentThisYear, spentTotal;

  /// Pounds a mile over the miles the log covers.
  final double? perMile;

  /// Real economy from fill-ups (full tank to full tank).
  final double? mpg, milesPerKwh;
  final int? lastOdometer;

  /// Last insurance premium against the one before, as a fraction.
  final double? insuranceChange;

  /// Lowest tread at the last tyre check, mm.
  final double? tread;

  /// The latest valuation or offer, pounds.
  final int? latestValue;
}

CarStats carStats(List<CarLog> logs, {required String today}) {
  final byDate = [...logs]..sort((a, b) => a.date.compareTo(b.date));
  double pounds(CarLog l) => (l.costPence ?? 0) / 100;
  final costs = byDate.where((l) => LogKind.of(l.kind).isCost);
  final spentTotal = costs.fold(0.0, (a, l) => a + pounds(l));
  final spentThisYear = costs
      .where((l) => l.date.substring(0, 4) == today.substring(0, 4))
      .fold(0.0, (a, l) => a + pounds(l));
  final odo = byDate.where((l) => l.odometer != null).map((l) => l.odometer!).toList();
  final miles = odo.length < 2
      ? 0
      : odo.reduce((a, b) => a > b ? a : b) - odo.reduce((a, b) => a < b ? a : b);

  // Economy: miles between fill-ups over what the later one took.
  double? economy(LogKind kind, double perUnit) {
    final fills = byDate
        .where((l) => LogKind.of(l.kind) == kind && l.odometer != null && (l.amount ?? 0) > 0)
        .toList();
    if (fills.length < 2) return null;
    final distance = fills.last.odometer! - fills.first.odometer!;
    final used = fills.skip(1).fold(0.0, (a, l) => a + l.amount!);
    return distance <= 0 || used <= 0 ? null : distance / (used / perUnit);
  }

  final premiums = byDate
      .where((l) => LogKind.of(l.kind) == LogKind.insurance && (l.costPence ?? 0) > 0)
      .toList();
  final tyres = byDate.where((l) => LogKind.of(l.kind) == LogKind.tyres && l.amount != null).toList();
  final values = byDate.where((l) => LogKind.of(l.kind) == LogKind.valuation && l.costPence != null).toList();
  return CarStats(
    spentThisYear: spentThisYear,
    spentTotal: spentTotal,
    perMile: miles > 0 ? spentTotal / miles : null,
    mpg: economy(LogKind.fuel, 4.54609),
    milesPerKwh: economy(LogKind.charge, 1),
    lastOdometer: odo.isEmpty ? null : odo.last,
    insuranceChange: premiums.length < 2
        ? null
        : premiums.last.costPence! / premiums[premiums.length - 2].costPence! - 1,
    tread: tyres.isEmpty ? null : tyres.last.amount,
    latestValue: values.isEmpty ? null : (values.last.costPence! / 100).round(),
  );
}

/// Legal minimum tread, and the depth worth replacing at.
const legalTread = 1.6, adviseTread = 3.0;

// PCP mileage ---------------------------------------------------------------

/// A PCP's mileage allowance, kept in the car's meta under "pcp".
class PcpAllowance {
  const PcpAllowance({
    required this.start,
    required this.end,
    required this.milesPerYear,
    required this.startMiles,
    this.pencePerMile = 10,
  });

  final String start, end;
  final int milesPerYear, startMiles;
  final double pencePerMile;

  static PcpAllowance? fromMeta(String meta) {
    final j = (jsonDecode(meta) as Map)['pcp'];
    if (j is! Map) return null;
    return PcpAllowance(
      start: '${j['start']}',
      end: '${j['end']}',
      milesPerYear: (j['milesPerYear'] as num).round(),
      startMiles: (j['startMiles'] as num).round(),
      pencePerMile: (j['pencePerMile'] as num?)?.toDouble() ?? 10,
    );
  }

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'milesPerYear': milesPerYear,
    'startMiles': startMiles,
    'pencePerMile': pencePerMile,
  };

  int get termDays => daysUntil(start, end);

  /// Miles allowed by [today], miles driven, and what the end looks like at
  /// the pace so far.
  ({int allowed, int driven, int projected, int allowedTotal, double excessCost}) pace(
    int odometer,
    String today,
  ) {
    final total = (milesPerYear * termDays / 365).round();
    final elapsed = daysUntil(start, today).clamp(0, termDays);
    final driven = odometer - startMiles;
    final projected = elapsed == 0 ? driven : (driven * termDays / elapsed).round();
    final over = projected - total;
    return (
      allowed: (total * elapsed / (termDays == 0 ? 1 : termDays)).round(),
      driven: driven,
      projected: projected,
      allowedTotal: total,
      excessCost: over > 0 ? over * pencePerMile / 100 : 0,
    );
  }
}

/// The logbook as plain text, for an advert or a buyer.
String serviceHistory(Vehicle v, List<CarLog> logs) {
  final kept = logs.where((l) => const {'service', 'repair', 'mot', 'tyres'}.contains(l.kind)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return [
    '${v.title}${v.registration.isEmpty ? '' : ' (${v.registration})'}: service and repair history',
    for (final l in kept)
      [
        niceDate(l.date),
        LogKind.of(l.kind).label,
        if (l.odometer != null) '${l.odometer} miles',
        if (l.provider.isNotEmpty) l.provider,
        if (l.notes.isNotEmpty) l.notes,
      ].join(' · '),
    if (kept.isEmpty) 'No services or repairs logged.',
  ].join('\n');
}
