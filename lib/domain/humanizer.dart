import 'dart:math';

/// Cleans the marks machine-written text leaves behind and scores a draft
/// on five local checks. Everything runs on the device. The checks look at
/// the same kinds of signal public AI detectors use, but they are not those
/// detectors and cannot promise what any of them will say.
///
/// Three things are fixed automatically: invisible characters, typography a
/// keyboard does not type (em dashes, curly quotes, the ellipsis character)
/// and stock phrases with a plainer word. Sentence shapes that need
/// judgement ("not just X, it's Y", a wall of hashtags) are only flagged.
class HumanCheck {
  const HumanCheck({
    required this.text,
    required this.invisible,
    required this.typography,
    required this.replaced,
    required this.flags,
    required this.scores,
  });

  /// The cleaned text.
  final String text;

  /// How many invisible characters and typographic marks were fixed.
  final int invisible, typography;

  /// Stock phrases swapped, as "leverage → use".
  final List<String> replaced;

  /// Lines to rewrite by hand, each with why.
  final List<String> flags;

  /// The five checks, 0 to 100, higher reads more human.
  final Map<String, int> scores;

  int get fixes => invisible + typography + replaced.length;

  /// The mean weighted 60%, the weakest check 40%: one weak signal is enough
  /// for a detector.
  int get overall {
    if (scores.isEmpty) return 0;
    final mean = scores.values.reduce((a, b) => a + b) / scores.length;
    return (mean * 0.6 + scores.values.reduce(min) * 0.4).round();
  }

  bool get pass => overall >= 70 && scores.values.every((s) => s >= 55);
  String get verdict => pass ? 'Pass' : 'Review';
}

/// What each check measures, for the screen.
const humanChecks = {
  'Variety': 'Sentence lengths vary the way people write; machine text is even.',
  'Specifics': 'Numbers, names and concrete detail per 100 words.',
  'Plain words': 'Few stock phrases ("leverage", "seamless", "passionate").',
  'Typing marks': 'No invisible characters, em dashes or curly quotes.',
  'Voice': 'Contractions and first person, no staged reveals.',
};

/// Stock phrases and the plain words that replace them. Longer phrases come
/// first so they match before their parts.
const _plain = <String, String>{
  "in today's fast-paced world, ": '',
  "in today's fast-paced world": 'now',
  "it's worth noting that ": '',
  'it is worth noting that ': '',
  "it's important to note that ": '',
  'it is important to note that ': '',
  'at the end of the day': 'in the end',
  'navigate the complexities of': 'handle',
  'a testament to': 'proof of',
  'testament to': 'proof of',
  'in order to': 'to',
  'thrilled to announce': 'glad to say',
  'excited to share': 'sharing',
  'ever-evolving': 'changing',
  'ever-changing': 'changing',
  'cutting-edge': 'new',
  'game-changer': 'big change',
  'game changer': 'big change',
  'paradigm shift': 'big change',
  'deep dive': 'close look',
  'delve into': 'look at',
  'delves into': 'looks at',
  'delving into': 'looking at',
  'embark on': 'start',
  'embarked on': 'started',
  'utilize': 'use',
  'utilise': 'use',
  'utilized': 'used',
  'utilised': 'used',
  'utilizing': 'using',
  'utilising': 'using',
  'leverage': 'use',
  'leveraged': 'used',
  'leveraging': 'using',
  'harness': 'use',
  'harnessing': 'using',
  'robust': 'solid',
  'seamless': 'smooth',
  'seamlessly': 'smoothly',
  'holistic': 'whole',
  'myriad': 'many',
  'plethora': 'lots',
  'pivotal': 'key',
  'crucial': 'key',
  'furthermore': 'also',
  'moreover': 'also',
  'additionally': 'also',
  'nevertheless': 'still',
  'commence': 'start',
  'commenced': 'started',
  'endeavour': 'try',
  'endeavor': 'try',
  'facilitate': 'help',
  'facilitated': 'helped',
  'optimal': 'best',
  'empower': 'help',
  'empowered': 'helped',
  'elevate': 'raise',
  'streamline': 'simplify',
  'streamlined': 'simplified',
  'spearheaded': 'led',
  'spearhead': 'lead',
  'tapestry': 'mix',
  'realm': 'area',
  'synergy': 'teamwork',
  'synergies': 'gains',
  'unparalleled': 'rare',
  'meticulous': 'careful',
  'meticulously': 'carefully',
};

