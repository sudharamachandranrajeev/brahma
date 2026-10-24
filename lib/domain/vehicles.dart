import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pipeline.dart';

/// A car advert read from a page, or typed in.
class CarAdvert {
  const CarAdvert({
    required this.url,
    required this.title,
    this.make = '',
    this.model = '',
    this.year,
    this.mileage,
    this.price,
    this.fuel = '',
    this.transmission = '',
    this.body = '',
    this.colour = '',
    this.condition = 'used',
    this.sellerType = 'unknown',
    this.seller = '',
    this.sellerPhone = '',
    this.location = '',
    this.image,
    this.description = '',
  });

  final String url, title, make, model;
  final int? year, mileage, price;
  final String fuel, transmission, body, colour;

  /// used | new
  final String condition;

  /// dealer | private | store | unknown
  final String sellerType;
  final String seller, sellerPhone, location;
  final String? image;
  final String description;

  /// The site, as a host without "www." (autotrader.co.uk, gumtree.com).
  String get source => sourceOf(url);
}

/// The host of [url] without "www.", or "manual" when there is none.
String sourceOf(String url) {
  final host = Uri.tryParse(url.trim())?.host ?? '';
  return host.isEmpty ? 'manual' : host.replaceFirst(RegExp(r'^(www|m)\.'), '');
}

/// The hunt's steps as they read for a car.
String carStageLabel(Stage s) => switch (s) {
  Stage.fresh => 'Found',
  Stage.shortlisted => 'Shortlisted',
  Stage.enquired => 'Contacted',
  Stage.viewing => 'Seen / test drive',
  Stage.applied => 'Offer made',
  Stage.agreed => 'Bought',
  Stage.dropped => 'Not for us',
};

const sellerTypes = {
  'dealer': 'Dealer',
  'private': 'Private seller',
  'store': 'Online store',
  'unknown': 'Not sure',
};

// Reading an advert page --------------------------------------------------

