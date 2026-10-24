import 'package:vidya/domain/book.dart';
import 'package:vidya/domain/review.dart';
import 'package:vidya/domain/templates.dart';

/// A made-up learner, for tests and screenshots. Dates are relative to
/// [today] so streaks and weekly charts have something to show.
Future<void> seedBook(LearningBook book, {String today = '2026-10-24'}) async {
  String day(int ago) =>
      DateTime.parse('${today}T00:00:00Z').subtract(Duration(days: ago)).toIso8601String().substring(0, 10);

  final pid = await book.importTemplate(programTemplates.first, today: day(20));
  final courses = await book.db.select(book.db.learnCourses).get();
  final topics = await book.db.select(book.db.learnTopics).get();
  final first = courses.firstWhere((c) => c.title == 'Programming fundamentals');
  for (final t in topics.where((t) => t.courseId == first.id).take(4)) {
    await book.setTopicDone(t, true, today: day(2));
  }
  final second = courses.firstWhere((c) => c.title == 'Data structures and algorithms');
  for (final t in topics.where((t) => t.courseId == second.id).take(1)) {
    await book.setTopicDone(t, true, today: today);
  }
  for (var i = 0; i < 12; i++) {
    if (i % 4 != 3) await book.logSession(20 + (i * 7) % 50, today: today, courseId: first.id, day: day(i));
  }
  await book.addAssessment('Week 1 quiz', 72, 100, today: day(10), courseId: first.id);
  await book.addAssessment('Week 2 quiz', 85, 100, today: day(4), courseId: first.id);
  await book.addAssessment('Mock exam', 91, 100, today: day(1), courseId: first.id);
  final skills = await book.db.select(book.db.learnSkills).get();
  for (final (i, s) in skills.indexed.take(3)) {
    await book.setSkillLevel(s, i + 1, today: today);
  }
  await book.addPortfolio(
    'Habit tracker app',
    today: day(6),
    kind: 'project',
    skills: 'Programming, Git',
    summary: 'A small app in Dart.',
  );
  await book.addPortfolio('Cloud practitioner', today: day(3), kind: 'certificate', skills: 'Security');
  await book.saveNote(
    'Big-O cheat sheet',
    'Constant, log, linear, n log n, quadratic.',
    'algorithms, revision',
    today: day(1),
  );
  for (final (q, a) in [
    ('What is the time complexity of binary search?', 'O(log n)'),
    ('What does a hash map trade for constant-time lookup?', 'Memory, and order'),
    ('Stack or queue: last in, first out?', 'Stack'),
  ]) {
    await book.saveCard(q, a, today: day(5), deck: 'Algorithms');
  }
  final cards = await book.db.select(book.db.learnCards).get();
  await book.reviewCard(cards.first, Grade.good, today: day(5));
  await book.reviewCard(cards[1], Grade.again, today: day(1));
  await book.unlockNew(today);
  assert(pid.isNotEmpty);
}
