# Sentinel rules

`rules.json` holds advisories that every Brahma app shows in Sentinel, for problems found between
releases. Each app fetches it (synced devices through their own sync server, `GET /api/rules`) and
trusts it only when `rules.json.sig` verifies against the Ed25519 public key built into
`core/lib/src/sentinel/rules.dart`. An expired file, or one older than a file the device has seen,
is refused.

```json
{
  "expires": "2027-10-26T00:00:00Z",
  "advisories": [
    {
      "id": "artha-0.2.0-token-log",
      "apps": ["artha"],
      "below": "0.2.1",
      "status": "serious",
      "title": "Update Artha",
      "why": "Artha before 0.2.1 wrote the sync token to its log.",
      "steps": "Install Artha 0.2.1 or newer."
    }
  ]
}
```

`apps` (app ids) and `below` (a version) are optional; `status` is good, info, warning, serious or
critical. After editing, sign it and commit both files:

```sh
node scripts/sign-rules.ts      # key: ~/.config/brahma/rules-signing.pem, never committed
```
