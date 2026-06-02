# Reference: Staging-file template

The per-ad markdown file written to `~/.linkedinads/staging/<YYYY-MM-DD>-<slug>.md` at step 9 of the workflow.

Section order mirrors LinkedIn Campaign Manager's wizard so copy-paste is mechanical, not "find the right field."

## Slug derivation

The slug comes from the topic-first brief or the post-first hook:
- Lowercase.
- Replace non-alphanumeric with `-`.
- Collapse consecutive `-`.
- Strip leading/trailing `-`.
- Truncate at 60 chars.
- Append `-2`, `-3`, ... on collision with existing staging files for the same date.

Examples:
- `promote the free CISO AI-readiness assessment` → `promote-the-free-ciso-ai-readiness-assessment`
- `amplify post: Your AI compliance scanner is lying to you` → `amplify-post-your-ai-compliance-scanner-is-lying-to-you`

## Template

Substitute `<placeholders>` from the picked objective + audience + offer + 3 drafted variants + image path.

```markdown
---
slug: <slug>
created_at: <ISO 8601 UTC, second precision>
trigger: <topic-first | post-first>
brief: <KK's one-line brief OR "amplify post: <original hook>">
source_post: <URL or filename if trigger == post-first, else empty>
brand: transilience
objective: <lead-gen | website-conversions>
audience: <preset name>
offer: <offer name>
image_status: <generated | missing>
status: staged
---

# Staged Ad — <slug>

## 1. Campaign

- **Objective:** <Lead Generation | Website Visits/Conversions>
- **Campaign name:** Transilience — <offer.title> (<YYYY-MM-DD>)
- **Daily budget:** $<defaults.daily_budget_usd> USD
- **Lifetime cap:** $<daily × duration> USD (<duration_days> days × $<daily>)
- **Start:** _set in CM_
- **End:** _set in CM (<duration_days> days from start)_
- **Bid strategy:** Maximum delivery (Automated)

## 2. Audience — preset: `<audience.name>`

- **Locations:** <audience.geos joined with "; ">
- **Job titles:** <audience.job_titles joined with "; ">
- **Seniorities:** <audience.seniorities joined with "; ">
- **Company size:** <audience.company_size joined with "; ">
- **Industries:** <audience.industries joined with "; ">
- **Exclude — job titles:** <audience.exclusions.job_titles or "none">
- **Exclude — companies:** <audience.exclusions.companies or "none configured — add Transilience customer list">
- **Exclude — audience lists:** <audience.exclusions.audience_lists or "none configured">
- **Estimated audience size:** _check in CM after setup_

## 3. Format

- **Ad format:** Single Image
- **Page:** Transilience AI — <brand.transilience.page_url>

## 4. Creative — 3 variants (run all three; LinkedIn optimizes)

### Variant A — problem-led
- **Headline (≤70):** <variant_a.headline>
- **Intro text (≤150):** <variant_a.intro>
- **CTA:** <offer.default_cta>
- **Headline chars:** <n> / 70 — <OK | OVER, tighten before shipping>
- **Intro chars:** <n> / 150 — <OK | OVER, tighten before shipping>

### Variant B — outcome-led
- **Headline (≤70):** <variant_b.headline>
- **Intro text (≤150):** <variant_b.intro>
- **CTA:** <offer.default_cta>
- **Headline chars:** <n> / 70 — <flag>
- **Intro chars:** <n> / 150 — <flag>

### Variant C — question-led
- **Headline (≤70):** <variant_c.headline>
- **Intro text (≤150):** <variant_c.intro>
- **CTA:** <offer.default_cta>
- **Headline chars:** <n> / 70 — <flag>
- **Intro chars:** <n> / 150 — <flag>

## 5. Image

- **File:** `<absolute path to ~/.linkedinads/images/<slug>.png>` (1200×627)
- **Generated:** <ISO 8601 UTC>
- **Brief used:** "<the constructed Gemini prompt>"
- **Regen:** `/linkedin-ad regen-image <slug>`

OR, if image-gen failed:

- **File:** MISSING — generation failed at <ISO 8601 UTC>
- **Regen:** `/linkedin-ad regen-image <slug>` (see ~/.linkedinads/failed-images/<slug>.log)

## 6. Destination URL — offer: `<offer.name>`

```
<offer.url>?utm_source=<utm_source>&utm_medium=<utm_medium>&utm_campaign=<expanded utm_campaign>&utm_content={variant}
```

- `{utm_content}` placeholder — set to `variant-a`, `variant-b`, `variant-c` when pasting each variant into CM so per-variant performance is trackable.

## 7. Notes & checks before launch

- [ ] <any over-limit copy items flagged in §4>
- [ ] <if image_status == missing> Regen or supply image before launching
- [ ] Set start date in CM
- [ ] Confirm `<offer.url>` LP is live and the form fires the conversion pixel
- [ ] <if exclusions.companies empty> Add Transilience customer-list exclusion if available
- [ ] <if objective == lead-gen> Confirm Lead Gen Form is wired to the same backend as the LP form
- [ ] Mark this file `status: copied` once paste is done
```

## Char-count flagging rules

Used in §4 of every staged ad. Apply at staging time AND in the review loop:

- **Headline:** target ≤70 chars (LinkedIn's hard limit). Over → `OVER, tighten before shipping`.
- **Intro text:** soft limit 150 chars (above-the-fold render on mobile). Hard limit 600 chars. Over soft / under hard → `OVER, tighten before shipping`. Over hard → `OVER HARD LIMIT, MUST tighten`.

The flag wording matters — KK sees it in the review loop AND again when copy-pasting into CM. Both are real failure modes.

## Status lifecycle

The `status:` frontmatter field has three values:
- `staged` (default after step 9) — waiting for KK to copy-paste into CM.
- `copied` — KK has pasted into CM and launched. Manually set in frontmatter, OR set via `/linkedin-ad mark-copied <slug>` (Phase 2 subcommand).
- `archived` — campaign ended. Manually set, used by `/linkedin-ad list` to filter.

`/linkedin-ad list` reads this field to organize the staging output.

## Collision handling

If `~/.linkedinads/staging/<YYYY-MM-DD>-<slug>.md` already exists:
1. Try `<YYYY-MM-DD>-<slug>-2.md`, then `-3`, etc.
2. Update the file's frontmatter `slug:` to match the new filename.
3. Update the UTM campaign expansion to use the new slug so per-ad UTMs stay unique.

NEVER overwrite — staged ads are KK's working copy and may contain hand-edits.
