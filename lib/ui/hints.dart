/// Anveshana's hints, by id, on top of the shared ones (coreHints). Tooltips
/// use the short ones; page banners (ids starting `page.`) explain a whole
/// screen once.
const anveshanaHints = <String, String>{
  // Navigation
  'nav.hunt': 'Homes you are looking at to rent or buy, from first sight to keys.',
  'nav.contacts': 'Agents, landlords, tenants, brokers, solicitors and trades.',
  'nav.searches': 'Saved searches. Brahma Watch checks them and alerts your phone.',
  'nav.invest': 'Buy-to-let, buying a home and development appraisals.',
  'nav.lettings': 'Tenancies, rent and landlord safety checks.',
  'nav.research': 'Area reports for any UK postcode, purchase tax and where to look further.',
  'nav.cars': 'Buy a car, new or used: where to look, what you found, how to pay and what to check.',
  'nav.settings': 'Your details for enquiries, your home point, Brahma Watch, sync and security.',
  'nav.more': 'The rest of Anveshana.',
  // Hunt
  'hunt.add': 'Paste a PropertyPal link, or type a property in.',
  'hunt.watch': 'Bring in what Brahma Watch found since the last check.',
  'hunt.distance': 'As the crow flies from the home point in Settings.',
  'hunt.enquiry': 'A first message: is it free, what next, when to view. Your details come from Settings.',
  'hunt.stage': 'Where this property is in your hunt. Calls and messages move it on by themselves.',
  'hunt.gone': 'The advert says it is let or sold.',
  // Searches
  'searches.send': 'Replace the searches Brahma Watch runs with these.',
  'searches.fetch': 'Copy the searches Brahma Watch runs into Anveshana.',
  'searches.run': 'Ask Brahma Watch to check every search now.',
  'searches.test': 'Send a test alert to your phone.',
  'searches.path':
      'The part of a PropertyPal search address after the site name, e.g. /property-to-rent/enniskillen.',
  // Invest
  'invest.save': 'Keep these figures to come back to.',
  'invest.icr': 'Lenders want rent to cover the interest at a stress rate by this much (often 125%).',
  'invest.residual': 'The most you could pay for the land and still make the target profit.',
  // Lettings
  'lettings.balance': 'Rent due so far minus rent recorded. Positive is owed.',
  'lettings.checks': 'Safety certificates and other duties with the date each is next due.',
  // Research
  'research.save': 'Keep this report to compare areas later.',
  'research.tax': 'Stamp Duty (England, NI), LBTT (Scotland) or LTT (Wales) for a price.',
  // Cars
  'cars.add': 'Paste an advert link from any site, or type a car in.',
  'cars.custom': 'Your own dealers and sites. Use {make}, {model}, {postcode} or {maxPrice} in the link.',
  'cars.compare':
      'Real cost is everything you pay less what the car is worth at the end. It is the fair way to compare '
      'cash, a loan, HP, PCP and a lease.',
  // Settings
  'settings.applicant': 'Goes into enquiries you send. Stays on your devices.',
  'settings.home': 'Where distances are measured from, e.g. home or work.',
  'settings.watch':
      'Your own Brahma Watch Worker on Cloudflare, which checks searches and alerts your phone.',
  // Page banners
  'page.cars':
      'Search the main car sites for your area from one place, save the cars you find, compare ways to pay '
      'and work through the checks before you buy.',
  'page.hunt':
      'Every property you are considering, by stage. Add one from a PropertyPal link, or let Brahma '
      'Watch bring in new listings. Hover or long-press anything for a tip.',
  'page.contacts': 'Call, text, WhatsApp or e-mail from here. Each contact is logged against the property.',
  'page.searches':
      'Brahma Watch runs these searches in the cloud every 10 minutes and alerts your phone when '
      'something new, cheaper or let appears.',
  'page.invest':
      'Rough appraisals with current UK tax rules. They are a starting point for your own checks, '
      'not financial advice.',
  'page.lettings':
      'For homes you let out, or rent yourself: rent due and paid, deposits and the safety checks '
      'each nation requires.',
  'page.research':
      'Postcode reports from open data: house prices (UK HPI), recorded crime (police.uk) and sold '
      'prices (England and Wales). Links cover flood risk, planning, EPCs and more.',
};
