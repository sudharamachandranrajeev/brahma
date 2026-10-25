import 'dart:convert';

import 'ai.dart';
import 'countries.dart';
import 'humanizer.dart';
import 'json.dart';
import 'profile.dart';
import 'schema.dart';

/// One input of a LinkedIn tool.
class ToolField {
  const ToolField(this.key, this.label, {this.lines = 1, this.helper, this.optional = false});
  final String key, label;
  final int lines;
  final String? helper;
  final bool optional;
}

/// The LinkedIn studio's tools. Each drafts text for the user to post or
/// send by hand; none of them touches LinkedIn. [humanCheck] runs on the
/// device; the rest ask the AI.
enum LinkedInTool {
  profile('Profile score', 'Score your profile out of 100 for recruiters and rewrite what loses points.', [
    ToolField(
      'profile',
      'Your LinkedIn profile',
      lines: 10,
      helper:
          'Paste your headline, About, recent experience and skills. Say whether you have a photo, a banner, '
          'Featured items, Open to Work and recommendations, and when you last posted.',
    ),
  ]),
  post('Post writer', 'Three hooks and a full post from something that happened, in your voice.', [
    ToolField(
      'idea',
      'What happened',
      lines: 4,
      helper: 'One true thing: what you did or saw, who was involved, and what it cost or returned. Numbers help.',
    ),
    ToolField(
      'angle',
      'Angle or hook (optional)',
      optional: true,
      helper: 'For example "the mistake" or "#5".',
    ),
  ]),
  comment('Comment writer', 'Comments on other people\'s posts that add something, two options each.', [
    ToolField(
      'posts',
      'The post (or several, separated by ---)',
      lines: 8,
      helper: 'Paste the text and, if you know it, the author\'s name and role.',
    ),
    ToolField('view', 'What you think (optional)', lines: 2, optional: true),
  ]),
  outreach('Connection note', 'The 200-character invite, the first message and two follow-ups.', [
    ToolField('who', 'Who', helper: 'Name, role and company.'),
    ToolField(
      'why',
      'Why them, why now',
      lines: 2,
      helper: 'A post they wrote, a role they are hiring for, a talk, someone you both know.',
    ),
    ToolField(
      'want',
      'What you hope for',
      lines: 2,
      helper: 'A referral, advice on a move, a conversation about a role.',
    ),
  ]),
  inbox(
    'Inbox triage',
    'Sort messages into recruiters, employers, network, asks and spam, and draft the replies.',
    [ToolField('messages', 'Messages', lines: 12, helper: 'Paste the messages and invitations, with names.')],
  ),
  replies(
    'Replies to comments',
    'Answers to the comments under your own post, sorted by which deserve one.',
    [
      ToolField('post', 'Your post (optional)', lines: 4, optional: true),
      ToolField(
        'comments',
        'The comments',
        lines: 10,
        helper: 'Paste them with names and roles where shown.',
      ),
    ],
  ),
  plan('Week plan', 'What to post this week, when, and whose posts to comment on.', [
    ToolField(
      'week',
      'What happened this week',
      lines: 4,
      helper: 'Applications, interviews, a course, something you built or learned, a conversation.',
    ),
    ToolField(
      'people',
      'People and companies to be seen by (optional)',
      lines: 3,
      optional: true,
      helper: 'Hiring managers, recruiters, employers you want to work for.',
    ),
  ]),
  audit('Post audit', 'What your past posts say about what works for you, and what to stop.', [
    ToolField(
      'analytics',
      'Your post numbers',
      lines: 10,
      helper:
          'Paste each post\'s first line with impressions, reactions, comments and reposts (Analytics > Content, '
          'or the export).',
    ),
    ToolField('followers', 'Followers (optional)', optional: true),
  ]),
  carousel('Carousel', 'A document post: slide copy, the caption, and a PDF to upload.', [
    ToolField(
      'idea',
      'The idea',
      lines: 4,
      helper: 'Something with steps or parts: a process, a framework, a before and after.',
    ),
  ]),
  repurpose('Repurpose', 'Turn a long piece (talk, article, transcript, thesis) into a week of posts.', [
    ToolField('source', 'The long piece', lines: 12, helper: 'Paste the text or transcript.'),
  ]),
  humanCheck('Human check', 'Clean a draft of machine marks and score it on five checks, on this device.', [
    ToolField('text', 'Draft', lines: 10),
  ]);

  const LinkedInTool(this.title, this.blurb, this.fields);
  final String title, blurb;
  final List<ToolField> fields;

