# Reference: Audience preset expansion

How the skill turns a preset name (e.g. `us-mid-market-ciso`) into the structured targeting block in §2 of the staging file.

## Lookup

1. Read `config.audiences[]`.
2. Find the entry where `name == <picked name>`. Error with `unknown audience preset: <name>` if not found.
3. Expand its fields into §2 of the staging template (see `ad-template.md`).

## Field-by-field expansion

| Config field | Staging file output | Notes |
|---|---|---|
| `geos` | "Locations: <joined>" | Join with `; `. v1 is US-only — every preset should include `"United States"`. |
| `job_titles` | "Job titles: <joined>" | Join with `; `. These map directly to LinkedIn's job-title targeting (free text — LinkedIn does fuzzy matching). |
| `seniorities` | "Seniorities: <joined>" | LinkedIn-supported values: Entry, Senior, Manager, Director, VP, CXO, Owner, Partner. |
| `company_size` | "Company size: <joined>" | LinkedIn-supported buckets: `1-10`, `11-50`, `51-200`, `201-500`, `501-1000`, `1001-5000`, `5001-10000`, `10001+`. Match these strings exactly. |
| `industries` | "Industries: <joined>" | Free text, but LinkedIn matches against its industry taxonomy. Use the canonical names: "Financial Services", "Hospital & Health Care", "Computer Software", "Information Technology and Services", "Insurance", etc. |
| `exclusions.job_titles` | "Exclude — job titles: <joined or 'none'>" | Empty list renders as `none`. |
| `exclusions.companies` | "Exclude — companies: <joined or hint>" | Empty list renders as `none configured — add Transilience customer list`. Forces KK to remember to upload it. |
| `exclusions.audience_lists` | "Exclude — audience lists: <joined or 'none configured'>" | These are LinkedIn matched-audience IDs (uploaded email lists or website-visitor segments). |

## Validation

Before expanding, check the preset:
- `geos` non-empty (required — LinkedIn rejects an ad with no geo).
- At least ONE of `job_titles`, `seniorities`, or `industries` non-empty. An ad with only geo + company_size is too broad and burns budget.

If validation fails, surface the issue and ask KK to either pick a different preset or fix the config.

## Adding a new preset

KK adds entries to `~/.linkedinads/config.yaml > audiences[]`. The skill picks them up on the next invocation — no install step.

## Phase 2 — overrides

Phase 2 subcommand idea: `--audience-override '{"job_titles": ["Add this", "And this"]}'` to extend a preset without editing config. Out of scope for v1.
