import 'package:udyoga/domain/book.dart';
import 'package:udyoga/domain/insights.dart';
import 'package:udyoga/domain/pipeline.dart';

import 'support.dart';

/// A book with something on every page: profile, jobs, applications at
/// several stages, a lead, a career map, an assessment, growth items and a
/// practice round with a reviewed answer.
Future<void> seedBook(CareerBook book, {String today = '2026-10-24'}) async {
  await book.saveProfile(sampleProfile);
  final ids = await book.importPostings(
    [
      samplePosting(closing: '2026-10-28'),
      samplePosting(id: '2', title: 'Digital Nurse Specialist', company: 'Sample Care Group'),
      samplePosting(id: '3', title: 'EPR Trainer', company: 'Northwind Health'),
      samplePosting(
        id: '4',
        title: 'Nursing Informatics Lead',
        company: 'Contoso Medical',
        description: 'Lead EPR optimisation and patient safety training for nursing staff.',
      ),
      samplePosting(id: '5', title: 'Patient Safety Educator', company: 'Fabrikam Clinics'),
      samplePosting(id: '6', title: 'Digital Health Analyst', company: 'Example Labs', description: 'Data.'),
    ],
    sampleProfile,
    today: today,
  );
  await book.setJobStatus(ids[0], 'saved');
  final a1 = await book.applyFor(await book.job(ids[1]), today: '2026-10-10', sent: true);
  final a2 = await book.applyFor(await book.job(ids[2]), today: '2026-10-01', sent: true);
  await book.moveTo(a2, Stage.interview, date: '2026-10-15');
  await book.logEvent(a2, 'interview', at: '2026-10-30T10:00', summary: 'Panel interview');
  await book.setFollowUp(a1, '2026-10-20');
  await book.importLeads([
    const LeadSuggestion({
      'name': 'Sam Recruiter',
      'title': 'Talent Partner',
      'company': 'Sample Care Group',
      'kind': 'recruiter',
      'linkedin': '',
      'email': '',
      'source': '',
      'why': 'Hires for digital nursing roles',
      'approach': 'Mention the e-observations pilot',
    }),
  ], today: today);
  const outlook = {
    'exposure': 'medium',
    'summary': 'Documentation is being automated; judgement and change leadership grow.',
    'tasksAtRisk': ['Manual charting'],
    'tasksGrowing': ['Clinical safety of AI tools'],
    'skillsToBuild': ['Clinical safety officer training'],
  };
  await book.saveReport(
    'career_map',
    {
      'current': {'role': 'Staff Nurse', 'level': 'Band 5', 'summary': 'Ward nurse with digital experience.'},
      'paths': [
        {
          'name': 'Into informatics',
          'direction': 'specialist',
          'realism': 'likely',
          'summary': 'Build on the EPR roll-out.',
          'aiOutlook': outlook,
          'steps': [
            {
              'role': 'Clinical Informatics Nurse',
              'timeframe': '0-1 years',
              'salaryRange': '£38k-£45k',
              'likelihood': 70,
              'requirements': ['EPR project work'],
              'certifications': [],
              'employers': ['Health trusts'],
            },
          ],
          'risks': ['Few posts locally'],
          'firstMoves': ['Join the digital nurse network'],
        },
        {
          'name': 'Ward management',
          'direction': 'management',
          'realism': 'possible',
          'summary': 'Lead a ward.',
          'aiOutlook': outlook,
          'steps': [],
          'risks': [],
          'firstMoves': [],
        },
      ],
      'recommended': 'Into informatics',
      'rationale': 'Strongest evidence on the CV.',
      'marketTrends': ['Digital nursing posts up in 2026'],
    },
    const [],
    at: '${today}T09:00',
  );
  await book.saveReport(
    'assessment',
    {
      'verdict': 'Competitive for band 6 informatics roles; strengthen project evidence.',
      'marketPosition': {'level': 'Mid-level', 'competitiveness': 'average', 'summary': 'Solid ward record.'},
      'strengths': [
        {'point': 'Led a digital pilot', 'evidence': 'e-observations roll-out'},
      ],
      'weaknesses': [
        {'point': 'No formal informatics training', 'fix': 'Take an introductory course'},
      ],
      'toughestChallenges': [
        {'challenge': 'Competing with IT staff', 'why': 'Panels want both', 'prepare': 'Quantify the pilot'},
      ],
      'aiImpact': outlook,
      'targetRoles': [
        {
          'title': 'Clinical Informatics Nurse',
          'why': 'Direct fit',
          'fit': 72,
          'salaryRange': '£38k-£45k',
          'searchTerms': ['clinical informatics nurse'],
        },
      ],
      'countries': [
        {
          'country': 'GB',
          'demand': 'high',
          'salaryRange': '£38k-£45k',
          'rightToWork': 'Yes',
          'verdict': 'Best market',
        },
      ],
      'learning': [
        {
          'title': 'Introduction to Health Informatics',
          'kind': 'course',
          'provider': 'Example Academy',
          'url': '',
          'cost': 'free',
          'duration': '6 weeks',
          'why': 'Fills the training gap',
          'priority': 'essential',
        },
      ],
      'quickWins': ['Update the LinkedIn headline'],
    },
    const [],
    at: '${today}T09:05',
  );
  await book.suggestLearning([
    const LearningSuggestion(title: 'Clinical Safety Officer training', kind: 'certification'),
  ], today: today);
  final round = await book.startPractice(
    role: 'Clinical Informatics Nurse',
    mode: 'competency',
    questions: const [
      PracticeQuestion({
        'question': 'Tell us about a change you led.',
        'category': 'Behavioural',
        'why': 'Leadership of change',
        'lookFor': ['Situation', 'Measured result'],
        'difficulty': 'standard',
      }),
    ],
    at: '${today}T08:00',
  );
  await book.saveAnswer(
    round,
    0,
    'I led the e-observations pilot on a 28-bed ward and trained 40 staff; late observations fell 30%.',
    const AnswerReview({
      'score': 7.4,
      'rating': 'strong',
      'dimensions': [
        {'name': 'Relevance', 'score': 8, 'comment': 'On point'},
      ],
      'strengths': ['Numbers'],
      'improvements': ['Say what you would do differently'],
      'redFlags': [],
      'betterAnswer': '',
      'followUp': 'What went wrong?',
    }),
    at: '${today}T08:10',
  );
}