  /// The report kind its results are saved as.
  String get kind => 'linkedin.$name';

  static LinkedInTool? ofKind(String kind) => values.where((t) => t.kind == kind).firstOrNull;
}

/// LinkedIn's limits, in characters.
abstract final class LinkedInLimits {
  static const invite = 200;
  static const post = 3000;
  static const comment = 1250;
  static const headline = 220;
  static const about = 2600;
}

/// Ways to open a post. Line one is all most readers see before "see more".
const hooks = <({int id, String name, String pattern, String example, String use, String pitfall})>[
  (
    id: 1,
    name: 'The cost',
    pattern: 'It took me {time or money} to learn {lesson}.',
    example: 'It took me 14 rejections to learn that my CV opened with the wrong job.',
    use: 'A lesson you paid for.',
    pitfall: 'A lesson everyone already knows.',
  ),
  (
    id: 2,
    name: 'The numbers',
    pattern: '{N} applications. {M} interviews. {K} offer. What changed between them.',
    example: '60 applications. 3 interviews. 1 offer. Only the last 10 had a tailored first line.',
    use: 'A job search or project with real counts.',
    pitfall: 'Rounded or invented numbers.',
  ),
  (
    id: 3,
    name: 'Before and after',
    pattern: '{Time} ago I {before}. Today I {after}.',
    example: 'Two years ago I filed incident reports. Today I design the system that files them.',
    use: 'A career move or a skill you built.',
    pitfall: 'A before that is only there to make the after look good.',
  ),
  (
    id: 4,
    name: 'Against the advice',
    pattern: '{Common advice} did not work for me. {What did}.',
    example: '"Apply to everything" did not work for me. Applying to six roles a week did.',
    use: 'A view that some people will disagree with.',
    pitfall: 'Arguing against advice nobody gives.',
  ),
  (
    id: 5,
    name: 'The mistake',
    pattern: 'My worst {work decision} so far: {decision}.',
    example: 'My worst interview so far: I answered a question about failure with a success.',
    use: 'Something you got wrong and fixed.',
    pitfall: 'A humblebrag dressed as a mistake.',
  ),
  (
    id: 6,
    name: 'The quote',
    pattern: '"{What someone said}"',
    example: '"We loved you, but the other candidate had shipped it before."',
    use: 'A moment with a person in it.',
    pitfall: 'A quote with no scene after it.',
  ),
  (
    id: 7,
    name: 'The real job',
    pattern: 'What {your job} looks like on an ordinary {day}.',
    example: 'What a clinical informatics nurse does on a Tuesday, hour by hour.',
    use: 'Showing what you do to people who hire for it.',
    pitfall: 'A day that is all highlights.',
  ),
  (
    id: 8,
    name: 'How I did it',
    pattern: 'How I {result} in {time} without {the usual thing}.',
    example: 'How I passed the AWS exam in 5 weeks without a bootcamp.',
    use: 'A method someone else can copy.',
    pitfall: 'Leaving out the part that was hard.',
  ),
  (
    id: 9,
    name: 'The question',
    pattern: 'People keep asking me {question}. My honest answer:',
    example: 'People keep asking how I moved from retail to UX. My honest answer: slowly.',
    use: 'A question you really get.',
    pitfall: 'A question nobody asked.',
  ),
  (
    id: 10,
    name: 'Myth and reality',
    pattern: 'Myth: {belief}. After {experience}: {what is true}.',
    example: 'Myth: recruiters read cover letters. After 40 calls with them: two of them do.',
    use: 'Correcting a belief in your field.',
    pitfall: 'A reality you cannot back up.',
  ),
  (
    id: 11,
    name: 'Wish I had known',
    pattern: '{N} things I wish I had known before {milestone}.',
    example: '4 things I wish I had known before my first panel interview.',
    use: 'Advice for people one step behind you.',
    pitfall: 'More than five items, or items without a story.',
  ),
  (
    id: 12,
    name: 'Small win',
    pattern: 'Small win this week: {specific thing}.',
    example: 'Small win this week: my first pull request to an open-source project was merged.',
    use: 'Progress on a goal, especially while job hunting.',
    pitfall: 'A win with no detail.',
  ),
  (
    id: 13,
    name: 'Learning in public',
    pattern: 'Week {n} of {learning goal}: {what you learned}.',
    example: 'Week 3 of learning SQL: window functions finally made sense.',
    use: 'A course, certificate or skill in progress.',
    pitfall: 'Listing topics instead of one thing that clicked.',
  ),
  (
    id: 14,
    name: 'Credit someone',
    pattern: '{Person or role} taught me {lesson} without meaning to.',
    example: 'A night-shift porter taught me more about patient flow than any course.',
    use: 'A lesson from a colleague; also good for being seen as generous.',
    pitfall: 'Tagging people for reach.',
  ),
  (
    id: 15,
    name: 'Open to work',
    pattern: 'I am looking for {role} in {place}. What I bring, in three lines:',
    example: 'I am looking for a data analyst role in Belfast or remote. What I bring, in three lines:',
    use: 'Telling your network what you want, plainly.',
    pitfall: 'Apologising for looking, or listing duties.',
  ),
  (
    id: 16,
    name: 'What is changing',
    pattern: '{Change in your field} is changing {part of the work}. What I am seeing:',
    example: 'AI scribes are changing how GP notes get written. What I am seeing on placement:',
    use: 'Showing you understand where your field is going.',
    pitfall: 'Repeating the headlines without your own view.',
  ),
  (
    id: 17,
    name: 'Tried both',
    pattern: '{Option A} or {option B}? I tried both for {time}.',
    example: 'Recruiter or applying direct? I tried both for three months.',
    use: 'A comparison you lived through.',
    pitfall: 'A tie with no verdict.',
  ),
  (
    id: 18,
    name: 'The turning point',
    pattern: 'The {message or moment} that changed my career had {N} words.',
    example: 'The email that got me my first analyst job had 41 words.',
    use: 'A short story with a clear before and after.',
    pitfall: 'A turning point that only looks like one in hindsight.',
  ),
];

