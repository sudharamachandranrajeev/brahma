// The shop sites the extension may open and read: the hosts of lib/domain/shops.dart
// (test/extension.test.js fails when the two drift apart). A subdomain of a host counts.
const SHOP_HOSTS = [
  "aldi.co.uk",
  "asda.com",
  "bmstores.co.uk",
  "boots.com",
  "coop.co.uk",
  "groceries.morrisons.com",
  "homebargains.co.uk",
  "homesense.com",
  "iceland.co.uk",
  "lidl.co.uk",
  "matalan.co.uk",
  "ocado.com",
  "poundland.co.uk",
  "poundstretcher.co.uk",
  "primark.com",
  "sainsburys.co.uk",
  "sportsdirect.com",
  "superdrug.com",
  "tesco.com",
  "thebodyshop.com",
  "tkmaxx.com",
  "waitrose.com"
];

if (typeof module !== 'undefined') module.exports = { SHOP_HOSTS };
