import 'json.dart';
import 'schema.dart';

/// A job held, from the CV.
class Experience {
  const Experience({
    this.title = '',
    this.organisation = '',
    this.location = '',
    this.start = '',
    this.end = '',
    this.highlights = const [],
  });
  final String title, organisation, location;

  /// As written on the CV, ideally yyyy-MM; [end] is '' while current.
  final String start, end;
  final List<String> highlights;

  bool get current => end.isEmpty || end.toLowerCase() == 'present';

  factory Experience.fromJson(Json j) => Experience(
    title: str(j['title']),
    organisation: str(j['organisation']),
    location: str(j['location']),
    start: str(j['start']),
    end: str(j['end']),
    highlights: strs(j['highlights']),
  );

  Json toJson() => {
    'title': title,
    'organisation': organisation,
    'location': location,
    'start': start,
    'end': end,
    'highlights': highlights,
  };

  static final schema = object({
    'title': string(),
    'organisation': string(),
    'location': string(),
    'start': string('yyyy-MM when known, else as written'),
    'end': string("yyyy-MM, or '' if this is the current job"),
    'highlights': strings('Responsibilities and achievements, one per item, as on the CV'),
  });
}

class Education {
  const Education({this.qualification = '', this.institution = '', this.year = '', this.grade = ''});
  final String qualification, institution, year, grade;

  factory Education.fromJson(Json j) => Education(
    qualification: str(j['qualification']),
    institution: str(j['institution']),
    year: str(j['year']),
    grade: str(j['grade']),
  );

  Json toJson() => {'qualification': qualification, 'institution': institution, 'year': year, 'grade': grade};

  static final schema = object({
    'qualification': string(),
    'institution': string(),
    'year': string(),
    'grade': string(),
  });
}

/// What the candidate is looking for.
class Targets {
  const Targets({
    this.roles = const [],
    this.keywords = const [],
    this.countries = const [],
    this.locations = const [],
    this.workModes = const [],
    this.salaryMin,
    this.salaryCurrency = '',
    this.notes = '',
  });

  /// Job titles to aim for.
  final List<String> roles;

  /// Search terms for the job feeds.
  final List<String> keywords;

  /// ISO alpha-2 codes, the current country first.
  final List<String> countries;

  /// Towns or regions to search in ('' or none: anywhere in the country).
  final List<String> locations;

  /// onsite | hybrid | remote
  final List<String> workModes;
  final int? salaryMin;
  final String salaryCurrency;

  /// Right to work, notice period, relocation, hours, anything else.
  final String notes;

  bool get remote => workModes.contains('remote');

  factory Targets.fromJson(Json j) => Targets(
    roles: strs(j['roles']),
    keywords: strs(j['keywords']),
    countries: strs(j['countries']).map((c) => c.toUpperCase()).toList(),
    locations: strs(j['locations']),
    workModes: strs(j['workModes']),
    salaryMin: switch (intOf(j['salaryMin'])) {
      final v? when v > 0 => v,
      _ => null,
    },
    salaryCurrency: str(j['salaryCurrency']),
    notes: str(j['notes']),
  );

  Json toJson() => {
    'roles': roles,
    'keywords': keywords,
    'countries': countries,
    'locations': locations,
    'workModes': workModes,
    'salaryMin': salaryMin,
    'salaryCurrency': salaryCurrency,
    'notes': notes,
  };

  Targets copyWith({
    List<String>? roles,
    List<String>? keywords,
    List<String>? countries,
    List<String>? locations,
    List<String>? workModes,
    int? salaryMin,
    bool clearSalary = false,
    String? salaryCurrency,
    String? notes,
  }) => Targets(
    roles: roles ?? this.roles,
    keywords: keywords ?? this.keywords,
    countries: countries ?? this.countries,
    locations: locations ?? this.locations,
    workModes: workModes ?? this.workModes,
    salaryMin: clearSalary ? null : salaryMin ?? this.salaryMin,
    salaryCurrency: salaryCurrency ?? this.salaryCurrency,
    notes: notes ?? this.notes,
  );
}

/// The candidate: who they are, what they have done and what they want.
/// One per account, kept as a synced pref.
class CandidateProfile {
  const CandidateProfile({
    this.name = '',
    this.headline = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.country = '',
    this.linkedin = '',
    this.website = '',
    this.currentRole = '',
    this.currentEmployer = '',
    this.yearsExperience,
    this.summary = '',
    this.experience = const [],
    this.education = const [],
    this.skills = const [],
    this.certifications = const [],
    this.achievements = const [],
    this.languages = const [],
    this.targets = const Targets(),
    this.cvText = '',
  });

  final String name, headline, email, phone, location;

  /// Where the candidate lives and works now, ISO alpha-2.
  final String country;
  final String linkedin, website, currentRole, currentEmployer;
  final double? yearsExperience;
  final String summary;
  final List<Experience> experience;
  final List<Education> education;
  final List<String> skills, certifications, achievements, languages;
  final Targets targets;

  /// The CV as imported, for the AI to read alongside the fields.
  final String cvText;