/// What a recruiter-ready profile has, out of 100.
const profileRubric = <({String id, int points, String full})>[
  (
    id: 'Headline',
    points: 14,
    full:
        'Names the role you want and your specialism, with one piece of proof and the words recruiters search '
        'for. More than the current job title.',
  ),
  (
    id: 'Photo and banner',
    points: 8,
    full: 'A clear, recent photo and a banner that says what field you are in.',
  ),
  (
    id: 'About, first lines',
    points: 10,
    full:
        'The lines before "see more" say what you do, for whom, and the role you are after. No "passionate".',
  ),
  (
    id: 'About, the rest',
    points: 10,
    full: 'First person: the problems you solve, proof with numbers, what you are looking for, how to reach you.',
  ),
  (
    id: 'Experience',
    points: 14,
    full: 'Each recent role shows outcomes with numbers, not duties, and matches the CV.',
  ),
  (
    id: 'Skills',
    points: 8,
    full: 'Top skills match the target roles\' keywords, with the best three pinned.',
  ),
  (
    id: 'Open to Work',
    points: 6,
    full: 'Set (recruiters only or public) with the right titles, places, work modes and start date.',
  ),
  (
    id: 'Featured',
    points: 6,
    full: 'Two or three items that show your work: a project, a post, a portfolio.',
  ),
  (id: 'Recommendations', points: 6, full: 'Two or more recent ones from managers, clients or tutors.'),
  (id: 'Activity', points: 8, full: 'Posts or real comments on your field in the last 30 days.'),
  (
    id: 'Education and certificates',
    points: 6,
    full: 'Relevant qualifications and certificates with dates and awarding bodies.',
  ),
  (id: 'Custom URL and contact', points: 4, full: 'A clean custom URL and a way to contact you.'),
];

/// Kinds of comment, picked by what the post is.
const commentKinds = {
  'A data point': 'the post makes a claim you can support with a number of your own',
  'The missing case': 'the post is right but leaves out when it stops being true',
  'Respectful disagreement': 'you think it is wrong; agree with the true part first',
  'Build on one line': 'one sentence in it is the strong one; quote it and extend it',
  'The real question': 'the post skipped the hard part; ask one specific question',
  'Been there': 'you have done the thing; what happened, in two sentences',
  'A gentle correction': 'there is a factual error; be brief, kind and sure',
  'Another angle': 'right facts, a different way to read them',
  'Short and true': 'the post needs nothing added; under 12 words, true or funny',
};

/// Inbox buckets for someone looking for work.
const inboxBuckets = {
  'RECRUITER': 'offers a role or wants to talk about roles',
  'EMPLOYER': 'a hiring manager, a referral or someone at a company you want',
  'NETWORK': 'peers, alumni, people in your field with something to say',
  'ASK': 'wants your time, advice, an introduction or a favour',
  'SPAM': 'sales sequences, agencies selling to you, "quick question" with no question',
};

