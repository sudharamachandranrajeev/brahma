import 'nation.dart';

/// What the user is looking for. Saved as a pref.
class CarSearch {
  const CarSearch({
    this.make = '',
    this.model = '',
    this.maxPrice,
    this.postcode = '',
    this.radius = 30,
    this.condition = 'used',
  });

  final String make, model;
  final int? maxPrice;
  final String postcode;

  /// Miles.
  final int radius;

  /// used | new
  final String condition;

  bool get isUsed => condition == 'used';

  /// BT postcodes are Northern Ireland; any other full postcode is Great Britain.
  Nation? get nation => postcode.trim().isEmpty
      ? null
      : postcode.trim().toUpperCase().startsWith('BT')
      ? Nation.northernIreland
      : null;

  bool get inNorthernIreland => nation == Nation.northernIreland;

  String get compactPostcode => postcode.replaceAll(RegExp(r'\s'), '').toUpperCase();
  String get query => [make, model].where((s) => s.trim().isNotEmpty).join(' ').trim();

  CarSearch copyWith({
    String? make,
    String? model,
    int? maxPrice,
    bool clearPrice = false,
    String? postcode,
    int? radius,
    String? condition,
  }) => CarSearch(
    make: make ?? this.make,
    model: model ?? this.model,
    maxPrice: clearPrice ? null : maxPrice ?? this.maxPrice,
    postcode: postcode ?? this.postcode,
    radius: radius ?? this.radius,
    condition: condition ?? this.condition,
  );

  Map<String, Object?> toJson() => {
    'make': make,
    'model': model,
    'maxPrice': maxPrice,
    'postcode': postcode,
    'radius': radius,
    'condition': condition,
  };

  factory CarSearch.fromJson(Map<String, Object?> j) => CarSearch(
    make: '${j['make'] ?? ''}',
    model: '${j['model'] ?? ''}',
    maxPrice: (j['maxPrice'] as num?)?.round(),
    postcode: '${j['postcode'] ?? ''}',
    radius: (j['radius'] as num?)?.round() ?? 30,
    condition: j['condition'] == 'new' ? 'new' : 'used',
  );
}

/// Kinds of seller a site brings you to.
enum SourceKind {
  marketplace('Marketplaces', 'Private sellers and traders side by side. Cheapest, least protection.'),
  portal('Listing sites', 'Mostly dealers (some private). Search many forecourts at once.'),
  store('Online stores', 'Sell and deliver nationwide with a return window. Often dearer.'),
  dealer('Dealer groups', 'Franchised and large independent forecourts. Warranty and finance on site.'),
  newDeals('New-car deals', 'Broker and manufacturer discounts, finance and leasing offers.');

  const SourceKind(this.label, this.about);
  final String label, about;
}

/// A place to look for cars. [url] builds the site's own results page for a
/// search; it opens in the user's browser, so nothing is scraped.
class CarSource {
  const CarSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.url,
    this.used = true,
    this.newCars = false,
    this.onlyNi = false,
    this.note = '',
    this.exact = true,
  });

  final String id, name, note;
  final SourceKind kind;
  final Uri Function(CarSearch s) url;
  final bool used, newCars;

  /// Covers Northern Ireland only (listed first for BT postcodes, hidden otherwise).
  final bool onlyNi;

  /// The link applies every filter; false when it only narrows to make and
  /// model and the rest is set on the site.
  final bool exact;

  bool serves(CarSearch s) =>
      (s.isUsed ? used : newCars) && (!onlyNi || s.inNorthernIreland || s.postcode.isEmpty);
}

