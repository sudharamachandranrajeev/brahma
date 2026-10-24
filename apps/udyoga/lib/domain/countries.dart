/// Countries a candidate can look for work in, with the job sites worth
/// searching there. Portal links are searches the user opens in a browser:
/// nothing is scraped.
class Country {
  const Country(this.code, this.name, this.currency, {this.adzuna, this.indeed, this.portals = const []});

  /// ISO 3166 alpha-2, upper case.
  final String code;
  final String name;

  /// ISO 4217.
  final String currency;

  /// Adzuna's country code, when Adzuna covers it.
  final String? adzuna;

  /// Indeed's site for the country.
  final String? indeed;
  final List<Portal> portals;

  static Country? of(String code) => byCode[code.toUpperCase()];

  static String nameOf(String code) => of(code)?.name ?? code;
}

/// A job site search. In [url], {q} and {l} are the search terms and place
/// (URL-encoded); {qs} and {ls} are the same as hyphenated slugs.
class Portal {
  const Portal(this.name, this.url, {this.note = ''});
  final String name, url;
  final String note;

  Uri link(String query, String place) {
    String slug(String s) =>
        s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return Uri.parse(
      url
          .replaceAll('{q}', Uri.encodeQueryComponent(query))
          .replaceAll('{l}', Uri.encodeQueryComponent(place))
          .replaceAll('{qs}', slug(query))
          .replaceAll('{ls}', slug(place)),
    );
  }
}

/// Sites that cover every country.
const globalPortals = [
  Portal(
    'LinkedIn Jobs',
    'https://www.linkedin.com/jobs/search/?keywords={q}&location={l}&f_TPR=r604800',
    note: 'Posted in the last week',
  ),
  Portal('Google Jobs', 'https://www.google.com/search?q={q}+jobs+{l}&ibp=htl;jobs'),
  Portal('Glassdoor', 'https://www.glassdoor.com/Job/jobs.htm?sc.keyword={q}&locKeyword={l}'),
];

/// LinkedIn people search, for finding recruiters and hiring managers.
Uri linkedInPeople(String keywords) => Uri.parse(
  'https://www.linkedin.com/search/results/people/?keywords=${Uri.encodeQueryComponent(keywords)}',
);

/// LinkedIn company page search.
Uri linkedInCompany(String company) => Uri.parse(
  'https://www.linkedin.com/search/results/companies/?keywords=${Uri.encodeQueryComponent(company)}',
);

