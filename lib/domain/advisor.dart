import 'dart:convert';
import 'dart:typed_data';

import '../db/database.dart';
import 'answer_metrics.dart';
import 'ai.dart';
import 'countries.dart';
import 'insights.dart';
import 'json.dart';
import 'profile.dart';
import 'resume.dart';
import 'schema.dart';

typedef Progress = void Function(String status);

/// A CV to read: a PDF (the model reads the layout itself) or text.
sealed class CvSource {
  const CvSource();
}

class PdfCv extends CvSource {
  const PdfCv(this.bytes);
  final Uint8List bytes;
}

class TextCv extends CvSource {
  const TextCv(this.text);
  final String text;
}

/// Udyoga's career adviser: every AI task, its instructions and its schema.
/// The candidate's profile goes with each request; nothing else about the
/// user does.
class Advisor {
  Advisor(this.ai, {required this.today});
  final Ai ai;

  /// yyyy-MM-dd, so research is dated and deadlines are judged right.
  final String today;

  String _system(CandidateProfile p) {
    final home = p.country.isEmpty ? 'the candidate\'s country' : Country.nameOf(p.country);
    return '''
You are Udyoga's career adviser: a senior recruiter, hiring manager and careers coach who knows the job market in $home and abroad. Today is $today.

Principles:
- Be realistic and candid. Say plainly when something is a long shot and why; do not flatter. The candidate wants to be ready for the toughest version of every challenge.
- Never invent experience, qualifications, employers, dates, figures or achievements. Work only from the candidate's profile and CV. Where something would help but is not there, say what is missing instead of making it up.
- Facts that change (salaries, demand, pay bands, visa and right-to-work rules, certifications, how AI is changing the work) must be current: research them and prefer sources from the last 12 months. Give currencies and the year of any figure.
- Account for the growth of AI in the candidate's field in every judgement: what is being automated, what is growing in value, and what employers now expect.
- Use the spelling and terms of the candidate's country (for example "CV" and UK English in the UK and Ireland).
- Be specific and practical: name real employers, job sites, qualifications and awarding bodies, with official links where you have them.''';
  }

  Json _candidate(CandidateProfile p) => {
    'type': 'text',
    'text': '<candidate>\n${jsonEncode(p.forPrompt())}\n</candidate>',
  };

  Json _text(String t) => {'type': 'text', 'text': t};

  String _job(Job j) => jsonEncode({
    'title': j.title,
    'company': j.company,
    'location': j.location,
    'country': j.country,
    'salary': j.salaryText.isNotEmpty ? j.salaryText : _salary(j),
    'url': j.url,
    'posted': j.posted,
    'closing': j.closing,
    'advert': j.description,
  });

  String _salary(Job j) => [
    if (j.salaryMin != null) '${j.salaryMin}',
    if (j.salaryMax != null && j.salaryMax != j.salaryMin) '${j.salaryMax}',
  ].join('–').let((s) => s.isEmpty ? '' : '${j.currency} $s'.trim());

  /// Reads a CV into a profile.
  Future<CandidateProfile> readCv(CvSource cv) async {
    final content = switch (cv) {
      PdfCv(:final bytes) => <Json>[
        {
          'type': 'document',
          'source': {'type': 'base64', 'media_type': 'application/pdf', 'data': base64Encode(bytes)},
        },
        _text('This is the candidate\'s CV. Fill in the profile from it.'),
      ],
      TextCv(:final text) => [
        _text('<cv>\n$text\n</cv>\n\nThis is the candidate\'s CV. Fill in the profile from it.'),
      ],
    };
    final r = await ai.ask(
      system:
          'You read CVs and fill in a structured profile exactly as the CV states it. Today is $today. '
          'Copy facts faithfully; do not improve, guess or add anything. Leave unknown fields empty.',
      content: content,
      schema: CandidateProfile.schema,
      effort: 'medium',
    );
    return CandidateProfile.fromJson(r.data);
  }