String _slug(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

Uri _q(String host, String path, Map<String, String?> q) => Uri.https(host, path, {
  for (final e in q.entries)
    if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
});

String? _price(CarSearch s) => s.maxPrice?.toString();
String? _pc(CarSearch s) => s.postcode.trim().isEmpty ? null : s.compactPostcode;

/// UsedCarsNI numbers its makes and models; those not known here still open
/// the site's own search, which takes the text as a keyword.
const _usedCarsNiMakes = {'ford': 7, 'honda': 8};
const _usedCarsNiModels = {'focus': 908};

final carSources = <CarSource>[
  CarSource(
    id: 'autotrader',
    name: 'AutoTrader',
    kind: SourceKind.portal,
    newCars: true,
    note: 'Biggest UK dealer and private stock.',
    url: (s) => _q('www.autotrader.co.uk', '/car-search', {
      'postcode': _pc(s),
      'radius': s.postcode.isEmpty ? null : '${s.radius}',
      'make': s.make,
      'model': s.model,
      'price-to': _price(s),
      'postcode-new': null,
      'onesearchad': s.isUsed ? 'Used' : 'New',
    }),
  ),
  CarSource(
    id: 'gumtree',
    name: 'Gumtree',
    kind: SourceKind.marketplace,
    note: 'Mostly private sellers. Watch for scams: see the checklist.',
    url: (s) => _q('www.gumtree.com', '/search', {
      'search_category': 'cars',
      'vehicle_make': _slug(s.make),
      'vehicle_model': _slug(s.model),
      'max_price': _price(s),
      'search_location': _pc(s),
      'distance': s.postcode.isEmpty ? null : '${s.radius}',
    }),
  ),
  CarSource(
    id: 'facebook',
    name: 'Facebook Marketplace',
    kind: SourceKind.marketplace,
    note: 'Needs your sign-in; set the location on Facebook. Adverts cannot be imported.',
    exact: false,
    url: (s) => _q('www.facebook.com', '/marketplace/search', {'query': s.query, 'maxPrice': _price(s)}),
  ),
  CarSource(
    id: 'ebay',
    name: 'eBay Motors',
    kind: SourceKind.marketplace,
    url: (s) => _q('www.ebay.co.uk', '/sch/Cars/9801/i.html', {
      '_nkw': s.query,
      '_udhi': _price(s),
      '_stpos': _pc(s),
      '_sadis': s.postcode.isEmpty ? null : '${s.radius}',
    }),
  ),
  CarSource(
    id: 'usedcarsni',
    name: 'UsedCarsNI',
    kind: SourceKind.portal,
    onlyNi: true,
    note: 'The main Northern Ireland dealer site.',
    url: (s) => _q('www.usedcarsni.com', '/search_results.php', {
      'search_type': '1',
      if (_usedCarsNiMakes[s.make.trim().toLowerCase()] case final m?) 'make': '$m',
      if (_usedCarsNiModels[s.model.trim().toLowerCase()] case final m?) 'model': '$m',
      'price_to': _price(s),
      if (s.postcode.isNotEmpty) ...{
        'distance_enabled': '1',
        'distance_postcode': _pc(s),
        'distance_miles': '${s.radius}',
      },
    }),
    exact: true,
  ),
  CarSource(
    id: 'donedeal',
    name: 'DoneDeal',
    kind: SourceKind.marketplace,
    onlyNi: true,
    note: 'Ireland-wide, many Northern Ireland sellers. Prices may be in euro.',
    url: (s) => _q(
      'www.donedeal.ie',
      '/cars${s.make.isEmpty ? '' : '/${_title(s.make)}'}${s.model.isEmpty ? '' : '/${_title(s.model)}'}',
      {'price_to': _price(s)},
    ),
  ),
  CarSource(
    id: 'pistonheads',
    name: 'PistonHeads',
    kind: SourceKind.portal,
    note: 'Enthusiast, performance and classic cars.',
    url: (s) => _q('www.pistonheads.com', '/buy/search', {
      'make': _slug(s.make),
      'model': _slug(s.model),
      'price-to': _price(s),
      'postcode': _pc(s),
      'radius': s.postcode.isEmpty ? null : '${s.radius}',
    }),
  ),
  CarSource(
    id: 'cargurus',
    name: 'CarGurus',
    kind: SourceKind.portal,
    exact: false,
    note: 'Rates each deal against market price. Pick make and model on the site.',
    url: (s) => _q(
      'www.cargurus.co.uk',
      '/Cars/inventorylisting/viewDetailsFilterViewInventoryListing.action',
      {'zip': _pc(s), 'distance': s.postcode.isEmpty ? null : '${s.radius}', 'maxPrice': _price(s)},
    ),
  ),
  CarSource(
    id: 'exchangeandmart',
    name: 'Exchange & Mart',
    kind: SourceKind.portal,
    exact: false,
    url: (s) => _q(
      'www.exchangeandmart.co.uk',
      '/used-cars-for-sale${s.make.isEmpty ? '' : '/${_slug(s.make)}'}${s.model.isEmpty ? '' : '/${_slug(s.model)}'}',
      {'postcode': _pc(s), 'distance': s.postcode.isEmpty ? null : '${s.radius}', 'maxprice': _price(s)},
    ),
  ),
  CarSource(
    id: 'cinch',
    name: 'Cinch',
    kind: SourceKind.store,
    note: 'Delivers nationwide; 14-day return. Check delivery to Northern Ireland.',
    url: (s) => _q(
      'www.cinch.co.uk',
      '/used-cars${s.make.isEmpty ? '' : '/${_slug(s.make)}'}${s.model.isEmpty ? '' : '/${_slug(s.model)}'}',
      {'maxPrice': _price(s)},
    ),
  ),
  CarSource(
    id: 'cazoo',
    name: 'Cazoo',
    kind: SourceKind.store,
    exact: false,
    note: 'Online store (this is where Motors.co.uk now leads).',
    url: (s) => Uri.https(
      'www.cazoo.co.uk',
      '/cars${s.make.isEmpty ? '' : '/${_slug(s.make)}'}${s.model.isEmpty ? '' : '/${_slug(s.model)}'}/',
    ),
  ),
  CarSource(
    id: 'arnoldclark',
    name: 'Arnold Clark',
    kind: SourceKind.dealer,
    newCars: true,
    exact: false,
    note: 'Large UK dealer group. Set the price on the site.',
    url: (s) => _q('www.arnoldclark.com', s.isUsed ? '/used-cars/search' : '/new-cars/search', {
      'make': _slug(s.make),
      'model': _slug(s.model),
    }),
  ),
  CarSource(
    id: 'evanshalshaw',
    name: 'Evans Halshaw',
    kind: SourceKind.dealer,
    exact: false,
    url: (s) => Uri.https(
      'www.evanshalshaw.com',
      '${s.make.isEmpty ? '' : '/${_slug(s.make)}'}/used-cars${s.model.isEmpty ? '' : '/${_slug(s.model)}'}/',
    ),
  ),
  CarSource(
    id: 'carwow',
    name: 'Carwow',
    kind: SourceKind.newDeals,
    used: false,
    newCars: true,
    exact: false,
    note: 'Dealers compete to quote you a discount.',
    url: (s) => Uri.https(
      'www.carwow.co.uk',
      s.make.isEmpty ? '/new-cars' : '/${_slug(s.make)}${s.model.isEmpty ? '' : '/${_slug(s.model)}'}/deals',
    ),
  ),
  CarSource(
    id: 'leasing',
    name: 'Leasing.com',
    kind: SourceKind.newDeals,
    used: false,
    newCars: true,
    exact: false,
    note: 'Personal lease deals.',
    url: (s) => Uri.https(
      'leasing.com',
      '/car-leasing${s.make.isEmpty ? '' : '/${_slug(s.make)}'}${s.model.isEmpty ? '' : '/${_slug(s.model)}'}/',
    ),
  ),
];

String _title(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join('-');

/// A site the user added: a link where {make}, {model}, {query}, {postcode}
/// and {maxPrice} are replaced by the search.
class CustomSource {
  const CustomSource({required this.name, required this.link});
  final String name, link;

  Uri? resolve(CarSearch s) {
    final filled = link
        .trim()
        .replaceAll('{make}', Uri.encodeComponent(s.make))
        .replaceAll('{model}', Uri.encodeComponent(s.model))
        .replaceAll('{query}', Uri.encodeComponent(s.query))
        .replaceAll('{postcode}', Uri.encodeComponent(s.compactPostcode))
        .replaceAll('{maxPrice}', '${s.maxPrice ?? ''}');
    final uri = Uri.tryParse(filled);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty ? uri : null;
  }

  Map<String, Object?> toJson() => {'name': name, 'link': link};

  factory CustomSource.fromJson(Map<String, Object?> j) =>
      CustomSource(name: '${j['name'] ?? ''}', link: '${j['link'] ?? ''}');
}

/// The sites to show for [s]: those that serve it, Northern Ireland's first
/// for a BT postcode.
List<CarSource> sourcesFor(CarSearch s) {
  final list = carSources.where((c) => c.serves(s)).toList();
  if (s.inNorthernIreland) list.sort((a, b) => (b.onlyNi ? 1 : 0).compareTo(a.onlyNi ? 1 : 0));
  return list;
}