const countries = [
  Country(
    'GB',
    'United Kingdom',
    'GBP',
    adzuna: 'gb',
    indeed: 'https://uk.indeed.com',
    portals: [
      Portal('Reed', 'https://www.reed.co.uk/jobs/{qs}-jobs-in-{ls}'),
      Portal('Totaljobs', 'https://www.totaljobs.com/jobs/{qs}/in-{ls}'),
      Portal('CV-Library', 'https://www.cv-library.co.uk/search-jobs?q={q}&geo={l}'),
      Portal('Find a job (GOV.UK)', 'https://findajob.dwp.gov.uk/search?q={q}&w={l}'),
      Portal('NHS Jobs', 'https://www.jobs.nhs.uk/candidate/search/results?keyword={q}&location={l}'),
      Portal('HSC Jobs (Northern Ireland)', 'https://jobs.hscni.net/Search?SearchCatID=0&keywords={q}'),
      Portal('NI Civil Service', 'https://irecruit-ext.hrconnect.nigov.net/jobs/vacancies.aspx'),
      Portal('NIJobs', 'https://www.nijobs.com/ShowResults.aspx?Keywords={q}&Location=0'),
      Portal('Civil Service Jobs', 'https://www.civilservicejobs.service.gov.uk/csr/index.cgi'),
      Portal('Guardian Jobs', 'https://jobs.theguardian.com/jobs/{qs}/'),
    ],
  ),
  Country(
    'IE',
    'Ireland',
    'EUR',
    indeed: 'https://ie.indeed.com',
    portals: [
      Portal('IrishJobs', 'https://www.irishjobs.ie/jobs/{qs}'),
      Portal('Jobs.ie', 'https://www.jobs.ie/jobs/{qs}'),
      Portal('publicjobs.ie', 'https://www.publicjobs.ie/en/'),
      Portal('HSE Careers', 'https://about.hse.ie/jobs/'),
    ],
  ),
  Country(
    'IN',
    'India',
    'INR',
    adzuna: 'in',
    indeed: 'https://in.indeed.com',
    portals: [
      Portal('Naukri', 'https://www.naukri.com/{qs}-jobs-in-{ls}'),
      Portal('foundit', 'https://www.foundit.in/srp/results?query={q}&locations={l}'),
      Portal('National Career Service', 'https://www.ncs.gov.in/'),
    ],
  ),
  Country(
    'US',
    'United States',
    'USD',
    adzuna: 'us',
    indeed: 'https://www.indeed.com',
    portals: [Portal('USAJOBS', 'https://www.usajobs.gov/search/results/?k={q}&l={l}')],
  ),
  Country(
    'CA',
    'Canada',
    'CAD',
    adzuna: 'ca',
    indeed: 'https://ca.indeed.com',
    portals: [
      Portal('Job Bank', 'https://www.jobbank.gc.ca/jobsearch/jobsearch?searchstring={q}&locationstring={l}'),
    ],
  ),
  Country(
    'AU',
    'Australia',
    'AUD',
    adzuna: 'au',
    indeed: 'https://au.indeed.com',
    portals: [
      Portal('SEEK', 'https://www.seek.com.au/{qs}-jobs/in-{ls}'),
      Portal('APS Jobs', 'https://www.apsjobs.gov.au/s/job-search?searchString={q}'),
    ],
  ),
  Country(
    'NZ',
    'New Zealand',
    'NZD',
    adzuna: 'nz',
    indeed: 'https://nz.indeed.com',
    portals: [Portal('SEEK NZ', 'https://www.seek.co.nz/{qs}-jobs/in-{ls}')],
  ),
  Country(
    'AE',
    'United Arab Emirates',
    'AED',
    indeed: 'https://ae.indeed.com',
    portals: [
      Portal('Bayt', 'https://www.bayt.com/en/uae/jobs/{qs}-jobs/'),
      Portal('GulfTalent', 'https://www.gulftalent.com/jobs/search?keywords={q}'),
    ],
  ),
  Country(
    'SA',
    'Saudi Arabia',
    'SAR',
    indeed: 'https://sa.indeed.com',
    portals: [Portal('Bayt', 'https://www.bayt.com/en/saudi-arabia/jobs/{qs}-jobs/')],
  ),
  Country(
    'QA',
    'Qatar',
    'QAR',
    indeed: 'https://qa.indeed.com',
    portals: [Portal('Bayt', 'https://www.bayt.com/en/qatar/jobs/{qs}-jobs/')],
  ),
  Country(
    'DE',
    'Germany',
    'EUR',
    adzuna: 'de',
    indeed: 'https://de.indeed.com',
    portals: [
      Portal('StepStone', 'https://www.stepstone.de/jobs/{qs}/in-{ls}'),
      Portal('Bundesagentur für Arbeit', 'https://www.arbeitsagentur.de/jobsuche/suche?was={q}&wo={l}'),
    ],
  ),
  Country('NL', 'Netherlands', 'EUR', adzuna: 'nl', indeed: 'https://nl.indeed.com'),
  Country('FR', 'France', 'EUR', adzuna: 'fr', indeed: 'https://fr.indeed.com'),
  Country('ES', 'Spain', 'EUR', adzuna: 'es', indeed: 'https://es.indeed.com'),
  Country('IT', 'Italy', 'EUR', adzuna: 'it', indeed: 'https://it.indeed.com'),
  Country('BE', 'Belgium', 'EUR', adzuna: 'be', indeed: 'https://be.indeed.com'),
  Country('AT', 'Austria', 'EUR', adzuna: 'at', indeed: 'https://at.indeed.com'),
  Country('CH', 'Switzerland', 'CHF', adzuna: 'ch', indeed: 'https://ch.indeed.com'),
  Country('PL', 'Poland', 'PLN', adzuna: 'pl', indeed: 'https://pl.indeed.com'),
  Country('SE', 'Sweden', 'SEK', indeed: 'https://se.indeed.com'),
  Country('NO', 'Norway', 'NOK', indeed: 'https://no.indeed.com'),
  Country('DK', 'Denmark', 'DKK', indeed: 'https://dk.indeed.com'),
  Country('FI', 'Finland', 'EUR', indeed: 'https://fi.indeed.com'),
  Country('PT', 'Portugal', 'EUR', indeed: 'https://pt.indeed.com'),
  Country(
    'SG',
    'Singapore',
    'SGD',
    adzuna: 'sg',
    indeed: 'https://sg.indeed.com',
    portals: [Portal('MyCareersFuture', 'https://www.mycareersfuture.gov.sg/search?search={q}')],
  ),
  Country('MY', 'Malaysia', 'MYR', indeed: 'https://malaysia.indeed.com'),
  Country('ZA', 'South Africa', 'ZAR', adzuna: 'za', indeed: 'https://za.indeed.com'),
  Country('MX', 'Mexico', 'MXN', adzuna: 'mx', indeed: 'https://mx.indeed.com'),
  Country('BR', 'Brazil', 'BRL', adzuna: 'br', indeed: 'https://br.indeed.com'),
  Country('JP', 'Japan', 'JPY', indeed: 'https://jp.indeed.com'),
  Country('OM', 'Oman', 'OMR', indeed: 'https://om.indeed.com'),
  Country('KW', 'Kuwait', 'KWD', indeed: 'https://kw.indeed.com'),
  Country('BH', 'Bahrain', 'BHD', indeed: 'https://bh.indeed.com'),
];

final byCode = {for (final c in countries) c.code: c};

/// The job sites to search in [country]: Indeed for the country, its own
/// sites, then the global ones.
List<Portal> portalsFor(String country) {
  final c = Country.of(country);
  return [
    if (c?.indeed != null) Portal('Indeed', '${c!.indeed}/jobs?q={q}&l={l}'),
    ...?c?.portals,
    ...globalPortals,
  ];
}
