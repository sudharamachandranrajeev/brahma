# LinkedIn lead connections with n8n: study and workflow

What Udyoga can do with an [n8n](https://n8n.io) workflow to find more professional contacts, and
LinkedIn ones in particular, without putting the user's account at risk. Researched October 2026.

## The question

Could an n8n workflow find recruiters, hiring managers and peers for each job and help the
candidate connect with them on LinkedIn, beyond what the app's built-in AI search already does?

## What LinkedIn allows

- **The User Agreement forbids automation and scraping.** It bans software, scripts, robots,
  crawlers and browser add-ons that scrape the service or copy profiles. It also bans "bots or
  other automated methods" that add contacts or send messages. Accounts that send automated or bulk
  invitations get restricted.
- **LinkedIn enforces this in court.** It sued Nubela, the company behind Proxycurl (the best-known
  LinkedIn profile API), in January 2025. The case ended in a permanent injunction, and Proxycurl
  shut down on 4 July 2025. Any third-party "LinkedIn data API" carries the same risk.
- **The official API does not cover this.** n8n's built-in LinkedIn node does one thing: create a
  post as a person or an organisation, through a LinkedIn developer app (Share on LinkedIn plus
  Sign In with LinkedIn). There is no endpoint for people search or invitations open to ordinary
  developers. A community report from April 2026 also says the node failed with a 426 error
  because it pinned an expired LinkedIn API version.

## Options considered

| Approach | Verdict |
| --- | --- |
| Browser automation (Puppeteer or Playwright in n8n) that searches LinkedIn and sends invitations | **Rejected.** Against the User Agreement, and the account gets restricted. |
| Third-party LinkedIn data or "safe automation" APIs | **Rejected.** They depend on scraping (see Proxycurl) and can vanish overnight. |
| Official LinkedIn API | Posting only. Useful for an "open to work" or expertise post the user approves, not for finding people. |
| **Search engine "X-ray" queries + AI ranking + the user sends each request** | **Chosen.** Reads only what search engines show publicly and never touches LinkedIn's site or API. A person makes every contact. |

## The workflow

`udyoga-leads.json` is an n8n workflow that Udyoga calls for one job at a time:

```
Udyoga ── POST job ──▶ Webhook (checks X-Udyoga-Secret)
                         ▼
                       Build searches     4 queries: site:linkedin.com/in recruiters at the employer,
                         ▼                people in the team, the employer's recruitment pages,
                       Web search         specialist agencies (Brave Search API, 1 query a second)
                         ▼
                       Claude             picks up to 10 people or teams, says why, and drafts a
                         ▼                connection note under 300 characters (structured output)
                       Shape leads        drops any link the search did not return
                         ▼
Udyoga ◀── leads ───── Respond to Udyoga
```

Udyoga adds the answers to Contacts, linked to the job and due today. The user opens the profile
from the app, reads it, edits the note and sends the request in LinkedIn. Marking the contact as
contacted in Udyoga sets a reminder to follow up a week later.

**What is sent:** the job (title, employer, place, link, up to 4,000 characters of the advert) and
the candidate's current role, target roles, top skills and country. The candidate's name, e-mail,
phone and CV are never sent. It all goes to the user's own n8n, and from there only to the search
API and Anthropic, using the user's own keys.

**Why n8n rather than the app:** the workflow is the user's to change. They can add sources (their
professional body's directory, a job board's API, a CRM), set rules ("never agencies") or send a
daily digest of new contacts by e-mail or ntfy. All of this works without an app release.

## Set it up

1. Run n8n: the cloud version, or self-hosted with
   `docker run -it --rm -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n`.
   Self-hosted on your own network can use `http://`; anything else needs `https://`.
2. In n8n, *Workflows > Import from file* and pick `udyoga-leads.json`.
3. Create three **Header Auth** credentials and select each in its node:
   - *Udyoga secret* (Webhook node): name `X-Udyoga-Secret`, value a long random string.
   - *Brave Search* (Web search node): name `X-Subscription-Token`, value your key from
     [api.search.brave.com](https://api.search.brave.com) (free tier available).
   - *Anthropic API key* (Claude node): name `x-api-key`, value your Claude API key.
4. Activate the workflow and copy the Webhook node's **production** URL.
5. In Udyoga: *Settings > n8n lead workflow > Connect*. Enter the URL and the same secret.
6. Open a job and press **Ask my n8n workflow** on its Contacts card.

The workflow uses `claude-opus-5-5`. To cut cost, change `model` in *Prepare Claude request*.
Another search API needs only a different URL in *Web search*, with its results mapped in
*Prepare Claude request*.

**Answer format.** Respond with `{"leads": [...]}`, or a one-item list holding that object. Each
lead has `name` plus any of `title`, `company`, `kind` (recruiter, hiring_manager, referral, peer,
mentor, other), `linkedin`, `email`, `source`, `why` and `approach`. Leads without a name are skipped.

## Good practice for the user

- Send a few personalised requests a day, not dozens. Mention the job or something specific.
- Contact the named recruiter first, then the hiring manager, then peers for a referral.
- Never buy contact lists or let any tool click "Connect" for you.

## Sources

- n8n LinkedIn node: <https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.linkedin/>
- LinkedIn node API-version error (April 2026): <https://community.n8n.io/t/error-with-the-linkedin-node/289071>
- LinkedIn User Agreement on scraping and automation (summary):
  <https://conductatlas.com/platform/linkedin/linkedin-user-agreement/prohibition-on-scraping-and-automated-data-collection/>
- Proxycurl shutdown, from its founder: <https://nubela.co/blog/goodbye-proxycurl/>
- LinkedIn and scrapers: <https://news.bloomberglaw.com/artificial-intelligence/linkedins-war-against-bot-scrapers-ramps-up-as-ai-gets-smarter>
