import 'json.dart';
import 'schema.dart';

// What the AI hands back, each with the schema it answers in. Readers are
// lenient (see json.dart) so an older stored report still opens.

/// AI exposure of a role or path.
const exposureLevels = ['low', 'medium', 'high'];

class AiOutlook {
  const AiOutlook({
    this.exposure = 'medium',
    this.summary = '',
    this.atRisk = const [],
    this.growing = const [],
    this.skills = const [],
  });
  final String exposure, summary;
  final List<String> atRisk, growing, skills;

  factory AiOutlook.fromJson(Json j) => AiOutlook(
    exposure: str(j['exposure']),
    summary: str(j['summary']),
    atRisk: strs(j['tasksAtRisk']),
    growing: strs(j['tasksGrowing']),
    skills: strs(j['skillsToBuild']),
  );

  static final schema = object({
    'exposure': oneOf(exposureLevels, 'How much of the work AI is likely to change within 3 years'),
    'summary': string('What AI is already doing in this field and what that means for the candidate'),
    'tasksAtRisk': strings('Parts of the job being automated'),
    'tasksGrowing': strings('Parts growing in value'),
    'skillsToBuild': strings('Concrete AI and digital skills that keep the candidate ahead'),
  });
}

/// A learning step: certification, course, degree, skill or experience.
class LearningSuggestion {
  const LearningSuggestion({
    required this.title,
    this.kind = 'course',
    this.provider = '',
    this.url = '',
    this.cost = '',
    this.duration = '',
    this.why = '',
    this.priority = 'valuable',
  });
  final String title, kind, provider, url, cost, duration, why, priority;

  factory LearningSuggestion.fromJson(Json j) => LearningSuggestion(
    title: str(j['title']),
    kind: str(j['kind']),
    provider: str(j['provider']),
    url: str(j['url']),
    cost: str(j['cost']),
    duration: str(j['duration']),
    why: str(j['why']),
    priority: str(j['priority']),
  );

  static final schema = object({
    'title': string(),
    'kind': oneOf(['certification', 'course', 'degree', 'skill', 'experience']),
    'provider': string('Awarding body or provider'),
    'url': string('Official page'),
    'cost': string('Typical cost with currency, or "free"'),
    'duration': string('Typical time to complete'),
    'why': string('What it unlocks for this candidate, concretely'),
    'priority': oneOf(['essential', 'valuable', 'optional']),
  });
}

/// The deep, candid assessment of the candidate in today's market.
class Assessment {
  const Assessment(this.j);
  final Json j;

  String get verdict => str(j['verdict']);
  String get level => str(obj(j['marketPosition'])['level']);
  String get competitiveness => str(obj(j['marketPosition'])['competitiveness']);
  String get position => str(obj(j['marketPosition'])['summary']);
  List<Json> get strengths => objs(j['strengths']);
  List<Json> get weaknesses => objs(j['weaknesses']);
  List<Json> get challenges => objs(j['toughestChallenges']);
  AiOutlook get ai => AiOutlook.fromJson(obj(j['aiImpact']));
  List<Json> get targetRoles => objs(j['targetRoles']);
  List<Json> get countries => objs(j['countries']);
  List<LearningSuggestion> get learning => objs(j['learning']).map(LearningSuggestion.fromJson).toList();
  List<String> get quickWins => strs(j['quickWins']);
  List<String> get searchTerms => [for (final r in targetRoles) ...strs(r['searchTerms'])];

  static final schema = object({
    'verdict': string('Two or three plain sentences: where the candidate really stands and what to do next'),
    'marketPosition': object({
      'level': string(
        'Seniority band, e.g. "Entry", "Mid-level", "Senior", with the local grade if public sector',
      ),
      'competitiveness': oneOf(['strong', 'average', 'weak']),
      'summary': string(),
    }),
    'strengths': array(object({'point': string(), 'evidence': string('From the CV')})),
    'weaknesses': array(object({'point': string(), 'fix': string()})),
    'toughestChallenges': array(
      object({'challenge': string(), 'why': string(), 'prepare': string('How to prepare, step by step')}),
      description: 'The hardest obstacles to the next move, stated bluntly',
    ),
    'aiImpact': AiOutlook.schema,
    'targetRoles': array(
      object({
        'title': string(),
        'why': string(),
        'fit': integer('0 to 100, today'),
        'salaryRange': string('Current range with currency and source year'),
        'searchTerms': strings('Job-board search terms for this role'),
      }),
    ),
    'countries': array(
      object({
        'country': string('ISO alpha-2'),
        'demand': oneOf(['high', 'moderate', 'low']),
        'salaryRange': string(),
        'rightToWork': string('Visa route or right-to-work position for this candidate'),
        'verdict': string(),
      }),
      description: 'The current country first, then realistic alternatives',
    ),
    'learning': array(LearningSuggestion.schema),
    'quickWins': strings('Things to do this week'),
    'sources': sourcesSchema,
  });
}

