import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';
import 'review.dart';

/// Everything Vidya measures, worked out from the rows. Nothing here is
/// stored: experience, level, streak and the daily quests always agree with
/// the data they come from.
class Stats {
  Stats({
    required this.today,
    this.programs = const [],
    this.courses = const [],
    this.topics = const [],
    this.sessions = const [],
    this.assessments = const [],
    this.skills = const [],
    this.portfolio = const [],
    this.notes = const [],
    this.cards = const [],
    this.reviews = const [],
    this.unlocked = 0,
  }) {
    for (final t in topics) {
      if (t.done != null) _active.add(t.done!);
    }
    for (final s in sessions) {
      _active.add(s.day);
      _minutes[s.day] = (_minutes[s.day] ?? 0) + s.minutes;
    }
    for (final a in assessments) {
      _active.add(a.day);
    }
    for (final p in portfolio) {
      _active.add(p.day);
    }
    for (final n in notes) {
      _active.add(n.created);
    }
    for (final r in reviews) {
      _active.add(r.day);
      _reviewsOn[r.day] = (_reviewsOn[r.day] ?? 0) + 1;
    }
  }

  final String today;
  final List<Program> programs;
  final List<Course> courses;
  final List<Topic> topics;
  final List<StudySession> sessions;
  final List<Assessment> assessments;
  final List<Skill> skills;
  final List<PortfolioItem> portfolio;
  final List<Note> notes;
  final List<Flashcard> cards;
  final List<CardReview> reviews;
  final int unlocked;

  final _active = <String>{};
  final _minutes = <String, int>{};
  final _reviewsOn = <String, int>{};

  // ---- experience and level ----

  static const xpTopic = 20, xpCourse = 100, xpProgram = 250, xpPortfolio = 60, xpNote = 10;
  static const xpReview = 2, xpNewCard = 3;
  static const xpAssessment = 25, xpAssessmentHigh = 25, xpSkillLevel = 15, xpAchievement = 25;

  /// Minutes of study count once, at most four hours a day, so one long
  /// idle session cannot buy a level.
  int get xpStudy => _minutes.values.fold<int>(0, (a, m) => a + math.min(m, 240) ~/ 2);

  /// Reviews count up to 100 a day, so cramming the same cards does not pay.
  int get xpReviews => _reviewsOn.values.fold<int>(0, (a, n) => a + math.min(n, 100) * xpReview);

  int get xp =>
      topicsDone * xpTopic +
      xpReviews +
      cards.length * xpNewCard +
      xpStudy +
      coursesDone * xpCourse +
      programsDone * xpProgram +
      portfolio.length * xpPortfolio +
      notes.length * xpNote +
      assessments.length * xpAssessment +
      assessments.where((a) => _pct(a) >= 80).length * xpAssessmentHigh +
      skills.fold<int>(0, (a, s) => a + s.level * xpSkillLevel) +
      unlocked * xpAchievement;

  /// Level n starts at 50·n·(n−1) experience: 100, 300, 600, 1000...
  static int xpFor(int level) => 50 * level * (level - 1);

  int get level => ((1 + math.sqrt(1 + xp * 4 / 50)) / 2).floor();
  int get levelStart => xpFor(level);
  int get levelEnd => xpFor(level + 1);
  double get levelProgress => (xp - levelStart) / (levelEnd - levelStart);

  static const ranks = [
    'Seed',
    'Sprout',
    'Seedling',
    'Sapling',
    'Bamboo',
    'Pine',
    'Maple',
    'Cedar',
    'Banyan',
    'Sage',
  ];
  String get rank => ranks[math.min(level, ranks.length) - 1];

  // ---- activity ----

  int get totalMinutes => _minutes.values.fold(0, (a, b) => a + b);
  double get hours => totalMinutes / 60;
  int minutesOn(String day) => _minutes[day] ?? 0;
  int get todayMinutes => minutesOn(today);
  bool activeOn(String day) => _active.contains(day);

  /// Consecutive active days ending today; today not yet done does not break
  /// a streak that reached yesterday.
  int get streak {
    var day = _active.contains(today) ? today : addDays(today, -1);
    var n = 0;
    while (_active.contains(day)) {
      n++;
      day = addDays(day, -1);
    }
    return n;
  }

  int get longestStreak {
    final days = _active.toList()..sort();
    var best = 0, run = 0;
    String? prev;
    for (final d in days) {
      run = prev != null && daysBetween(prev, d) == 1 ? run + 1 : 1;
      best = math.max(best, run);
      prev = d;
    }
    return best;
  }

  int activeDaysIn(int days) =>
      [for (var i = 0; i < days; i++) addDays(today, -i)].where(_active.contains).length;

  /// Share of the last 30 days with any learning, 0 to 1.
  double get consistency => activeDaysIn(30) / 30;

  /// Study minutes in each of the last [weeks] blocks of seven days, oldest first.
  List<int> weeklyMinutes([int weeks = 8]) => [
    for (var w = weeks - 1; w >= 0; w--)
      [for (var d = 0; d < 7; d++) minutesOn(addDays(today, -(w * 7 + d)))].fold(0, (a, b) => a + b),
  ];

  /// Minutes on each of the last 7 days, oldest first.
  List<int> get lastWeek => [for (var d = 6; d >= 0; d--) minutesOn(addDays(today, -d))];

  // ---- curriculum ----

  int get topicsDone => topics.where((t) => t.done != null).length;
  int get topicsToday => topics.where((t) => t.done == today).length;
  int get coursesDone => courses.where((c) => c.status == 'done').length;
  int get coursesDoing => courses.where((c) => c.status == 'doing').length;
  int get programsDone => programs.where((p) => p.status == 'done').length;