/// Buckets for comments under the user's own post.
const replyBuckets = {
  'OPPORTUNITY': 'a recruiter, a hiring manager or someone asking how to work with you',
  'SUBSTANCE': 'adds data, disagrees or extends the post',
  'PEER': 'someone in your field worth being seen next to',
  'CHEER': '"great post", an emoji, a tag',
  'NOISE': 'pitches, spam, bad faith',
};

/// Post types for a balanced week.
const postTypes = {
  'Proof': 'something you did, with a number',
  'Opinion': 'a view on your field that someone could disagree with',
  'Teach': 'one thing the reader can use today',
  'Story': 'a scene with a person and a cost (every other week)',
  'Signal': 'what you are looking for and what you bring (every other week while searching)',
};

/// The answer every tool gives: sections of labelled blocks, some of them
/// text to paste into LinkedIn.
final deliverableSchema = object({
  'headline': string('One line: the verdict, or what this is.'),
  'score': integer('The score out of 100 where the tool scores something; otherwise -1.'),
  'scoreAfter': integer('The likely score once the rewrites are in; -1 when nothing is scored.'),
  'sections': array(
    object({
      'title': string(),
      'blocks': array(
        object({
          'label': string('Short label, e.g. "Hook 2: #5 The mistake", "Day 4 follow-up", "Headline: 3/14".'),
          'text': string('The content. When copy is true, exactly what the user pastes, with line breaks.'),
          'copy': boolean('True for text the user will paste into LinkedIn.'),
          'limit': integer('LinkedIn\'s character limit for this text, or 0.'),
          'note': string('One line on why, or when to send it; may be empty.'),
          'write': boolean('True when this is a post idea the user can turn into a full post.'),
        }),
      ),
    }),
  ),
  'next': string('The one next step for the user.'),
});

/// The carousel's answer: the deliverable plus the slides.
final carouselSchema = {
  ...deliverableSchema,
  'properties': {
    ...obj(deliverableSchema['properties']),
    'slides': array(
      object({
        'title': string('3 to 7 words; on the cover, 6 words at most.'),
        'body': string('At most 25 words; may be empty on the cover.'),
      }),
      description: '8 to 12 slides: cover, why it matters, one idea each, a recap, one call to action.',
    ),
  },
  'required': [...(deliverableSchema['required'] as List), 'slides'],
};

/// Udyoga's LinkedIn coach: the instructions and schema for each tool.
/// Everything it writes is for the user to post or send by hand.
class LinkedInCoach {
  LinkedInCoach(this.ai, {required this.today});
  final Ai ai;
  final String today;

  String _system(CandidateProfile p) {
    final home = p.country.isEmpty ? 'the candidate\'s country' : Country.nameOf(p.country);
    return '''
You are Udyoga's LinkedIn coach for someone building their career and looking for work in $home. Today is $today.

Rules:
- Write in the candidate's own voice, from <voice> when given; otherwise plain, direct and warm. A draft in the wrong voice is worse than none.
- Never invent experience, employers, numbers, results, people or quotes. Where a number would help and is not given, write {{your number}} and say so in the note.
- Plain words. No em dashes, no curly quotes, no emoji at the start of lines, no hashtag walls (three at most, at the end), no "Thoughts?" endings, no "passionate", "results-driven" or "leverage".
- No links in a post's body: LinkedIn shows those posts to fewer people. Say to put the link in the first comment.
- Everything is for the candidate to post or send by hand. Never suggest automation, scraping, bulk invitations, engagement pods or tools that act on their account; those break LinkedIn's User Agreement and get accounts restricted.
- Keep LinkedIn's limits: connection note ${LinkedInLimits.invite} characters, post ${LinkedInLimits.post}, comment ${LinkedInLimits.comment}, headline ${LinkedInLimits.headline}, About ${LinkedInLimits.about}.
- Use the spelling of the candidate's country. Be candid: a generous score or a padded draft helps nobody.
- Answer in the schema. Put text to paste in blocks with copy true and its LinkedIn limit.''';
  }

  Json _text(String t) => {'type': 'text', 'text': t};

