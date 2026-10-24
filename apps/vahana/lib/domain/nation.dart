/// The four UK nations: MOT and other rules differ in Northern Ireland.
enum Nation {
  england('England'),
  northernIreland('Northern Ireland'),
  scotland('Scotland'),
  wales('Wales');

  const Nation(this.label);
  final String label;

  /// From a postcodes.io `country`, or a postcode's area (BT = Northern Ireland).
  static Nation? fromCountry(String? country) => switch (country) {
    'England' => england,
    'Northern Ireland' => northernIreland,
    'Scotland' => scotland,
    'Wales' => wales,
    _ => null,
  };
}