  /// The deep assessment: market position, strengths and weaknesses, the
  /// toughest challenges, AI impact, target roles, countries and learning.
  Future<AiResult> assess(CandidateProfile p, {Progress? onProgress}) => ai.ask(
    system: _system(p),
    content: [
      _candidate(p),
      _text(
        '''
Assess this candidate thoroughly and research the current market for them.

Cover: where they stand today and how competitive they are; strengths with evidence from the CV; weaknesses and how to fix each; the toughest challenges to their next move and how to prepare; how AI is changing their field; the roles they should target now with current salary ranges and job-board search terms; their prospects in their current country and in realistic other countries ${p.searchCountries.isEmpty ? '' : '(they are considering ${p.searchCountries.map(Country.nameOf).join(', ')})'} including right to work; and the certifications, courses, degrees and experience that would most improve their prospects, with providers, costs and official links. End with quick wins for this week.''',
      ),
    ],
    schema: Assessment.schema,
    web: true,
    searches: 12,
    onProgress: onProgress,
  );

  /// Every realistic career path from the current role.
  Future<AiResult> careerMap(CandidateProfile p, {Assessment? assessment, Progress? onProgress}) => ai.ask(
    system: _system(p),
    content: [
      _candidate(p),
      if (assessment != null) _text('<assessment>\n${jsonEncode(assessment.j)}\n</assessment>'),
      _text(
        '''
Map every realistic career progression from the candidate's current role: up the same ladder, sideways into related roles, specialist routes, management, a change of field, and independent work where it fits. For each path give two to four steps with timeframes, current salary ranges, likelihood, what each step requires (experience, skills, certifications) and typical employers in their countries. Judge each path's exposure to AI and say which parts will grow or shrink. Be honest about which paths are ambitious. Recommend one path and say why. Research current pay scales, grade structures and hiring trends.''',
      ),
    ],
    schema: CareerMap.schema,
    web: true,
    searches: 10,
    onProgress: onProgress,
  );

  /// How well the candidate fits [job], with research on the employer.
  Future<AiResult> assessJob(CandidateProfile p, Job job, {Progress? onProgress}) => ai.ask(
    system: _system(p),
    content: [
      _candidate(p),
      _text('<job>\n${_job(job)}\n</job>'),
      _text(
        '''
Evaluate this job for the candidate as a demanding hiring manager would. If the advert text is short, read the advert at its URL. Research the employer (what it is like to work there, recent news, pay against the market). Score the fit honestly against the essential and desirable criteria, list each requirement they meet with evidence from the CV and each gap with its severity and how to close or address it, and give realistic odds of an interview and an offer. Pick out the keywords the application must contain and what the interview will probe.''',
      ),
    ],
    schema: FitAssessment.schema,
    web: true,
    searches: 6,
    onProgress: onProgress,
  );

  /// A CV (and cover letter) for [job], from the profile.
  Future<AiResult> tailor(CandidateProfile p, Job job, {FitAssessment? fit, Progress? onProgress}) => ai.ask(
    system: _system(p),
    content: [
      _candidate(p),
      _text('<base_cv>\n${jsonEncode(ResumeDoc.fromProfile(p).toJson())}\n</base_cv>'),
      _text('<job>\n${_job(job)}\n</job>'),
      if (fit != null) _text('<fit_assessment>\n${jsonEncode(fit.j)}\n</fit_assessment>'),
      _text(
        '''
Tailor the CV to this job. Follow the job description, key responsibilities, essential and desirable criteria and the employer's values:
- Rewrite the profile for this role. Order skills and bullets so the most relevant come first; lead bullets with actions and results, using real figures from the CV only.
- Use the advert's wording where it truthfully describes the candidate's experience, so applicant tracking systems match it. Do not add a skill, duty, qualification or result the candidate does not have; list such keywords as missing instead.
- Keep it to about two pages: cut or shorten what does not serve this job.
- Keep the candidate's real job titles, employers and dates.
Then write the cover letter (or supporting statement, if the advert asks for one against criteria), and the notes.''',
      ),
    ],
    schema: tailorSchema,
    effort: 'high',
    onProgress: onProgress,
  );