  /// Runs [tool] on [input] (its fields by key). [voice] is how the user
  /// writes; [history] their saved posts, newest first. The answer's paste
  /// text comes back cleaned by the humanizer.
  Future<AiResult> run(
    LinkedInTool tool,
    Map<String, String> input,
    CandidateProfile p, {
    String voice = '',
    List<Json> history = const [],
    void Function(String status)? onProgress,
  }) async {
    assert(tool != LinkedInTool.humanCheck, 'The human check runs on the device');
    final r = await ai.ask(
      system: _system(p),
      content: [
        _text('<candidate>\n${jsonEncode(p.forPrompt())}\n</candidate>'),
        if (voice.trim().isNotEmpty) _text('<voice>\n${voice.trim()}\n</voice>'),
        if (history.isNotEmpty && const {LinkedInTool.plan, LinkedInTool.audit}.contains(tool))
          _text('<past_posts>\n${jsonEncode(history)}\n</past_posts>'),
        _text(
          '<input>\n${jsonEncode({for (final f in tool.fields) f.key: input[f.key]?.trim() ?? ''})}\n</input>',
        ),
        _text(_task(tool)),
      ],
      schema: tool == LinkedInTool.carousel ? carouselSchema : deliverableSchema,
      web: tool == LinkedInTool.plan,
      searches: 4,
      effort: const {LinkedInTool.profile, LinkedInTool.audit, LinkedInTool.plan}.contains(tool)
          ? 'high'
          : 'medium',
      onProgress: onProgress,
    );
    return AiResult(cleanDeliverable(r.data), sources: r.sources, usage: r.usage);
  }

  static final _hookList = jsonEncode([
    for (final h in hooks)
      {'id': h.id, 'name': h.name, 'pattern': h.pattern, 'use': h.use, 'pitfall': h.pitfall},
  ]);

