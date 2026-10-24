/// Vahana's hints, by id, on top of the shared ones (coreHints). Tooltips
/// use the short ones; page banners (ids starting `page.`) explain a whole
/// screen once.
const vahanaHints = <String, String>{
  // Navigation
  'nav.search': 'Search links for the main car sites, filled in from what you want.',
  'nav.garage': 'Cars you found and cars you own: dates, logbook, checks and sale.',
  'nav.finance': 'Cash, loan, HP, PCP and lease compared by real cost, plus running costs.',
  'nav.guide': 'Your rights, tax, and the checks to do before paying.',
  'nav.settings': 'Sync, security and the hints.',
  'nav.more': 'The rest of Vahana Anveshana.',
  // Cars
  'cars.add': 'Paste an advert link from any site, or type a car in.',
  'cars.custom': 'Your own dealers and sites. Use {make}, {model}, {postcode} or {maxPrice} in the link.',
  'cars.compare':
      'Real cost is everything you pay less what the car is worth at the end. It is the fair way to compare '
      'cash, a loan, HP, PCP and a lease.',
  'cars.dates':
      'MOT, tax, insurance and service dates. They count down here and on the Garage list. The calendar '
      'button adds a reminder to your own calendar.',
  'cars.flags': 'Things that buyers report most: prices that are too good, odd mileage, and missing details.',
  'cars.logbook':
      'Fuel, services, repairs, MOT and insurance. Totals build up, and logging an MOT or service moves its '
      'date on.',
  // Page banners
  'page.search':
      'Search the main car sites for your area from one place. Pages open in your browser; add your own '
      'dealers at the bottom.',
  'page.garage':
      'Cars you found, by stage. Open one for its price check, dates, logbook and checklists, and to record '
      'the sale.',
  'page.finance':
      'Compare ways to pay, and what the car costs to run. A starting point, not financial advice.',
  'page.guide': 'Your rights, the tax and costs to know, and the checks before you pay.',
};
