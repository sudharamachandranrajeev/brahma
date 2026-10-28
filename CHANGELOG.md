# Changelog

## 0.4.4 (2026-10-28)

- Everything in 0.4.3, whose Windows build failed: the Windows app builds again with the newest
  Visual Studio compiler.

## 0.4.3 (2026-10-27)

- Several CVs: import up to eight tailored versions at once and the AI merges them into one master
  profile (each job once, every skill, the most recent details), adds the roles they aim at to your
  targets and lists the versions on the Profile page. Certifications you hold go to Growth as done.
- Ideas and wins on the Growth page: jot down an idea, a tip or a win in seconds. The AI reads them
  with your profile in every request; an idea can become a goal.
- LinkedIn data import on the Growth page: import the ZIP LinkedIn sends you. It fills gaps in the
  profile, turns recommendations into wins, adds recent applications, saved jobs and useful
  connections, and never doubles anything. Read on the device; nothing is fetched from LinkedIn.

## 0.4.2 (2026-10-27)

- ChatGPT subscription (Linux and Windows): use the Codex you have installed, signed in to your own
  ChatGPT plan, for every AI feature instead of an API key. Like the Claude subscription, access
  lasts 24 hours and Udyoga asks to renew it at the next start; it never sees your login. Codex
  cannot read PDFs, so paste a CV's text when using it.

## 0.4.1 (2026-10-25)

- LinkedIn: the week plan and repurpose tools now pick from the hook formulas too (only the post
  writer had them).

## 0.4.0 (2026-10-25)

- LinkedIn studio: profile score and rewrite, post writer, comment writer, connection notes and
  follow-ups (also from a contact), inbox triage, replies to comments, week plan, post audit,
  carousel (with a PDF to upload) and repurposing. Everything is a draft for you to post by hand,
  in your own voice (set it on the page). A human check cleans each draft of dashes, invisible
  characters and stock phrases and scores it on five checks; it also runs on a CV and cover letter.
- Claude subscription (Linux and Windows): use the Claude Code you have installed, signed in to
  your own plan, instead of an API key. Udyoga's access lasts 24 hours and it asks you to renew it
  at the next start; it never sees your Claude login.
- Updates: Udyoga checks for a new version at start and asks before installing. Settings > Updates
  has a switch to turn the start-up check off and a Check now button.

## 0.3.1 (2026-10-25)

- Phones get new navigation: a floating dock that scrolls through every screen (the "More"
  sheet is gone) and a side panel listing them all with what each is for. Swipe right on any
  page, or tap the dock's menu button, to open it; Back closes it.

## 0.3.0 (2026-10-24)

- In-app updates: Settings > Updates finds a newer release on GitHub, downloads it, checks it against
  the release's SHA256SUMS.txt and installs it (Android's installer, the Windows setup, or the Linux
  `install.sh`). Today also points to a waiting update. Release builds only.
- Gemini as a second AI service: add a free key from Google AI Studio in Settings (the key is
  checked before it is saved) and every AI feature works with Gemini 3.8 Flash or 3.5 Flash-Lite,
  web research through Google Search and URL context included. With keys for both, choose the
  model in Settings.

## 0.2.0 (2026-10-24)

- n8n lead workflow: connect your own n8n (Settings) and a job's Contacts card can ask it for
  recruiters, hiring managers and agencies. A ready-made workflow and a study of what LinkedIn
  allows are in `docs/n8n`. It uses search-engine results and Claude; you send every connection
  request yourself.

## 0.1.0 (2026-10-24)

First test release.

- Profile from an imported CV (PDF, Word, text), with targets: roles, countries, places, work modes.
- Jobs from Adzuna, Reed, Remotive, Jobicy and Arbeitnow, refreshed every few hours, merged across
  sites, with a quick fit score; optional AI web search.
- Fit assessment, tailored CV and cover letter (Word and text export), applicant-tracking keywords.
- Applications by stage with follow-ups, No reply after six weeks, AI-drafted chasers, thank-you
  notes and feedback requests; reminders to Google Calendar or an `.ics` file.
- Contacts found from public pages or added by hand, with LinkedIn search links and drafted messages.
- Interview practice in five modes with on-device answer measures and a seven-dimension AI review.
- Career assessment, career map of five to eight paths, and growth goals for certifications and
  courses.
- Look: azure canvas, tilting cards, floating pill navigation, depth page transitions, hero logos;
  Inter and Plus Jakarta Sans bundled (SIL OFL).
- Sync and security from Brahma: encrypted database, end-to-end encrypted sync, one account across
  the suite.