const pathDirections = ['vertical', 'lateral', 'specialist', 'management', 'pivot', 'independent'];
const realismLevels = ['likely', 'possible', 'ambitious'];

/// A role on a career path.
class PathStep {
  const PathStep(this.j);
  final Json j;
  String get role => str(j['role']);
  String get timeframe => str(j['timeframe']);
  String get salary => str(j['salaryRange']);
  int get likelihood => intOf(j['likelihood']) ?? 0;
  List<String> get requirements => strs(j['requirements']);
  List<String> get certifications => strs(j['certifications']);
  List<String> get employers => strs(j['employers']);

  static final schema = object({
    'role': string(),
    'timeframe': string('From now, e.g. "1-2 years"'),
    'salaryRange': string('Current range with currency'),
    'likelihood': integer('0 to 100 that the candidate reaches it on this path'),
    'requirements': strings('Experience, skills and qualifications needed'),
    'certifications': strings(),
    'employers': strings('Typical employers in the candidate\'s countries'),
  });
}

class CareerPath {
  const CareerPath(this.j);
  final Json j;
  String get name => str(j['name']);
  String get direction => str(j['direction']);
  String get realism => str(j['realism']);
  String get summary => str(j['summary']);
  AiOutlook get ai => AiOutlook.fromJson(obj(j['aiOutlook']));
  List<PathStep> get steps => objs(j['steps']).map(PathStep.new).toList();
  List<String> get risks => strs(j['risks']);
  List<String> get firstMoves => strs(j['firstMoves']);

  static final schema = object({
    'name': string('Short name, e.g. "Into management"'),
    'direction': oneOf(pathDirections),
    'realism': oneOf(realismLevels),
    'summary': string(),
    'aiOutlook': AiOutlook.schema,
    'steps': array(PathStep.schema, description: 'Two to four roles in order, after the current one'),
    'risks': strings(),
    'firstMoves': strings('What to do in the next three months'),
  });
}

/// Every realistic way on from the current role.
class CareerMap {
  const CareerMap(this.j);
  final Json j;
  String get current => str(obj(j['current'])['role']);
  String get currentSummary => str(obj(j['current'])['summary']);
  List<CareerPath> get paths => objs(j['paths']).map(CareerPath.new).toList();
  String get recommended => str(j['recommended']);
  String get rationale => str(j['rationale']);
  List<String> get trends => strs(j['marketTrends']);

  static final schema = object({
    'current': object({'role': string(), 'level': string(), 'summary': string()}),
    'paths': array(CareerPath.schema, description: 'Five to eight distinct paths'),
    'recommended': string('Name of the path you recommend'),
    'rationale': string(),
    'marketTrends': strings('Current trends in hiring for this field, with dates'),
    'sources': sourcesSchema,
  });
}

const fitVerdicts = ['strong', 'good', 'stretch', 'long_shot', 'unsuitable'];

/// How well the candidate fits one job, and how to apply.
class FitAssessment {
  const FitAssessment(this.j);
  final Json j;
  int get fit => intOf(j['fit']) ?? 0;
  String get verdict => str(j['verdict']);
  String get summary => str(j['summary']);
  String get odds => str(j['odds']);
  List<Json> get matched => objs(j['matched']);
  List<Json> get gaps => objs(j['gaps']);
  List<String> get redFlags => strs(j['redFlags']);
  String get salary => str(j['salary']);
  String get employer => str(j['employer']);
  List<String> get responsibilities => strs(j['keyResponsibilities']);
  List<String> get keywords => strs(j['keywords']);
  List<String> get tips => strs(j['applicationTips']);
  List<String> get interviewFocus => strs(j['interviewFocus']);
  String get closing => str(j['closingDate']);

  static final schema = object({
    'fit': integer('0 to 100, honest: 70+ only if the candidate meets nearly all essential criteria'),
    'verdict': oneOf(fitVerdicts),
    'summary': string(),
    'odds': string('Realistic chance of interview and offer, and why'),
    'keyResponsibilities': strings('From the advert'),
    'matched': array(object({'requirement': string(), 'evidence': string('From the CV')})),
    'gaps': array(
      object({
        'requirement': string(),
        'severity': oneOf(['blocker', 'major', 'minor']),
        'mitigation': string(),
      }),
    ),
    'redFlags': strings('Concerns about the job or employer'),
    'salary': string('The pay against the market and the candidate\'s minimum'),
    'employer': string('What the employer is like, recent news, culture, from research'),
    'keywords': strings('Words from the advert the CV must contain'),
    'applicationTips': strings(),
    'interviewFocus': strings('What the interview will probe'),
    'closingDate': string("yyyy-MM-dd if found, else ''"),
    'sources': sourcesSchema,
  });
}

/// What tailoring a CV changed, and what to check before sending.
class TailorNotes {
  const TailorNotes(this.j);
  final Json j;
  List<String> get changes => strs(j['changes']);
  List<String> get covered => strs(j['keywordsCovered']);
  List<String> get missing => strs(j['keywordsMissing']);
  List<String> get cautions => strs(j['cautions']);
  String get coverLetter => str(j['coverLetter']);
  int get atsScore => intOf(j['atsScore']) ?? 0;
}

