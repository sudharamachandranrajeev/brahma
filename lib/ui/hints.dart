/// Udyoga's hints, by id, on top of the shared ones (coreHints). Tooltips
/// use the short ones; page banners (ids starting `page.`) explain a whole
/// screen once.
const udyogaHints = <String, String>{
  // Navigation
  'nav.today': 'Follow-ups due, interviews, new matches and your next steps.',
  'nav.jobs': 'Openings matched to your profile from job sites and the AI search.',
  'nav.applications': 'Every application by stage, with follow-up dates.',
  'nav.interview': 'Practice interviews: answer questions and get scored.',
  'nav.career': 'Your career map: every path from your current role.',
  'nav.contacts': 'Recruiters, hiring managers and referrers to follow up.',
  'nav.growth': 'Certifications, courses and skills to build.',
  'nav.profile': 'Your CV, experience and what you are looking for.',
  'nav.settings': 'Claude API key, job sites, the AI routine, sync and security.',
  'nav.more': 'The rest of Udyoga.',
  // Jobs
  'jobs.refresh': 'Check the job sites now.',
  'jobs.ai': 'Ask Claude to search LinkedIn, Indeed, national and public-sector boards for you.',
  'jobs.add': 'Paste a job link or the advert text.',
  'jobs.portals': 'Open searches for your roles on the main job sites, in your browser.',
  'jobs.fit': 'How well the job fits you, 0 to 100. A star means the AI assessed it.',
  'job.assess': 'Claude reads the advert, researches the employer and scores your fit honestly.',
  'job.tailor': 'A CV and cover letter for this job, from your real experience only.',
  'job.leads': 'Find the recruiter, hiring manager and agencies for this job.',
  // Applications
  'apps.followup': 'When to chase this up. Add it to your calendar so it reminds you.',
  'apps.calendar': 'Download every follow-up as a calendar file with 9 am alerts.',
  'apps.chase': 'Claude drafts a short, polite message asking for an update or feedback.',
  // Interview
  'interview.mode': 'The kind of interview to practise.',
  'interview.metrics': 'Measured on this device: length, speaking time, fillers, "I" against "we" and STAR.',
  // Career
  'career.map': 'Every realistic path from your current role, with timeframes, pay and AI exposure.',
  'career.target': 'Adds this path\'s steps as goals and its certifications to Growth.',
  'career.assess': 'A candid assessment of where you stand in today\'s market.',
  // Settings
  'settings.ai': 'Your own Claude API key. Requests go straight from this device to Anthropic.',
  'settings.routine':
      'Let the AI search for jobs and refresh your career map on its own. Each run costs a little.',
  'settings.feeds': 'Free keys for Adzuna (many countries) and Reed (UK) add their jobs to each refresh.',
  // Page banners
  'page.today':
      'Your day: follow-ups due, interviews coming up, the best new matches and what to do next. '
      'Hover or long-press anything for a tip.',
  'page.jobs':
      'Openings for your target roles in your countries, refreshed every few hours from job sites, and by '
      'the AI search when you turn it on. Open one to assess your fit, tailor your CV and apply.',
  'page.applications':
      'Each application by stage. Udyoga sets a follow-up date when it moves on, and marks it No reply '
      'after six weeks of silence.',
  'page.interview':
      'Questions a real panel would ask for the role, then a strict review of each answer on seven '
      'dimensions, with a better answer and the follow-up to expect.',
  'page.career':
      'Where you can go from here: up, sideways, specialist, management or a change of field, judged for '
      'realism and AI exposure. Pick a path to turn it into goals.',
  'page.contacts':
      'People to reach: recruiters, hiring managers, referrers. Claude finds public professional contacts; '
      'LinkedIn searches open in your browser.',
  'page.growth':
      'What to learn next and how far you have got. Suggestions come from your assessment and career map.',
  'page.profile':
      'Import your CV and Claude fills this in. Everything Udyoga does starts from it, so keep it accurate.',
};
