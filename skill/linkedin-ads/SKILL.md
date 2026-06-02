---
name: linkedin-ads
description: Use when KK wants to draft and stage a Transilience AI LinkedIn paid ad for review before pasting into LinkedIn Campaign Manager. Triggers on /linkedin-ad, "draft a LinkedIn ad", "stage a LinkedIn ad", "set up a LinkedIn ads campaign", "amplify this post on LinkedIn", "promote this post as a paid ad", or any request to create paid LinkedIn advertising content for Transilience. Does NOT fire for organic LinkedIn posts — use kk-voice for that. Does NOT fire for Network Intelligence or KK-personal ads — Transilience-only for v1.
---

# LinkedIn Ads — Topic/Post to Staged Campaign

Orchestrate the pipeline. Detail lives in `references/`.

Output is a single markdown file per ad in `~/.linkedinads/staging/`. KK copy-pastes into LinkedIn Campaign Manager manually. The skill never calls the LinkedIn API.

## Workflow

1. **Parse trigger.**
   - Topic-first: `/linkedin-ad <topic>` — capture brief as angle seed.
   - Post-first: `/linkedin-ad --from-post <url|file>` — extract hook + insight + CTA per `references/post-extraction.md`, pre-fill angle seed with `amplify post: <hook>`.
2. **Load config** `~/.linkedinads/config.yaml`. Stop if `brand.transilience.page_url`, `audiences[]`, or `offers[]` are empty; report what's missing and copy `sample-config.yaml` if `~/.linkedinads/config.yaml` does not exist.
3. **Pick objective** (interactive) — render the two v1 objectives (`lead-gen`, `website-conversions`) as a numbered menu. Wait for pick. Skip if `--objective <name>` passed.
4. **Pick audience preset** (interactive) — render `config.audiences[].name` + `description` as a numbered menu. Wait for pick. Expand the chosen preset into the full targeting block per `references/audience-presets.md`. Skip if `--audience <preset>` passed.
5. **Pick offer** (interactive) — render `config.offers[].name` + `title` as a numbered menu. Wait for pick. Load URL + CTA + UTM template per `references/offer-library.md`. Skip if `--offer <name>` passed.
6. **Draft 3 creative variants** — load `kk-voice` skill. Produce headline + intro + CTA in `problem-led`, `outcome-led`, `question-led` styles per `references/variant-rules.md`. Flag any over-limit copy in-place (headline > 70, intro > 150 soft / 600 hard) — do NOT silently truncate.
7. **Generate image** — construct the Gemini prompt per `references/image-brief.md`. Invoke `~/.claude/skills/storyteller/scripts/gen_image.sh` with the 1200x627 composition hint baked into the prompt. Save to `~/.linkedinads/images/<slug>.png`. On failure: log to `~/.linkedinads/failed-images/<slug>.log` and continue with `MISSING` placeholder.
8. **Review loop** (interactive). Render the full staged ad. Loop on edits ("tighten variant 2's hook", "regen image", "swap audience to us-enterprise-soc-lead", "shorten the intro on variant B") until KK says "ship it".
9. **Write staging file** — `~/.linkedinads/staging/<YYYY-MM-DD>-<slug>.md` per `references/ad-template.md`. Print absolute path. NO push to LinkedIn — staging only.

## Modes & flags

- **Interactive (default):** `/linkedin-ad <topic>`. Steps 3, 4, 5, 8 prompt KK.
- **`--objective <lead-gen|website-conversions>`** — skip step 3.
- **`--audience <preset-name>`** — skip step 4. Errors if name not in config.
- **`--offer <offer-name>`** — skip step 5. Errors if name not in config.
- **`--from-post <url|file>`** — switches to post-first trigger.
- **`--no-image`** — skip step 7 entirely; staging file gets `MISSING — generation skipped`.

## Subcommands

- `/linkedin-ad regen-image <slug>` — read `<slug>`'s staging file, edit the image brief interactively (or accept), regen via `gen_image.sh`, rewrite the `## 5. Image` section only. Rest of the ad untouched.
- `/linkedin-ad list` — print one row per `~/.linkedinads/staging/*.md`: date, slug, objective, audience, offer, status from frontmatter (`staged`, `copied`, `archived`).

## Failure-mode anti-patterns

- Do NOT push to LinkedIn — staging file is the only output. KK copy-pastes manually.
- Do NOT default to a preset/objective/offer silently — every staged ad reflects KK's deliberate picks. Flags or interactive prompt only.
- Do NOT block on image-gen failure — staging file still writes with `MISSING` placeholder + regen instructions.
- Do NOT truncate over-limit copy silently — flag inline in the staging file's char-count lines, force tighten in the review loop.
- Do NOT push held formats (Instagram, Reels) — out of scope; use `storyteller` skill for vertical video.
- Do NOT call the LinkedIn API — v1 is staging-only. Adding API push later is a separate skill version.
- Do NOT overwrite an existing staging file silently — append `-2`, `-3` to slug on collision.

## Prerequisites

- `~/.linkedinads/config.yaml` exists; if missing, copy `sample-config.yaml` and pause for KK to fill `audiences[]` + `offers[]`.
- `GEMINI_API_KEY` set in env OR `Gemini Key.txt` present in `$HOME/Projects/StoryTeller/` (`gen_image.sh` handles both). Skip the check if running `--no-image`.
- `storyteller` skill installed at `~/.claude/skills/storyteller/` (for `scripts/gen_image.sh`).

**REQUIRED VOICE SKILL:** `kk-voice` — load before drafting variants (step 6). The Jennifer Chen audience profile is the bar every variant must clear.

## Scope (v1)

- Brand: **Transilience AI only**.
- Ad format: **Single Image (1200×627) only**.
- Objectives: **Lead Generation + Website Visits/Conversions only**.
- Audience: **US-market named presets** in config.
- Output: **Markdown file per ad** in `~/.linkedinads/staging/`. No API calls.

## Phase 2 (deferred — stub references exist but not wired)

- **StoryTeller integration** — `references/storyteller-integration.md` stub. Will plug into StoryTeller's step 8.5 once v1 has dogfooded a few real ads.
- **Additional formats** — Document, Video, Carousel.
- **Additional objectives** — Brand Awareness, Engagement.
- **Network Intelligence + KK-personal brands** — separate audience/offer sets in config.
- **Direct LinkedIn API push** — replaces copy-paste workflow once the staging format is stable.