  List<Topic> topicsOf(String courseId) =>
      topics.where((t) => t.courseId == courseId).toList()..sort((a, b) => a.ord.compareTo(b.ord));

  /// Finished share of a course's topics, 0 to 1 (1 when the course is done).
  double courseProgress(Course c) {
    if (c.status == 'done') return 1;
    final t = topicsOf(c.id);
    return t.isEmpty ? 0 : t.where((x) => x.done != null).length / t.length;
  }

  double programProgress(Program p) {
    final cs = courses.where((c) => c.programId == p.id && c.status != 'dropped').toList();
    if (cs.isEmpty) return p.status == 'done' ? 1 : 0;
    return cs.fold(0.0, (a, c) => a + courseProgress(c)) / cs.length;
  }

  /// Hours studied for a course.
  double hoursOn(String courseId) =>
      sessions.where((s) => s.courseId == courseId).fold(0, (a, s) => a + s.minutes) / 60;

  /// Courses finished by their due date, among those with one: 0 to 1, null
  /// when none has been finished with a due date.
  double? get onTimeRate {
    final dated = courses.where((c) => c.status == 'done' && c.due != null && c.finished != null).toList();
    if (dated.isEmpty) return null;
    return dated.where((c) => c.finished!.compareTo(c.due!) <= 0).length / dated.length;
  }

  List<Course> get overdue => courses
      .where(
        (c) => (c.status == 'doing' || c.status == 'planned') && c.due != null && c.due!.compareTo(today) < 0,
      )
      .toList();

  // ---- assessments ----

  static double _pct(Assessment a) => a.max <= 0 ? 0 : a.score * 100 / a.max;
  static double percentOf(Assessment a) => _pct(a);

  double? get averageScore =>
      assessments.isEmpty ? null : assessments.fold(0.0, (a, x) => a + _pct(x)) / assessments.length;

  /// Percent scores in date order, for the trend line.
  List<double> get scoreTrend =>
      (assessments.toList()..sort((a, b) => a.day.compareTo(b.day))).map(_pct).toList();

  double get bestScore => assessments.fold(0.0, (a, x) => math.max(a, _pct(x)));

  // ---- skills and portfolio ----

  int get skillsAtTarget => skills.where((s) => s.level >= s.target).length;
  int get topSkills => skills.where((s) => s.level >= 5).length;

  /// Average skill level against the average target, 0 to 1.
  double get mastery {
    final goal = skills.fold(0, (a, s) => a + s.target);
    return goal == 0 ? 0 : (skills.fold(0, (a, s) => a + math.min(s.level, s.target)) / goal);
  }

  int get portfolioKinds => portfolio.map((p) => p.kind).toSet().length;

  /// How strong the portfolio is as evidence, 0 to 100: volume, variety and
  /// how many skills it backs.
  int get portfolioScore {
    final backed = <String>{
      for (final p in portfolio)
        ...p.skills.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
    };
    final skillNames = skills.map((s) => s.name.toLowerCase()).toSet();
    final cover = skillNames.isEmpty ? 0 : backed.where(skillNames.contains).length / skillNames.length;
    return (math.min(portfolio.length, 6) * 8 + math.min(portfolioKinds, 4) * 8 + cover * 20).round().clamp(
      0,
      100,
    );
  }

  /// Skills the portfolio does not yet show.
  List<Skill> get unbackedSkills {
    final backed = <String>{
      for (final p in portfolio)
        ...p.skills.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty),
    };
    return skills.where((s) => s.level > 0 && !backed.contains(s.name.toLowerCase())).toList();
  }

  // ---- flashcards ----

  List<Flashcard> get dueCards =>
      cards.where((c) => c.due.compareTo(today) <= 0).toList()
        ..sort((a, b) => a.due == b.due ? a.created.compareTo(b.created) : a.due.compareTo(b.due));
  int get reviewsToday => _reviewsOn[today] ?? 0;
  int get reviewsTotal => reviews.length;
  int get matureCards => cards.where((c) => c.interval >= matureDays).length;

  /// Share of reviews in the last 30 days that were remembered, null with none.
  double? get retention {
    final since = addDays(today, -29);
    final recent = reviews.where((r) => r.day.compareTo(since) >= 0).toList();
    if (recent.isEmpty) return null;
    return recent.where((r) => r.grade > Grade.again.index).length / recent.length;
  }

  /// Cards due on each of the next [days] days, today (with any overdue) first.
  List<int> forecast([int days = 7]) => [
    for (var d = 0; d < days; d++)
      cards.where((c) => d == 0 ? c.due.compareTo(today) <= 0 : c.due == addDays(today, d)).length,
  ];

  /// The longest single study session, in minutes.
  int get longestSession => sessions.fold(0, (a, s) => math.max(a, s.minutes));

  // ---- daily quests ----

  List<Quest> get quests => [
    Quest('study', 'Study for 25 minutes', todayMinutes >= 25, 12, '${math.min(todayMinutes, 25)}/25 min'),
    Quest('topic', 'Finish a topic', topicsToday >= 1, 20, '$topicsToday/1'),
    Quest('note', 'Capture a note', notes.any((n) => n.created == today), 10, null),
    // Only once there are cards to review; done when today's queue is empty.
    if (cards.isNotEmpty)
      Quest(
        'review',
        'Clear today’s reviews',
        reviewsToday > 0 && dueCards.isEmpty,
        10,
        dueCards.isEmpty ? null : '${dueCards.length} due',
      ),
  ];

  /// Overall progress for the day, 0 to 1.
  double get questProgress => quests.where((q) => q.done).length / quests.length;
}

class Quest {
  const Quest(this.id, this.title, this.done, this.xp, this.detail);
  final String id, title;
  final bool done;
  final int xp;
  final String? detail;
}
