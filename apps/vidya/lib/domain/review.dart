import 'dart:math' as math;

import 'package:brahma_core/brahma_core.dart';

import '../db/database.dart';

/// How well a card was remembered.
enum Grade {
  again('Again'),
  hard('Hard'),
  good('Good'),
  easy('Easy');

  const Grade(this.label);
  final String label;
}

/// A card's schedule after one review.
typedef Schedule = ({int interval, double ease, int reps, int lapses, String due});

/// A day-granular take on SM-2. A forgotten card comes back today and
/// starts again; a remembered one waits longer each time, by its ease.
Schedule nextSchedule(Flashcard c, Grade g, String today) {
  var ease = c.ease, reps = c.reps, lapses = c.lapses;
  final int interval;
  switch (g) {
    case Grade.again:
      ease -= 0.2;
      reps = 0;
      lapses++;
      interval = 0;
    case Grade.hard:
      ease -= 0.15;
      interval = c.reps == 0 ? 1 : math.max(c.interval + 1, (c.interval * 1.2).round());
      reps++;
    case Grade.good:
      interval = _grown(c);
      reps++;
    case Grade.easy:
      ease += 0.15;
      interval = math.max(_grown(c) + 1, (_grown(c) * 1.3).round());
      reps++;
  }
  ease = ease.clamp(1.3, 3.0);
  return (interval: interval, ease: ease, reps: reps, lapses: lapses, due: addDays(today, interval));
}

int _grown(Flashcard c) => switch (c.reps) {
  0 => 1,
  1 => 3,
  _ => math.max(c.interval + 1, (c.interval * c.ease).round()),
};

/// Cards with an interval this long are "mature": held in long-term memory.
const matureDays = 21;