final _ldScript = RegExp(r'<script[^>]*application/ld\+json[^>]*>([\s\S]*?)</script>', caseSensitive: false);
final _metaTag = RegExp(r'<meta\s[^>]*>', caseSensitive: false);
final _attr = RegExp(r'''([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
final _year = RegExp(r'\b(19[5-9]\d|20[0-4]\d)\b');
final _pounds = RegExp(r'£\s?(\d{1,3}(?:,\d{3})+|\d+)');

const _vehicleTypes = {'Car', 'Vehicle', 'Motorcycle', 'MotorizedBicycle', 'BusOrCoach'};

/// Reads a car advert from the schema.org data most listing sites publish
/// for search engines, or failing that the page's link-preview (Open Graph)
/// tags. Throws FormatException when the page has neither.
CarAdvert parseCarAdvert(String html, String url) {
  final ld = _vehicleLd(html);
  final og = _openGraph(html);
  if (ld == null && (og['og:title'] ?? '').isEmpty) {
    throw const FormatException('No advert details on that page (a sign-in or bot check, or not an advert).');
  }
  final j = ld ?? const <String, Object?>{};
  String str(Object? o) => switch (o) {
    String s => _unescape(s.trim()),
    num n => '$n',
    {'name': final Object? n} => str(n),
    List l when l.isNotEmpty => str(l.first),
    _ => '',
  };
  final offer = switch (j['offers']) {
    List l when l.isNotEmpty && l.first is Map => (l.first as Map).cast<String, Object?>(),
    Map m => m.cast<String, Object?>(),
    _ => const <String, Object?>{},
  };
  final sellerObj = switch (offer['seller'] ?? j['seller']) {
    Map m => m.cast<String, Object?>(),
    _ => const <String, Object?>{},
  };
  final title = str(j['name']).isNotEmpty ? str(j['name']) : _unescape(og['og:title'] ?? '');
  final description = str(j['description']).isNotEmpty
      ? str(j['description'])
      : _unescape(og['og:description'] ?? '');
  final price =
      _number(offer['price'] ?? offer['lowPrice']) ??
      _number(og['product:price:amount'] ?? og['og:price:amount']) ??
      _poundsIn(title) ??
      _poundsIn(description);
  final odometer = j['mileageFromOdometer'];
  final distance = _number(odometer is Map ? odometer['value'] : odometer);
  final inKm = odometer is Map && odometer['unitCode'] == 'KMT';
  final mileage = distance != null && inKm ? (distance / 1.609344).round() : distance;
  final yearText = [
    j['vehicleModelDate'],
    j['modelDate'],
    j['productionDate'],
    j['dateVehicleFirstRegistered'],
  ].map(str).firstWhere((s) => s.isNotEmpty, orElse: () => title);
  final condition = str(offer['itemCondition'] ?? j['itemCondition']);
  final sellerKind = str(sellerObj['@type']);
  final image = switch (j['image']) {
    String s => s,
    List l when l.isNotEmpty => str(l.first is Map ? (l.first as Map)['url'] : l.first),
    Map m => str(m['url']),
    _ => og['og:image'],
  };
  final address = sellerObj['address'] ?? (offer['availableAtOrFrom'] as Map?)?['address'];
  return CarAdvert(
    url: url,
    title: title.isEmpty ? sourceOf(url) : title,
    make: str(j['brand'] ?? j['manufacturer']),
    model: str(j['model']),
    year: int.tryParse(_year.firstMatch(yearText)?.group(1) ?? ''),
    mileage: mileage,
    price: price,
    fuel: str(j['fuelType']),
    transmission: str(j['vehicleTransmission']),
    body: str(j['bodyType']),
    colour: str(j['color']),
    condition: condition.contains('NewCondition') ? 'new' : 'used',
    sellerType: switch (sellerKind) {
      'Person' => 'private',
      'AutoDealer' || 'AutomotiveBusiness' || 'AutoRental' || 'Organization' || 'LocalBusiness' => 'dealer',
      _ => 'unknown',
    },
    seller: str(sellerObj['name']),
    sellerPhone: str(sellerObj['telephone']),
    location: switch (address) {
      Map a => [a['addressLocality'], a['postalCode']].map(str).where((s) => s.isNotEmpty).join(', '),
      _ => str(address),
    },
    image: image == null || image.isEmpty ? null : image,
    description: description,
  );
}

/// The first schema.org vehicle (or failing that, product) on the page.
Map<String, Object?>? _vehicleLd(String html) {
  final found = <Map<String, Object?>>[];
  void walk(Object? o) {
    if (o is List) {
      o.forEach(walk);
    } else if (o is Map) {
      final m = o.cast<String, Object?>();
      if (m['@graph'] != null) walk(m['@graph']);
      final type = m['@type'];
      final types = type is List ? type.map((t) => '$t') : [if (type != null) '$type'];
      if (types.any(_vehicleTypes.contains) || types.contains('Product')) found.add(m);
      // Some sites wrap the car in an Offer's itemOffered.
      if (m['itemOffered'] != null) walk(m['itemOffered']);
    }
  }

  for (final m in _ldScript.allMatches(html)) {
    try {
      walk(jsonDecode(m.group(1)!.trim()));
    } on FormatException {
      continue;
    }
  }
  bool isVehicle(Map<String, Object?> m) {
    final t = m['@type'];
    return (t is List ? t.map((x) => '$x') : ['$t']).any(_vehicleTypes.contains);
  }

  return found.where(isVehicle).firstOrNull ?? found.firstOrNull;
}

/// Open Graph and product meta tags by property (or name).
Map<String, String> _openGraph(String html) {
  final out = <String, String>{};
  for (final tag in _metaTag.allMatches(html)) {
    final attrs = {
      for (final a in _attr.allMatches(tag.group(0)!)) a.group(1)!.toLowerCase(): a.group(2) ?? a.group(3)!,
    };
    final key = attrs['property'] ?? attrs['name'];
    final content = attrs['content'];
    if (key != null && content != null) out.putIfAbsent(key.toLowerCase(), () => content);
  }
  return out;
}

int? _number(Object? o) => switch (o) {
  num n => n.round(),
  String s => num.tryParse(s.replaceAll(RegExp(r'[£,\s]'), ''))?.round(),
  _ => null,
};

int? _poundsIn(String text) => _number(_pounds.firstMatch(text)?.group(1));

String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&pound;', '£')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>');

/// Sites whose adverts are only shown to signed-in people.
const _signInOnly = {'facebook.com', 'fb.com'};

/// Fetches an advert page and reads it. Throws FormatException with a
/// message for the user when the link is not an https page or the page
/// cannot be read (a sign-in wall, a bot check).
Future<CarAdvert> fetchCarAdvert(String link, {http.Client? client}) async {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw const FormatException('Paste the advert\'s https:// link.');
  }
  final source = sourceOf(link);
  if (_signInOnly.any((h) => source == h || source.endsWith('.$h'))) {
    throw const FormatException('Facebook only shows adverts to signed-in people.');
  }
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(uri, headers: {'user-agent': _userAgent, 'accept': 'text/html'})
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw FormatException('The site said ${res.statusCode}.');
    return parseCarAdvert(res.body, uri.removeFragment().toString());
  } finally {
    if (client == null) c.close();
  }
}

const _userAgent = 'Mozilla/5.0 (compatible; Anveshana/0.2; personal car search)';