/// A job found by the AI's web search.
class FoundJob {
  const FoundJob(this.j);
  final Json j;

  static final schema = object({
    'jobs': array(
      object({
        'title': string(),
        'company': string(),
        'location': string(),
        'country': string('ISO alpha-2'),
        'remote': boolean(),
        'url': string('The advert itself, not a search page'),
        'salaryText': string(),
        'posted': string("yyyy-MM-dd or ''"),
        'closing': string("yyyy-MM-dd or ''"),
        'description': string('Summary of the role, key responsibilities and essential criteria'),
        'site': string('Where it is advertised'),
        'fit': integer('0 to 100 for this candidate'),
        'why': string('One line: why it suits, or the main gap'),
      }),
    ),
    'sources': sourcesSchema,
  });
}

/// A lead the AI found: someone worth contacting about openings.
class LeadSuggestion {
  const LeadSuggestion(this.j);
  final Json j;
  String get name => str(j['name']);
  String get title => str(j['title']);
  String get company => str(j['company']);
  String get kind => str(j['kind']);
  String get linkedin => str(j['linkedin']);
  String get email => str(j['email']);
  String get source => str(j['source']);
  String get why => str(j['why']);
  String get approach => str(j['approach']);

  static final schema = object({
    'leads': array(
      object({
        'name': string('A person, or a team such as "Recruitment team" when no person is public'),
        'title': string(),
        'company': string(),
        'kind': oneOf(['recruiter', 'hiring_manager', 'referral', 'peer', 'mentor', 'other']),
        'linkedin': string("Public profile or company page URL, or ''"),
        'email': string("Only an address published for job enquiries, else ''"),
        'source': string('Page where this was found'),
        'why': string(),
        'approach': string('How to make contact and what to say first'),
      }),
    ),
    'sources': sourcesSchema,
  });
}

/// A short message to send (outreach, chasing feedback, thanks).
class Draft {
  const Draft(this.j);
  final Json j;
  String get subject => str(j['subject']);
  String get message => str(j['message']);

  static final schema = object({'subject': string(), 'message': string()});
}

const practiceModes = {
  'standard': 'Mixed: the questions this interview is most likely to ask',
  'competency': 'Competency and values based (STAR answers)',
  'technical': 'Role knowledge and technical',
  'toughest': 'Toughest panel: hard follow-ups, pressure and curve balls',
  'ai': 'AI and change: how the role is changing and how you will keep up',
};

class PracticeQuestion {
  const PracticeQuestion(this.j);
  final Json j;
  String get question => str(j['question']);
  String get category => str(j['category']);
  String get why => str(j['why']);
  List<String> get lookFor => strs(j['lookFor']);
  String get difficulty => str(j['difficulty']);

  static final schema = object({
    'questions': array(
      object({
        'question': string(),
        'category': string('e.g. Behavioural, Values, Technical, Situational, Motivation, AI'),
        'why': string('What the panel is testing'),
        'lookFor': strings('What a top answer includes'),
        'difficulty': oneOf(['standard', 'hard', 'toughest']),
      }),
    ),
    'sources': sourcesSchema,
  });
}

/// The dimensions every answer is scored on, 0 to 10.
const reviewDimensions = [
  'Relevance',
  'Structure',
  'Evidence',
  'Impact',
  'Communication',
  'Role knowledge',
  'AI and change readiness',
];

class AnswerReview {
  const AnswerReview(this.j);
  final Json j;
  double get score => numOf(j['score']) ?? 0;
  String get rating => str(j['rating']);
  List<({String name, int score, String comment})> get dimensions => [
    for (final d in objs(j['dimensions']))
      (name: str(d['name']), score: intOf(d['score']) ?? 0, comment: str(d['comment'])),
  ];
  List<String> get strengths => strs(j['strengths']);
  List<String> get improvements => strs(j['improvements']);
  List<String> get redFlags => strs(j['redFlags']);
  String get better => str(j['betterAnswer']);
  String get followUp => str(j['followUp']);

  static final schema = object({
    'score': number('0 to 10 overall, one decimal; 7 is a solid answer, 9+ is rare'),
    'rating': oneOf(['outstanding', 'strong', 'adequate', 'weak', 'poor']),
    'dimensions': array(
      object({'name': oneOf(reviewDimensions), 'score': integer('0 to 10'), 'comment': string()}),
      description: 'One per dimension, in the order given',
    ),
    'strengths': strings(),
    'improvements': strings('Specific changes, most important first'),
    'redFlags': strings('Anything that would worry a panel'),
    'betterAnswer': string(
      'A stronger version in the candidate\'s own voice, using only their real experience',
    ),
    'followUp': string('The probing follow-up a tough interviewer would ask next'),
  });
}
