/// What the user is doing with a property.
enum PropertyKind {
  rent('To rent'),
  buy('To buy'),
  owned('Owned');

  const PropertyKind(this.label);
  final String label;

  static PropertyKind of(String name) => values.where((k) => k.name == name).firstOrNull ?? rent;
}

/// Steps of a hunt, in order. Lets and purchases share them; a few read
/// differently for each.
enum Stage {
  fresh('new'),
  shortlisted('shortlisted'),
  enquired('enquired'),
  viewing('viewing'),
  applied('applied'),
  agreed('agreed'),
  dropped('dropped');

  const Stage(this.id);
  final String id;

  static Stage of(String id) => values.where((s) => s.id == id).firstOrNull ?? fresh;

  String label(PropertyKind kind) => switch (this) {
    fresh => 'New',
    shortlisted => 'Shortlisted',
    enquired => 'Enquired',
    viewing => 'Viewing',
    applied => kind == PropertyKind.buy ? 'Offer made' : 'Applied',
    agreed => kind == PropertyKind.buy ? 'Sale agreed' : 'Let agreed',
    dropped => 'Not for us',
  };

  /// Still in play.
  bool get active => this != dropped;
}

/// Readable advert status ("toLet" -> "To let").
String listingStatusLabel(String key) => switch (key) {
  'toLet' => 'To let',
  'letAgreed' => 'Let agreed',
  'let' => 'Let',
  'forSale' => 'For sale',
  'saleAgreed' => 'Sale agreed',
  'sold' => 'Sold',
  '' => '',
  _ => key,
};

/// Whether an advert says the property is gone.
bool listingGone(String key) => const {'letAgreed', 'let', 'saleAgreed', 'sold', 'withdrawn'}.contains(key);
