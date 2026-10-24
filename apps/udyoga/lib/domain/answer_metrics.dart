/// Measures of a practice answer worked out on the device, alongside the
/// AI's review: length, speaking time, filler words, ownership ("I" against
/// "we"), numbers used and STAR coverage.
class AnswerMetrics {
  AnswerMetrics._(this.words, this.fillers, this.iCount, this.weCount, this.figures, this.star);

  factory AnswerMetrics.of(String answer) {
    final text = answer.toLowerCase();
    final words = RegExp(r"[a-z0-9'’]+").allMatches(text).map((m) => m[0]!).toList();
    var fillers = 0;
    for (final f in _fillers) {
      fillers += RegExp('\\b${RegExp.escape(f)}\\b').allMatches(text).length;
    }
    final star = <String>{
      for (final e in _starCues.entries)
        if (e.value.any(text.contains)) e.key,
    };
    return AnswerMetrics._(
      words.length,
      fillers,
      words.where((w) => w == 'i' || w == "i'm" || w == 'i’m' || w == 'my' || w == 'me').length,
      words.where((w) => w == 'we' || w == 'our' || w == 'us').length,
      RegExp(r'\d+([.,]\d+)?\s*(%|percent|k\b|m\b|£|\$|€|hours|days|weeks|people|staff|patients|cases)?')
          .allMatches(text)
          .length,
      star,
    );
  }

  final int words, fillers, iCount, weCount, figures;

  /// STAR parts the answer seems to cover: situation, task, action, result.
  final Set<String> star;

  /// At an interview pace of about 140 words a minute.
  Duration get speakingTime => Duration(seconds: (words / 140 * 60).round());

  /// Two minutes is about right for a competency answer.
  String get lengthVerdict => switch (words) {
    < 120 => 'Short: add the situation, your actions and the result',
    > 420 => 'Long: aim for about two minutes',
    _ => 'A good length',
  };

  /// Share of "I" among I and we; panels want to hear what you did.
  double get ownership => iCount + weCount == 0 ? 0 : iCount / (iCount + weCount);

  static const _fillers = [
    'um',
    'uh',
    'erm',
    'like',
    'basically',
    'actually',
    'you know',
    'kind of',
    'sort of',
    'i guess',
    'literally',
  ];

  static const _starCues = {
    'Situation': [
      'when i was',
      'at the time',
      'situation',
      'there was',
      'we had',
      'in my role',
      'while working',
    ],
    'Task': ['my task', 'i needed to', 'i had to', 'responsible for', 'my role was', 'the goal', 'asked to'],
    'Action': [
      'i decided',
      'i organised',
      'i organized',
      'i created',
      'i spoke',
      'i set up',
      'so i',
      'i then',
      'i made',
    ],
    'Result': [
      'as a result',
      'the result',
      'which meant',
      'reduced',
      'increased',
      'improved',
      'saved',
      'outcome',
    ],
  };
}
