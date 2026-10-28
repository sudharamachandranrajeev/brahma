/// What a shop sells online.
enum Selling {
  /// Home delivery (and usually click and collect) you book a slot for.
  delivery('Delivery'),

  /// Orders online for delivery or collection, no grocery slots.
  online('Online orders'),

  /// A website to browse; buying happens in store.
  browse('In store only');

  const Selling(this.label);
  final String label;
}

/// A UK shop Bhojana knows how to search.
class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.kind,
    required this.home,
    required this.selling,
    this.search,
    this.slots,
    this.loyalty,
    this.multiBuys = false,
  });

  final String id;
  final String name;

  /// Grocery | Discount | Home | Fashion | Health & beauty | Sport
  final String kind;
  final String home;
  final Selling selling;

  /// The search page, with `{q}` where the words go; null when the site has
  /// no product search.
  final String? search;

  /// The delivery slot page, for grocers that book slots.
  final String? slots;

  /// The loyalty scheme whose prices show only when signed in.
  final String? loyalty;

  /// Whether Bhojana offers this shop's multi-buy deals ("Any 2 for £3") for
  /// the user to take. Turned on per shop once its deals have been checked.
  final bool multiBuys;

  bool get searchable => search != null;

  String searchUrl(String query) => search!.replaceAll('{q}', Uri.encodeComponent(query.trim()));
}

const shopKinds = ['Grocery', 'Discount', 'Home', 'Fashion', 'Health & beauty', 'Sport'];

