import 'package:brahma_core/brahma_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vidya/domain/achievements.dart';
import 'package:vidya/domain/book.dart';
import 'package:vidya/domain/stats.dart';
import 'package:vidya/domain/templates.dart';

import 'seed.dart';
import 'support.dart';

const today = '2026-10-24';

Future<LearningBook> openBook() async => LearningBook(await Store.open(memoryDatabase()));

void main() {
  late LearningBook book;
  setUp(() async => book = await openBook());
  tearDown(() => book.db.close());

  test('an empty learner starts at level 1 with nothing earned', () async {
    final s = await book.stats(today);
    expect(s.xp, 0);
    expect(s.level, 1);
    expect(s.rank, 'Seed');
    expect(s.streak, 0);
    expect(await book.unlockNew(today), isEmpty);
  });

  test('levels start at 50·n·(n−1) experience', () {
    expect(Stats.xpFor(2), 100);
    expect(Stats.xpFor(3), 300);
    expect(Stats(today: today).level, 1);
  });

  test('finishing every topic completes the course, then the program; undoing reopens them', () async {
    final pid = await book.addProgram('Test', '', today: today);
    final cid = await book.addCourse('Only course', today: today, programId: pid);
    await book.addTopic(cid, 'One');
    await book.addTopic(cid, 'Two');
    var topics = await book.db.select(book.db.learnTopics).get()
      ..sort((a, b) => a.ord.compareTo(b.ord));
    await book.setTopicDone(topics[0], true, today: today);
    expect((await book.stats(today)).courses.single.status, 'doing');
    await book.setTopicDone(topics[1], true, today: today);
    var s = await book.stats(today);
    expect(s.courses.single.status, 'done');
    expect(s.courses.single.finished, today);
    expect(s.programs.single.status, 'done');
    expect(s.programProgress(s.programs.single), 1);

    topics = await book.db.select(book.db.learnTopics).get()
      ..sort((a, b) => a.ord.compareTo(b.ord));
    await book.setTopicDone(topics[1], false, today: today);
    s = await book.stats(today);
    expect(s.courses.single.status, 'doing');
    expect(s.courses.single.finished, isNull);
    expect(s.programs.single.status, 'active');
  });

  test('a template copies courses, topics and new skills once', () async {
    final t = programTemplates.first;
    await book.importTemplate(t, today: today);
    await book.importTemplate(t, today: today);
    final s = await book.stats(today);
    expect(s.programs, hasLength(2));
    expect(s.courses, hasLength(t.courses.length * 2));
    expect(s.skills, hasLength(t.skills.length));
  });

  test('streak counts back from today, or from yesterday when today is still empty', () async {
    await book.logSession(30, today: today, day: '2026-10-22');
    await book.logSession(30, today: today, day: '2026-10-23');
    var s = await book.stats(today);
    expect(s.streak, 2);
    await book.logSession(30, today: today);
    s = await book.stats(today);
    expect(s.streak, 3);
    expect(s.longestStreak, 3);
    s = await book.stats('2026-10-26');
    expect(s.streak, 0);
    expect(s.longestStreak, 3);
  });

  test('study experience is capped per day', () async {
    await book.logSession(1000, today: today);
    expect((await book.stats(today)).xpStudy, 120);
  });

  test('achievements unlock once, persist, and add experience', () async {
    await book.addTopic(await book.addCourse('c', today: today), 't');
    final topic = (await book.db.select(book.db.learnTopics).get()).single;
    await book.setTopicDone(topic, true, today: today);
    final first = await book.unlockNew(today);
    expect(first.map((a) => a.key), containsAll(['topic-1']));
    expect(await book.unlockNew(today), isEmpty);
    // Undoing the topic does not take the achievement back.
    await book.setTopicDone(topic, false, today: today);
    expect(await book.unlockNew(today), isEmpty);
    expect((await book.db.select(book.db.learnUnlocks).get()).map((u) => u.id), contains('topic-1'));
    final s = await book.stats(today);
    expect(s.xp, s.unlocked * Stats.xpAchievement);
  });

  test('achievement keys are unique and each has a positive target', () {
    expect({for (final a in achievements) a.key}, hasLength(achievements.length));
    expect(achievements.every((a) => a.target > 0), isTrue);
  });

  test('seeded learner: metrics agree with the rows', () async {
    await seedBook(book);
    final s = await book.stats(today);
    expect(s.topicsDone, 5);
    expect(s.assessments, hasLength(3));
    expect(s.averageScore, closeTo((72 + 85 + 91) / 3, 0.001));
    expect(s.bestScore, 91);
    expect(s.streak, greaterThan(0));
    expect(s.weeklyMinutes(), hasLength(8));
    expect(s.weeklyMinutes().fold(0, (a, b) => a + b), s.totalMinutes);
    expect(s.skillsAtTarget, 1);
    expect(s.portfolioScore, inInclusiveRange(1, 100));
    expect(s.quests.where((q) => q.id == 'topic').single.done, isTrue);
    final done = {for (final u in await book.db.select(book.db.learnUnlocks).get()) u.id};
    expect(done, containsAll(['topic-1', 'test-1', 'clear-mind', 'port-1', 'note-1']));
  });

  test('on-time rate compares the finish day with the due date', () async {
    final a = await book.addCourse('Early', today: today, due: '2026-11-01');
    final b = await book.addCourse('Late', today: today, due: '2026-10-01');
    for (final id in [a, b]) {
      final c = await (book.db.select(book.db.learnCourses)..where((x) => x.id.equals(id))).getSingle();
      await book.setCourseStatus(c, 'done', today: today);
    }
    expect((await book.stats(today)).onTimeRate, 0.5);
  });

  test('deleting a program removes its courses and topics', () async {
    final pid = await book.importTemplate(programTemplates.first, today: today);
    await book.removeProgram(pid);
    final s = await book.stats(today);
    expect(s.programs, isEmpty);
    expect(s.courses, isEmpty);
    expect(s.topics, isEmpty);
  });
}
