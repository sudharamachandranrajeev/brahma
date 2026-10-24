import 'package:brahma_core/brahma_core.dart';
import 'package:drift/drift.dart';

// Table names are unique across the Brahma suite: every app on an account
// reads the same change log and applies only its own tables. Udyoga's all
// start with `job_` or `career_`.
//
// Dates are yyyy-MM-dd, times local yyyy-MM-ddTHH:mm. JSON columns hold what
// the AI returned (see domain/advisor.dart) and are read through the domain
// models, never shown raw.

/// An opening, from a job feed, the AI search or typed in.
@DataClassName('Job')
class JobListings extends Table with SyncedRow {
  TextColumn get title => text()();
  TextColumn get company => text().withDefault(const Constant(''))();
  TextColumn get location => text().withDefault(const Constant(''))();

  /// ISO 3166 alpha-2, upper case ('GB', 'IE', 'IN'); '' when unknown.
  TextColumn get country => text().withDefault(const Constant(''))();
  BoolColumn get remote => boolean().withDefault(const Constant(false))();

  /// Yearly figures in [currency] when the advert gives them.
  IntColumn get salaryMin => integer().nullable()();
  IntColumn get salaryMax => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant(''))();

  /// The advert's own wording ("£24,000 - £26,500 a year", "Band 4").
  TextColumn get salaryText => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get posted => text().nullable()();
  TextColumn get closing => text().nullable()();

  /// adzuna | reed | arbeitnow | remotive | jobicy | ai | manual; with the
  /// source's own id, so a refresh updates instead of duplicating.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get sourceId => text().withDefault(const Constant(''))();
  TextColumn get found => text()();

  /// new | saved | dismissed | applied
  TextColumn get status => text().withDefault(const Constant('new'))();

  /// 0 to 100: the AI's when it has assessed the job, else the local match.
  IntColumn get fit => integer().nullable()();

  /// The AI's assessment (FitAssessment), '' until asked.
  TextColumn get assessment => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// An application and where it stands.
@DataClassName('JobApplication')
class JobApplications extends Table with SyncedRow {
  TextColumn get jobId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get company => text().withDefault(const Constant(''))();
  TextColumn get location => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();

  /// See domain/pipeline.dart.
  TextColumn get stage => text().withDefault(const Constant('preparing'))();
  TextColumn get applied => text().nullable()();

  /// When to chase it up, and what to ask.
  TextColumn get followUp => text().nullable()();
  TextColumn get followUpNote => text().withDefault(const Constant(''))();

  /// The CV sent (career_resumes id).
  TextColumn get resumeId => text().nullable()();
  TextColumn get reference => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Last change of stage, for "no reply in N days".
  TextColumn get updated => text()();
}

/// What happened on an application: sent, chased, heard back, interviews.
@DataClassName('JobEvent')
class JobEvents extends Table with SyncedRow {
  TextColumn get applicationId => text()();
  TextColumn get at => text()();

  /// applied | followup | reply | interview | offer | rejected | withdrawn | note
  TextColumn get kind => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
}

/// Recruiters, hiring managers, referrers and other leads.
@DataClassName('Lead')
class CareerContacts extends Table with SyncedRow {
  TextColumn get name => text()();

  /// recruiter | hiring_manager | referral | peer | mentor | other
  TextColumn get kind => text().withDefault(const Constant('recruiter'))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get company => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get linkedin => text().withDefault(const Constant(''))();

  /// Where the lead was found (a team page, a job advert...).
  TextColumn get source => text().withDefault(const Constant(''))();

  /// new | contacted | replied | cold
  TextColumn get status => text().withDefault(const Constant('new'))();
  TextColumn get lastContact => text().nullable()();
  TextColumn get followUp => text().nullable()();
  TextColumn get jobId => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// CVs: the base one made from the profile and those tailored to a job.
@DataClassName('Resume')
class CareerResumes extends Table with SyncedRow {
  TextColumn get name => text()();
  TextColumn get jobId => text().nullable()();
  TextColumn get created => text()();

  /// ResumeDoc as JSON.
  TextColumn get content => text()();

  /// What was changed for the job, keyword cover and cautions (TailorNotes).
  TextColumn get tailoring => text().withDefault(const Constant(''))();
}

/// AI reports: profile assessment, career map, market scans. Kept so they can
/// be compared over time; the newest of each kind is the current one.
@DataClassName('Report')
class CareerReports extends Table with SyncedRow {
  /// assessment | career_map
  TextColumn get kind => text()();
  TextColumn get created => text()();
  TextColumn get content => text()();

  /// Web pages the AI read for it, as JSON [{title, url}].
  TextColumn get sources => text().withDefault(const Constant('[]'))();
}

/// Self-improvement: certifications, courses, degrees, skills and goals.
@DataClassName('GrowthItem')
class CareerGrowth extends Table with SyncedRow {
  TextColumn get title => text()();

  /// certification | course | degree | skill | experience | goal
  TextColumn get kind => text()();
  TextColumn get provider => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();
  TextColumn get why => text().withDefault(const Constant(''))();
  TextColumn get cost => text().withDefault(const Constant(''))();
  TextColumn get duration => text().withDefault(const Constant(''))();

  /// suggested | planned | doing | done | dropped
  TextColumn get status => text().withDefault(const Constant('suggested'))();

  /// 0 to 100.
  IntColumn get progress => integer().withDefault(const Constant(0))();
  TextColumn get target => text().nullable()();
  TextColumn get done => text().nullable()();

  /// The career path it serves, by name, when it came from the map.
  TextColumn get path => text().withDefault(const Constant(''))();
  TextColumn get added => text()();
}

/// An interview practice round.
@DataClassName('PracticeSession')
class CareerPractice extends Table with SyncedRow {
  TextColumn get jobId => text().nullable()();
  TextColumn get role => text()();

  /// standard | competency | technical | toughest | ai
  TextColumn get mode => text()();
  TextColumn get started => text()();

  /// The question set (PracticeQuestion list as JSON).
  TextColumn get questions => text()();

  /// Mean of the scored answers, 0 to 10.
  RealColumn get score => real().nullable()();
}

/// One answer in a practice round and its evaluation.
@DataClassName('PracticeAnswer')
class CareerAnswers extends Table with SyncedRow {
  TextColumn get sessionId => text()();
  IntColumn get question => integer()();
  TextColumn get answer => text()();
  TextColumn get at => text()();

  /// AnswerReview as JSON, '' until evaluated.
  TextColumn get review => text().withDefault(const Constant(''))();
  RealColumn get score => real().nullable()();
}

@DataClassName('Pref')
class Prefs extends Table with SyncedRow, PrefColumns {}

@DataClassName('OutboxItem')
class Outbox extends Table with OutboxColumns {}

@DataClassName('SyncCursor')
class SyncCursors extends Table with SyncCursorColumns {}

@DataClassName('LocalSetting')
class LocalSettings extends Table with LocalSettingColumns {}