/// Words recruiters skim past; flagged, not replaced, since the fix is a
/// specific example rather than a synonym.
const _hollow = [
  'passionate',
  'results-driven',
  'detail-oriented',
  'hard-working',
  'go-getter',
  'team player',
  'thought leader',
  'rockstar',
  'ninja',
  'guru',
  'dynamic',
  'synergistic',
  'proven track record',
  'think outside the box',
];

final _url = RegExp(r'https?://\S+|www\.\S+|\S+@\S+\.\S+');
final _invisible = RegExp(
  '[\u00AD\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]|[\u{E0000}-\u{E007F}]',
  unicode: true,
);
final _oddSpace = RegExp('[\u00A0\u2002-\u200A\u202F\u205F\u3000]');
final _sentences = RegExp(r'[^.!?\n]+[.!?]*');
final _words = RegExp(r"[A-Za-z][A-Za-z'\u2019-]*");

/// Cleans [draft] and scores the result.
HumanCheck humanize(String draft) {
  // Links are set aside so nothing inside one is rewritten.
  final links = <String>[];
  var t = draft.replaceAllMapped(_url, (m) {
    links.add(m[0]!);
    return '\u0000${links.length - 1}\u0000';
  });

  var invisible = 0;
  t = t.replaceAllMapped(_invisible, (_) {
    invisible++;
    return '';
  });
  t = t.replaceAllMapped(_oddSpace, (_) {
    invisible++;
    return ' ';
  });
  t = t.replaceAll('\u2028', '\n').replaceAll('\u2029', '\n\n');

  var typography = 0;
  String swap(String s, Pattern from, String to) => s.replaceAllMapped(from, (_) {
    typography++;
    return to;
  });
  t = swap(t, RegExp(r'^[ \t]*[\u2014\u2013][ \t]*', multiLine: true), '- ');
  t = swap(t, RegExp(r'[ \t]*\u2014[ \t]*'), ', ');
  t = swap(t, RegExp('[\u2013\u2010\u2011\u2212]'), '-');
  t = swap(t, RegExp('[\u2018\u2019\u201B\u2032]'), "'");
  t = swap(t, RegExp('[\u201C\u201D\u201F\u2033]'), '"');
  t = swap(t, '\u2026', '...');
  t = swap(t, RegExp(r'^[ \t]*[\u2022\u25AA\u25CF\u2023][ \t]*', multiLine: true), '- ');
  // What an em dash leaves behind: ", ." and ", ," and ", " at a line end.
  t = t
      .replaceAll(RegExp(r',\s*([.,;:!?])'), r'$1')
      .replaceAll(RegExp(r',[ \t]*$', multiLine: true), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ');

  final replaced = <String>[];
  for (final e in _plain.entries) {
    t = t.replaceAllMapped(RegExp('\\b${RegExp.escape(e.key)}', caseSensitive: false), (m) {
      final found = m[0]!;
      final to = _keepCase(found, e.value);
      replaced.add('${found.trim()} \u2192 ${to.isEmpty ? '(removed)' : to}');
      return to;
    });
  }
  // A phrase removed at the start of a sentence leaves a small letter.
  t = t.replaceAllMapped(
    RegExp(r'(^|[.!?]\s+)([a-z])', multiLine: true),
    (m) => '${m[1]}${m[2]!.toUpperCase()}',
  );

  t = t.replaceAllMapped(RegExp('\u0000(\\d+)\u0000'), (m) => links[int.parse(m[1]!)]);
  return HumanCheck(
    text: t,
    invisible: invisible,
    typography: typography,
    replaced: replaced,
    flags: _flags(t),
    scores: humanScores(t),
  );
}

String _keepCase(String found, String to) {
  if (to.isEmpty || found.isEmpty) return to;
  return found[0] == found[0].toUpperCase() && found[0] != found[0].toLowerCase()
      ? '${to[0].toUpperCase()}${to.substring(1)}'
      : to;
}

/// Sentence shapes that need a person to rewrite them, with why.
final _tells = <(RegExp, String)>[
  (
    RegExp(
      r"\b(not just|not only|isn't just|it's not about)\b[^.!?\n]{1,80}?\b(it's|but|it is)\b",
      caseSensitive: false,
    ),
    'the "not X, but Y" reveal reads as machine-made. Say the point directly.',
  ),
  (
    RegExp(
      r'^\s*(the (result|catch|twist|lesson|kicker|truth|problem|answer|secret)|why|how|what happened)\?\s*$',
      caseSensitive: false,
      multiLine: true,
    ),
    'a one-line question set up for a reveal. Fold it into the sentence after.',
  ),
  (
    RegExp(
      r'^.*\b(let that sink in|read that again|here.s the thing|plot twist)\b.*$',
      caseSensitive: false,
      multiLine: true,
    ),
    'a stock line. Cut it.',
  ),
  (
    RegExp(r'(thoughts|agree|who else|can you relate|what do you think)\?\s*$', caseSensitive: false),
    'a closing question any post could end with. Ask one only this post could ask, or none.',
  ),
];

List<String> _flags(String t) {
  final flags = [
    for (final (re, why) in _tells)
      for (final m in re.allMatches(t)) '"${_clip(m[0]!.trim())}": $why',
  ];
  for (final w in _hollow) {
    if (RegExp('\\b${RegExp.escape(w)}\\b', caseSensitive: false).hasMatch(t)) {
      flags.add('"$w": says nothing a reader can check. Replace it with what you did.');
    }
  }
  final emoji = RegExp(
    '[\u{1F680}\u{1F525}\u{1F4A1}\u{2728}\u{1F3AF}\u{1F447}\u{1F64C}\u{1F4AF}\u{1F44F}]',
    unicode: true,
  );
  final e = emoji.allMatches(t).length;
  if (e > 0) flags.add('$e stock emoji (rocket, fire, bulb, sparkles...). Remove them.');
  final tags = RegExp(r'(^|\s)#\w+').allMatches(t).length;
  if (tags > 3) flags.add('$tags hashtags. Keep three at most, at the end.');
  final triads = RegExp(r'\b\w{3,12}, \w{3,12},? and \w{3,12}\b').allMatches(t).length;
  if (triads >= 2) flags.add('$triads lists of exactly three. Vary them: two items, or four.');
  return flags;
}

String _clip(String s) => s.length > 60 ? '${s.substring(0, 57)}...' : s;

/// The five checks for [t].
Map<String, int> humanScores(String t) {
  final words = _words.allMatches(t).map((m) => m[0]!).toList();
  final n = max(words.length, 1);
  final per100 = 100 / n;

  final lengths = [
    for (final s in _sentences.allMatches(t))
      if (_words.allMatches(s[0]!).length case final w when w > 0) w,
  ];
  int variety;
  if (lengths.length < 3) {
    variety = 70;
  } else {
    final mean = lengths.reduce((a, b) => a + b) / lengths.length;
    final sd = sqrt(lengths.map((l) => pow(l - mean, 2)).reduce((a, b) => a + b) / lengths.length);
    variety = _clamp(20 + (sd / mean) / 0.6 * 80);
  }

  final numbers = RegExp(r'\d[\d,.]*%?').allMatches(t).length;
  final names = RegExp(r'(?<=[a-z,;:] )[A-Z][a-z]+').allMatches(t).length;
  final specifics = _clamp(30 + (numbers + names) * per100 * 14);

  final lower = t.toLowerCase();
  var stock = 0;
  for (final p in [..._plain.keys, ..._hollow]) {
    stock += RegExp('\\b${RegExp.escape(p.trim())}\\b').allMatches(lower).length;
  }
  final plainWords = _clamp(100 - stock * per100 * 25);

  final marks =
      _invisible.allMatches(t).length +
      RegExp('[\u2014\u2013\u2018\u2019\u201C\u201D\u2026]').allMatches(t).length;
  final typing = _clamp(100 - marks * 1000 / max(t.length, 1) * 15);

  final contractions = RegExp(r"\b\w+'(s|t|re|ve|ll|d|m)\b", caseSensitive: false).allMatches(t).length;
  final firstPerson = RegExp(r'\b(I|my|me|we|our)\b').hasMatch(t);
  final staged = _tells.fold(0, (n, tell) => n + tell.$1.allMatches(t).length);
  final voice = _clamp(40 + min(contractions * per100, 2) * 30 + (firstPerson ? 10 : 0) - staged * 15);

  return {
    'Variety': variety,
    'Specifics': specifics,
    'Plain words': plainWords,
    'Typing marks': typing,
    'Voice': voice,
  };
}

int _clamp(num v) => v.clamp(0, 100).round();