  String _task(LinkedInTool tool) => switch (tool) {
    LinkedInTool.profile =>
      '''
Score the profile in <input> against this rubric for the roles the candidate targets, honestly (most first attempts land between 30 and 50):
${jsonEncode([
        for (final r in profileRubric) {'item': r.id, 'points': r.points, 'full_marks': r.full},
      ])}
Sections: "Score" with one block per item (label "Item: got/points", text = why, copy false); then "Rewrites" in order of points lost: three headline options (limit ${LinkedInLimits.headline}), the About opening lines and the full About (limit ${LinkedInLimits.about}), experience bullets as outcomes, the skills to pin, and what to set in Open to Work. Each rewrite uses only facts from the profile and CV. Set score and scoreAfter; say in "next" what a rewrite cannot fix (recommendations, a banner, recent activity).''',
    LinkedInTool.post =>
      '''
Write a LinkedIn post from <input>. If the idea is too thin for one specific true post, say so in the headline and ask in "next" for the missing detail instead of padding.
Hooks: $_hookList
Section "Hooks": the three formulas that fit best (different ones), each as one block labelled "#id Name" with the opening line, copy false, and a note; say which you would use. Section "Post": the full post on the best hook (copy true, limit ${LinkedInLimits.post}, 900 to 1,300 characters): the hook alone on line 1, line 2 pays it off, short paragraphs with blank lines, one line that reframes, then one specific question or one instruction. One idea only. Label the post with the hook used, e.g. "Post: #5 The mistake". Put the best day and time to post in its note.''',
    LinkedInTool.comment =>
      '''
Write comments on the post or posts in <input> (separated by ---). Kinds: ${jsonEncode(commentKinds)}
One section per post titled with the author and topic. Two blocks of different kinds (label "Kind: name"), each 2 to 4 sentences unless it is "Short and true", copy true, limit ${LinkedInLimits.comment}. Never open with praise ("Great post", "Love this") or restate the post; one idea each; specific enough that it could only sit under this post. Use the candidate's real experience where it fits. Note which one to post and why.''',
    LinkedInTool.outreach =>
      '''
Write LinkedIn outreach to the person in <input>. If there is no specific reason to contact them now, say so in the headline and suggest how to find one in "next".
Section "Messages": the connection note (copy true, limit ${LinkedInLimits.invite}: one specific reference to them, one line on who the candidate is, no ask); the first message to send a day after they accept (2 to 4 sentences, gives something first, one small ask, no calendar link); a follow-up for 4 days later that adds something new; and a last one for 10 days later that closes the loop politely. Label each with when to send it. Never claim a shared connection, school or reading that <input> does not state.''',
    LinkedInTool.inbox =>
      '''
Sort every message in <input> into these buckets: ${jsonEncode(inboxBuckets)}
Headline: the counts per bucket. One section per bucket that has messages (most important first). For RECRUITER, EMPLOYER, NETWORK and worthwhile ASK messages: a block per message with the sender as label, a short reply (copy true), and a note. A recruiter reply asks what the message left out (pay band, level, location or hybrid, contract type) if the role could fit, or declines in one line and offers to refer. Declines are short, warm and final. For SPAM: one block listing them with the tell that gave each away (copy false). No reply is drafted for spam.''',
    LinkedInTool.replies =>
      '''
Sort the comments in <input> on the candidate's own post into: ${jsonEncode(replyBuckets)}
Headline: the counts. Sections in that order; each comment a block labelled with the commenter, the reply (copy true, limit ${LinkedInLimits.comment}) matching their length, using their name once without an exclamation mark. Answer questions in the reply itself rather than moving them to messages. For a critic, concede the true part first, then hold the line once. For an opportunity, answer fully and end with one line offering to talk. CHEER gets at most a few words; NOISE gets no reply (copy false, note "skip").''',
    LinkedInTool.plan =>
      '''
Plan the candidate's LinkedIn week from <input>, their profile and <past_posts> (do not repeat a theme from the last two weeks). Four posts beat seven. Types: ${jsonEncode(postTypes)}; never two of one type in a row.
Research briefly what is current in their field this week if it helps an angle. Section "Posts": one block per day Monday to Sunday labelled like "Tue 08:15 Proof" (engage-only days say so). Each post block's text is the specific angle drawn from what happened this week, with the number and name of the hook that fits from: $_hookList; write true, copy false. Times suit the people they want to reach, in their timezone: weekday mornings at a desk are the default; say plainly that the first line matters far more than the hour. Section "Engage": ten people or kinds of people from <input> and their targets (five with the audience they want, three peers, two who hire), 20 minutes a day before posting, commenting early.''',
    LinkedInTool.audit =>
      '''
Audit the candidate's posts from the numbers in <input> and <past_posts>. Compute for each post engagement rate ((reactions + comments + reposts) / impressions), comment ratio (comments / reactions) and, with a follower count, reach multiple (impressions / followers). Rank by engagement rate and reach multiple, not impressions; show the working.
Sections: "Top" and "Bottom" (up to five each, label = rate and first words of the post); "What the numbers say": each finding as a claim with its evidence and how sure you are, comparing hook, format, length and theme, and time of day last. With fewer than ten posts say a pattern cannot be trusted yet. End with one block "Stop" and one "Do more". score = the share of posts above 2% engagement as a percentage, or -1 without impressions.''',
    LinkedInTool.carousel =>
      '''
Make a LinkedIn document post (carousel) from <input>. If the idea is one claim rather than steps or parts, say so in the headline and suggest a text post in "next".
slides: 8 to 12: the cover (6 words at most plus a one-line promise in body), why it matters, one idea per slide (title of 3 to 7 words, at most 25 words under it), a recap the reader would screenshot, and one call to action. Do not number them; the PDF does. Sections: "Slides" (one block per slide, copy false) and "Caption": the 2 to 3 lines that go above the PDF (copy true, limit ${LinkedInLimits.post}).''',
    LinkedInTool.repurpose =>
      '''
Turn the long piece in <input> into LinkedIn posts. Do not summarise: pull out what stands alone: claims someone could argue with, numbers, stories with a person and a cost, explanations of how something works, mistakes, lines already quotable.
Headline: counts of each. If fewer than four stand-alone items, say it is thin. Section "Found": the items (copy false). Section "This week": four to six posts, strongest claim first, the story midweek, how-it-works last, each a block labelled with the day and hook ("Tue: #4 Against the advice"), text = the opening line and the angle, write true. Each must stand alone for a reader who never saw the source; vary the hooks, from: $_hookList''',
    LinkedInTool.humanCheck => throw StateError('The human check runs on the device'),
  };
}

/// [data] with every paste block cleaned by the humanizer.
Json cleanDeliverable(Json data) => {
  ...data,
  'sections': [
    for (final s in objs(data['sections']))
      {
        ...s,
        'blocks': [
          for (final b in objs(s['blocks']))
            b['copy'] == true ? {...b, 'text': humanize(str(b['text'])).text} : b,
        ],
      },
  ],
};

/// A saved post, as the plan and audit see it.
Json postHistory(Json content, String created) {
  final post = objs(content['sections'])
      .expand((s) => objs(s['blocks']))
      .where((b) => b['copy'] == true)
      .firstOrNull;
  final text = str(post?['text']);
  return {
    'date': created.substring(0, 10),
    'hook': str(post?['label']),
    'first_line': text.split('\n').first,
    'posted': str(content['posted']),
  };
}