  /// Quick fit scores for many jobs at once, from their adverts.
  Future<Map<String, ({int fit, String why})>> triage(CandidateProfile p, List<Job> jobs) async {
    if (jobs.isEmpty) return const {};
    final list = [
      for (final j in jobs)
        {
          'id': j.id,
          'title': j.title,
          'company': j.company,
          'location': j.location,
          'salary': j.salaryText.isNotEmpty ? j.salaryText : _salary(j),
          'advert': j.description.length > 700 ? '${j.description.substring(0, 700)}…' : j.description,
        },
    ];
    final r = await ai.ask(
      system: _system(p),
      content: [
        _candidate(p),
        _text('<jobs>\n${jsonEncode(list)}\n</jobs>'),
        _text(
          'Score each job 0 to 100 for this candidate (70+ only if they meet nearly all essentials), '
          'with one line on why. Be strict about level, location, right to work and pay.',
        ),
      ],
      schema: object({
        'scores': array(object({'id': string(), 'fit': integer(), 'why': string()})),
      }),
      effort: 'low',
      maxTokens: 16000,
    );
    return {
      for (final s in objs(r.data['scores']))
        str(s['id']): (fit: (intOf(s['fit']) ?? 0).clamp(0, 100), why: str(s['why'])),
    };
  }

  /// Searches the web for current openings across the candidate's countries
  /// and job sites (LinkedIn, Indeed, national and public-sector boards).
  Future<AiResult> findJobs(
    CandidateProfile p, {
    required List<String> countries,
    List<String> known = const [],
    Progress? onProgress,
  }) => ai.ask(
    system: _system(p),
    content: [
      _candidate(p),
      _text('''
Find current job openings this candidate could realistically apply for now, in ${countries.map(Country.nameOf).join(', ')}${p.targets.remote ? ', and remote roles open to them' : ''}. Search the main job sites for each country (LinkedIn, Indeed and the national, public-sector and specialist boards), employers' own career pages and recruiters. Include roles one step up where they are competitive, not only like-for-like.
Only include adverts that are open today ($today) and link to the advert itself. Skip any already known:
${known.isEmpty ? '(none)' : known.take(200).join('\n')}
Return up to 20, best fit first.'''),
    ],
    schema: FoundJob.schema,
    web: true,
    searches: 15,
    effort: 'medium',
    onProgress: onProgress,
  );

  /// Reads an advert from its page or pasted text into job fields.
  Future<Json> readAdvert({String url = '', String text = '', Progress? onProgress}) async {
    final r = await ai.ask(
      system: 'You extract job adverts into fields exactly as written. Today is $today.',
      content: [
        _text(
          url.isNotEmpty && text.isEmpty
              ? 'Read the job advert at $url and fill in its fields. Put the full role description, key '
                    'responsibilities and person specification in the description.'
              : '<advert url="$url">\n$text\n</advert>\n\nFill in this advert\'s fields. Put the full role '
                    'description, key responsibilities and person specification in the description.',
        ),
      ],
      schema: object({
        'title': string(),
        'company': string(),
        'location': string(),
        'country': string('ISO alpha-2'),
        'remote': boolean(),
        'salaryText': string(),
        'posted': string("yyyy-MM-dd or ''"),
        'closing': string("yyyy-MM-dd or ''"),
        'description': string(),
      }),
      web: url.isNotEmpty && text.isEmpty,
      searches: 3,
      effort: 'low',
      onProgress: onProgress,
    );
    return r.data;
  }

  /// People worth contacting about [job] or at [company]: recruiters,
  /// hiring managers, teams, from public professional pages.
  Future<AiResult> findLeads(CandidateProfile p, {Job? job, String company = '', Progress? onProgress}) =>
      ai.ask(
        system: _system(p),
        content: [
          _candidate(p),
          if (job != null) _text('<job>\n${_job(job)}\n</job>'),
          _text(
            '''
Find people and teams the candidate could contact about ${job != null ? 'this job' : 'openings${company.isEmpty ? ' in their field' : ' at $company'}'}: the recruiter or hiring manager named on the advert, the employer's recruitment team, specialist recruitment agencies and consultants for this field and area, and professional groups or events where they would meet hiring managers. Use only professional information that people or organisations publish for this purpose (adverts, team pages, agency sites, public LinkedIn profiles and company pages). Do not guess e-mail addresses or include private contact details. For each, say how to approach them and what to say first.''',
          ),
        ],
        schema: LeadSuggestion.schema,
        web: true,
        searches: 8,
        effort: 'medium',
        onProgress: onProgress,
      );

