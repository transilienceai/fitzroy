# Reference: Offer library + UTM construction

How the skill turns an offer name (e.g. `free-ai-readiness-assessment`) into the destination URL block in §6 of the staging file.

## Lookup

1. Read `config.offers[]`.
2. Find the entry where `name == <picked name>`. Error with `unknown offer: <name>` if not found.
3. Construct the destination URL with UTMs per the rules below.

## UTM construction

The offer's `utm_campaign` may contain `{slug}` — substitute with the ad's slug at staging time.

Final URL format:
```
<offer.url>?utm_source=<utm_source>&utm_medium=<utm_medium>&utm_campaign=<expanded utm_campaign>&utm_content={variant}
```

Note: `{utm_content}` is a literal placeholder that stays in the staging file. KK substitutes `variant-a`, `variant-b`, or `variant-c` when pasting each variant into Campaign Manager. This gives per-variant performance tracking without managing 3 separate URLs upstream.

## Worked example

Offer config:
```yaml
- name: "free-ai-readiness-assessment"
  title: "Free AI Security Readiness Assessment"
  url: "https://transilience.ai/assessment"
  default_cta: "Learn more"
  utm_source: "linkedin"
  utm_medium: "paid"
  utm_campaign: "ai-readiness-{slug}"
```

Ad slug: `promote-the-free-ciso-ai-readiness-assessment`

Final URL in §6 of staging file:
```
https://transilience.ai/assessment?utm_source=linkedin&utm_medium=paid&utm_campaign=ai-readiness-promote-the-free-ciso-ai-readiness-assessment&utm_content={variant}
```

## CTA allowlist

LinkedIn rejects off-list CTA values at ad upload time. The supported set for Single Image ads (as of 2026-06):

- `Learn more`
- `Sign up`
- `Register`
- `Subscribe`
- `Download`
- `Get quote`
- `Request demo`
- `Apply`
- `Visit website`
- `Join`
- `Attend`

`offer.default_cta` MUST be from this list. If KK adds a new offer with an off-list CTA, the skill flags it during config load (step 2 of the workflow) — do NOT wait for ad rejection.

## URL hygiene

- The skill does NOT URL-encode the `utm_campaign` value. LinkedIn UI accepts un-encoded ASCII; if the slug ever contains non-ASCII, encode it manually.
- The skill does NOT validate `offer.url` is reachable. KK confirms LP liveness in the §7 pre-launch checklist of the staging file.
- The skill does NOT verify the conversion pixel fires. Again — §7 checklist item.

## Adding a new offer

KK adds entries to `~/.linkedinads/config.yaml > offers[]`. The skill picks them up on next invocation. Ensure `default_cta` is from the CTA allowlist above.