/// The shops, by kind. Addresses are the shops' own public search pages;
/// a shop that changes its site needs its entry changed here.
const shops = <Shop>[
  Shop(
    id: 'tesco',
    name: 'Tesco',
    kind: 'Grocery',
    home: 'https://www.tesco.com/groceries/en-GB',
    search: 'https://www.tesco.com/groceries/en-GB/search?query={q}',
    slots: 'https://www.tesco.com/groceries/en-GB/slots/delivery',
    selling: Selling.delivery,
    loyalty: 'Clubcard',
    multiBuys: true,
  ),
  Shop(
    id: 'sainsburys',
    name: "Sainsbury's",
    kind: 'Grocery',
    home: 'https://www.sainsburys.co.uk/gol-ui/groceries',
    search: 'https://www.sainsburys.co.uk/gol-ui/SearchResults/{q}',
    slots: 'https://www.sainsburys.co.uk/gol-ui/slot/book',
    selling: Selling.delivery,
    loyalty: 'Nectar',
  ),
  Shop(
    id: 'asda',
    name: 'Asda',
    kind: 'Grocery',
    home: 'https://www.asda.com/groceries',
    search: 'https://www.asda.com/groceries/search/{q}',
    slots: 'https://www.asda.com/groceries/book-slot',
    selling: Selling.delivery,
    loyalty: 'Asda Rewards',
    multiBuys: true,
  ),
  Shop(
    id: 'morrisons',
    name: 'Morrisons',
    kind: 'Grocery',
    home: 'https://groceries.morrisons.com',
    search: 'https://groceries.morrisons.com/search?q={q}',
    slots: 'https://groceries.morrisons.com/slots',
    selling: Selling.delivery,
    loyalty: 'More Card',
  ),
  Shop(
    id: 'ocado',
    name: 'Ocado',
    kind: 'Grocery',
    home: 'https://www.ocado.com',
    search: 'https://www.ocado.com/search?q={q}',
    slots: 'https://www.ocado.com/slots',
    selling: Selling.delivery,
  ),
  Shop(
    id: 'waitrose',
    name: 'Waitrose',
    kind: 'Grocery',
    home: 'https://www.waitrose.com',
    search: 'https://www.waitrose.com/ecom/shop/search?searchTerm={q}',
    slots: 'https://www.waitrose.com/ecom/bookslot',
    selling: Selling.delivery,
    loyalty: 'myWaitrose',
  ),
  Shop(
    id: 'iceland',
    name: 'Iceland',
    kind: 'Grocery',
    home: 'https://www.iceland.co.uk',
    search: 'https://www.iceland.co.uk/search?q={q}',
    slots: 'https://www.iceland.co.uk/book-delivery',
    selling: Selling.delivery,
    loyalty: 'Bonus Card',
    multiBuys: true,
  ),
  Shop(
    id: 'coop',
    name: 'Co-op',
    kind: 'Grocery',
    home: 'https://www.coop.co.uk',
    search: 'https://www.coop.co.uk/products/search?query={q}',
    selling: Selling.online,
    loyalty: 'Co-op Membership',
  ),
  Shop(
    id: 'aldi',
    name: 'Aldi',
    kind: 'Grocery',
    home: 'https://www.aldi.co.uk',
    search: 'https://www.aldi.co.uk/results?q={q}',
    selling: Selling.browse,
  ),
  Shop(
    id: 'lidl',
    name: 'Lidl',
    kind: 'Grocery',
    home: 'https://www.lidl.co.uk',
    search: 'https://www.lidl.co.uk/q/search?q={q}',
    selling: Selling.browse,
    loyalty: 'Lidl Plus',
  ),
  Shop(
    id: 'poundland',
    name: 'Poundland',
    kind: 'Discount',
    home: 'https://www.poundland.co.uk',
    search: 'https://www.poundland.co.uk/search?q={q}',
    selling: Selling.browse,
  ),
  Shop(
    id: 'poundstretcher',
    name: 'Poundstretcher',
    kind: 'Discount',
    home: 'https://www.poundstretcher.co.uk',
    search: 'https://www.poundstretcher.co.uk/search?q={q}',
    selling: Selling.online,
  ),
  Shop(
    id: 'homebargains',
    name: 'Home Bargains',
    kind: 'Discount',
    home: 'https://www.homebargains.co.uk',
    search: 'https://www.homebargains.co.uk/search?q={q}',
    selling: Selling.online,
  ),
  Shop(
    id: 'bm',
    name: 'B&M',
    kind: 'Discount',
    home: 'https://www.bmstores.co.uk',
    search: 'https://www.bmstores.co.uk/search?q={q}',
    selling: Selling.browse,
  ),
  Shop(
    id: 'homesense',
    name: 'HomeSense',
    kind: 'Home',
    home: 'https://www.homesense.com',
    selling: Selling.browse,
  ),
  Shop(
    id: 'tkmaxx',
    name: 'TK Maxx',
    kind: 'Home',
    home: 'https://www.tkmaxx.com/uk/en',
    search: 'https://www.tkmaxx.com/uk/en/search?text={q}',
    selling: Selling.online,
  ),
  Shop(
    id: 'matalan',
    name: 'Matalan',
    kind: 'Fashion',
    home: 'https://www.matalan.co.uk',
    search: 'https://www.matalan.co.uk/search?q={q}',
    selling: Selling.online,
  ),
  Shop(
    id: 'primark',
    name: 'Primark',
    kind: 'Fashion',
    home: 'https://www.primark.com/en-gb',
    search: 'https://www.primark.com/en-gb/search?q={q}',
    selling: Selling.browse,
  ),
  Shop(
    id: 'boots',
    name: 'Boots',
    kind: 'Health & beauty',
    home: 'https://www.boots.com',
    search: 'https://www.boots.com/sitesearch?searchTerm={q}',
    selling: Selling.online,
    loyalty: 'Advantage Card',
  ),
  Shop(
    id: 'superdrug',
    name: 'Superdrug',
    kind: 'Health & beauty',
    home: 'https://www.superdrug.com',
    search: 'https://www.superdrug.com/search?text={q}',
    selling: Selling.online,
  ),
  Shop(
    id: 'bodyshop',
    name: 'The Body Shop',
    kind: 'Health & beauty',
    home: 'https://www.thebodyshop.com/en-gb',
    search: 'https://www.thebodyshop.com/search?q={q}',
    selling: Selling.online,
  ),
  Shop(
    id: 'sportsdirect',
    name: 'Sports Direct',
    kind: 'Sport',
    home: 'https://www.sportsdirect.com',
    search: 'https://www.sportsdirect.com/searchresults?descriptionfilter={q}',
    selling: Selling.online,
  ),
];

final _byId = {for (final s in shops) s.id: s};

Shop? shopById(String id) => _byId[id];

/// The shops a first-time user compares: the big grocers.
const defaultShops = ['tesco', 'sainsburys', 'asda', 'morrisons', 'aldi', 'lidl'];