  /// A short message: outreach to a lead, chasing feedback, thanks after an
  /// interview.
  Future<Draft> draft(CandidateProfile p, {required String purpose, String context = ''}) async {
    final r = await ai.ask(
      system: _system(p),
      content: [
        _candidate(p),
        if (context.isNotEmpty) _text('<context>\n$context\n</context>'),
        _text(
          'Write this message for the candidate to send: $purpose. Keep it short, warm and professional, '
          'specific to the context, with one clear ask. Sign with the candidate\'s name.',
        ),
      ],
      schema: Draft.schema,
      effort: 'low',
      maxTokens: 8000,
    );
    return Draft(r.data);
  }

  /// A practice interview's questions.
  Future<AiResult> practiceQuestions(
    CandidateProfile p, {
    required String role,
    required String mode,
    Job? job,
    int count = 8,
    Progress? onProgress,
  }) => ai.ask(
    system: _system(p),
    content: [
      _candidate(p),
      if (job != null) _text('<job>\n${_job(job)}\n</job>'),
      _text(
        '''
Prepare $count interview questions for the candidate for the role of $role.
Kind of interview: ${practiceModes[mode] ?? mode}.
Research how this employer or sector interviews now (competency frameworks, values, panel formats, assessment centres, current hot topics including AI adoption) and ask what a real panel would ask in $today's market. Make at least a third of them hard, and include questions that probe the gaps in the candidate's CV. For each, say what the panel is testing and what a top answer includes.''',
      ),
    ],
    schema: PracticeQuestion.schema,
    web: true,
    searches: 5,
    effort: 'medium',
    onProgress: onProgress,
  );

  /// Scores an answer on every dimension, with a better version.
  Future<AnswerReview> review(
    CandidateProfile p, {
    required String role,
    required String mode,
    required PracticeQuestion question,
    required String answer,
  }) async {
    final m = AnswerMetrics.of(answer);
    final r = await ai.ask(
      system: _system(p),
      content: [
        _candidate(p),
        _text(
          '<interview role="${_attr(role)}" kind="${_attr(practiceModes[mode] ?? mode)}">\n'
          '<question category="${_attr(question.category)}">${question.question}</question>\n'
          '<testing>${question.why}</testing>\n'
          '<top_answer_includes>${question.lookFor.join('; ')}</top_answer_includes>\n'
          '<answer>\n$answer\n</answer>\n'
          '<measured words="${m.words}" speaking_seconds="${m.speakingTime.inSeconds}" fillers="${m.fillers}" '
          'i_count="${m.iCount}" we_count="${m.weCount}" figures="${m.figures}" star="${m.star.join(',')}"/>\n'
          '</interview>',
        ),
        _text(
          '''
Evaluate the answer as a strict, experienced panel would in today's market. Score each dimension 0 to 10:
- Relevance: answers the question asked, for this role.
- Structure: clear STAR (situation, task, action, result) or equivalent; easy to follow.
- Evidence: a specific, real example with the candidate's own actions, not generalities.
- Impact: measurable results and what changed because of them.
- Communication: concise, confident, right length (about two minutes), few fillers.
- Role knowledge: understanding of the role, sector, standards and current practice.
- AI and change readiness: awareness of how AI and new tools are changing the work, and adaptability.
Then the overall score, what was strong, what to improve (most important first), any red flags, a better answer using only the candidate's real experience, and the follow-up a tough interviewer would ask.''',
        ),
      ],
      schema: AnswerReview.schema,
      effort: 'medium',
      maxTokens: 12000,
    );
    return AnswerReview(r.data);
  }

  String _attr(String s) => s.replaceAll('"', "'");
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
