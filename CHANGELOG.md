# Changelog

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
