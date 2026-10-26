/// Vani's hints, by id, on top of the shared ones (coreHints). Tooltips use
/// the short ones; page banners (ids starting `page.`) explain a screen once.
const vaniHints = <String, String>{
  // Navigation
  'nav.home': 'Your accounts at a glance: numbers, today\'s replies, what goes out next.',
  'nav.calendar': 'Everything scheduled, by month or week. Drag a post to move it.',
  'nav.inbox': 'Comments, replies, DMs, mentions and live chat from every account.',
  'nav.alerts': 'Alerts, inbox rules and discovery watches.',
  'nav.analytics': 'Followers, best times to post and your top content.',
  'nav.accounts': 'Connected accounts and the app credentials the hub signs in with.',
  'nav.settings': 'Hub connection, posting queue, saved replies, AI, sync and security.',
  'nav.compose': 'Write a post for one or many accounts.',
  'nav.more': 'The rest of Vani.',
  // Compose
  'compose.ai': 'AI drafts a caption for each platform from a short brief.',
  'compose.queue': 'Takes the next free slot of your posting queue (Settings > Queue).',
  'compose.recycle': 'Posts it again this many days after it goes out. For evergreen content.',
  'compose.firstComment': 'Posted as the first comment straight after publishing: hashtags, links.',
  'compose.custom': 'Different wording per account. Empty fields use the main text.',
  // Inbox
  'inbox.refresh': 'Ask the hub to check every account for new replies now.',
  'inbox.suggest': 'AI suggests replies in your voice.',
  'inbox.private': 'Replies to the comment in a direct message instead of in public.',
  'inbox.triage': 'AI sorts new items by mood and flags the ones waiting on an answer.',
  // Alerts
  'alerts.describe': 'Say what you are looking for in plain English; AI drafts the sources and keywords.',
  'alerts.ai': 'AI checks each new find against your description and alerts only on good matches.',
  'alerts.run': 'Run this watch now instead of waiting for its schedule.',
  'rules.description': 'A condition AI judges, e.g. "asks about price or availability".',
  // Accounts
  'accounts.check': 'Re-check the account\'s sign-in with the platform.',
  'credentials.redirect': 'Paste this into the platform\'s developer console as the OAuth redirect URI.',
  // Analytics
  'analytics.best': 'When your posts got the most engagement, in your local time.',
  // Settings
  'settings.hub':
      'Your own hub on your Cloudflare account. It keeps your accounts signed in and runs the schedule.',
  'settings.ai': 'Which AI writes captions and replies: an API key on the hub, or your own Claude, ChatGPT or Gemini plan through its official app on a computer.',
  'settings.queue': 'Weekly slots that "Add to queue" fills in order.',
  'settings.notify': 'Sends a test alert to your phone through the hub.',
  'settings.language': 'Inbox items in other languages are translated into this one.',
  'settings.profiles':
      'Profiles keep different people\'s or businesses\' social media apart on one hub. Anyone with the hub '
      'token can open every profile.',
  'settings.weekly': 'Every Monday the hub sends a short summary of the week. This sends one now.',
};