  bool get isEmpty => name.isEmpty && currentRole.isEmpty && experience.isEmpty && cvText.isEmpty;

  /// Countries to look in: the targets, else the home country.
  List<String> get searchCountries =>
      targets.countries.isNotEmpty ? targets.countries : [if (country.isNotEmpty) country];

  /// Search terms: the chosen keywords, else target roles, else the current role.
  List<String> get searchTerms => targets.keywords.isNotEmpty
      ? targets.keywords
      : targets.roles.isNotEmpty
      ? targets.roles
      : [if (currentRole.isNotEmpty) currentRole];

  factory CandidateProfile.fromJson(Json j) => CandidateProfile(
    name: str(j['name']),
    headline: str(j['headline']),
    email: str(j['email']),
    phone: str(j['phone']),
    location: str(j['location']),
    country: str(j['country']).toUpperCase(),
    linkedin: str(j['linkedin']),
    website: str(j['website']),
    currentRole: str(j['currentRole']),
    currentEmployer: str(j['currentEmployer']),
    yearsExperience: numOf(j['yearsExperience']),
    summary: str(j['summary']),
    experience: objs(j['experience']).map(Experience.fromJson).toList(),
    education: objs(j['education']).map(Education.fromJson).toList(),
    skills: strs(j['skills']),
    certifications: strs(j['certifications']),
    achievements: strs(j['achievements']),
    languages: strs(j['languages']),
    targets: Targets.fromJson(obj(j['targets'])),
    cvText: j['cvText'] is String ? j['cvText'] as String : '',
  );

  Json toJson() => {
    'name': name,
    'headline': headline,
    'email': email,
    'phone': phone,
    'location': location,
    'country': country,
    'linkedin': linkedin,
    'website': website,
    'currentRole': currentRole,
    'currentEmployer': currentEmployer,
    'yearsExperience': yearsExperience,
    'summary': summary,
    'experience': [for (final e in experience) e.toJson()],
    'education': [for (final e in education) e.toJson()],
    'skills': skills,
    'certifications': certifications,
    'achievements': achievements,
    'languages': languages,
    'targets': targets.toJson(),
    'cvText': cvText,
  };

  /// What the AI is told about the candidate: everything but the raw CV
  /// when the fields already carry it.
  Json forPrompt() {
    final j = toJson();
    if (experience.isNotEmpty && cvText.length > 12000) j.remove('cvText');
    return j;
  }

  CandidateProfile copyWith({
    String? name,
    String? headline,
    String? email,
    String? phone,
    String? location,
    String? country,
    String? linkedin,
    String? website,
    String? currentRole,
    String? currentEmployer,
    double? yearsExperience,
    String? summary,
    List<Experience>? experience,
    List<Education>? education,
    List<String>? skills,
    List<String>? certifications,
    List<String>? achievements,
    List<String>? languages,
    Targets? targets,
    String? cvText,
  }) => CandidateProfile(
    name: name ?? this.name,
    headline: headline ?? this.headline,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    location: location ?? this.location,
    country: country ?? this.country,
    linkedin: linkedin ?? this.linkedin,
    website: website ?? this.website,
    currentRole: currentRole ?? this.currentRole,
    currentEmployer: currentEmployer ?? this.currentEmployer,
    yearsExperience: yearsExperience ?? this.yearsExperience,
    summary: summary ?? this.summary,
    experience: experience ?? this.experience,
    education: education ?? this.education,
    skills: skills ?? this.skills,
    certifications: certifications ?? this.certifications,
    achievements: achievements ?? this.achievements,
    languages: languages ?? this.languages,
    targets: targets ?? this.targets,
    cvText: cvText ?? this.cvText,
  );

  /// The shape the AI fills in when reading a CV.
  static final schema = object({
    'name': string(),
    'headline': string('One line: current role and specialism'),
    'email': string(),
    'phone': string(),
    'location': string('Town or city'),
    'country': string('ISO 3166 alpha-2 code of the country they live in, upper case'),
    'linkedin': string(),
    'website': string(),
    'currentRole': string(),
    'currentEmployer': string(),
    'yearsExperience': number('Total years of work experience; 0 if unclear'),
    'summary': string('The personal statement or profile from the CV, as written'),
    'experience': array(Experience.schema, description: 'Most recent first'),
    'education': array(Education.schema),
    'skills': strings(),
    'certifications': strings('Professional certifications and licences held'),
    'achievements': strings('Awards and measurable results not tied to one job'),
    'languages': strings(),
    'targets': object({
      'roles': strings('Job titles the CV says they want, or the natural next roles'),
      'keywords': strings('3 to 6 short job-board search terms that would find suitable openings'),
      'countries': strings('ISO alpha-2 codes, the current country first'),
      'locations': strings('The home town or region'),
      'workModes': array(oneOf(['onsite', 'hybrid', 'remote'])),
      'salaryMin': integer('Yearly minimum if stated, else 0'),
      'salaryCurrency': string('ISO 4217'),
      'notes': string(),
    }),
  });
}
