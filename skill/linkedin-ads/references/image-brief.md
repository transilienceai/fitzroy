# Reference: Image brief construction (subject-rich + audience-driven)

How the skill builds the Gemini prompt at step 7. v2 design: the **SUBJECT** is derived from the offer + brief; the **STYLE** is derived from the audience.

**Reuses:** `~/.claude/skills/storyteller/scripts/gen_image.sh` (with `IMAGE_STYLE` env var override).

## When to call

Step 7 of the SKILL.md workflow — after variants draft, before the review loop. ONE image per ad, used for all 3 variants.

## File naming

```
~/.linkedinads/images/<slug>.png
```

Gemini may return JPEG even when the caller writes `.png`. `gen_image.sh` detects via magic bytes and renames. Track whichever path the helper echoes.

If the file already exists for this slug, the skill prompts: "image exists — reuse, regen, or skip?" Default: reuse.

## Resolution order

1. **STYLE** ← (a) `--image-style <name>` flag if set, else (b) `audience.preferred_image_styles[0]`, else (c) `photo` as global fallback.
2. **SUBJECT** ← derived from offer.title + brief + extracted specifics (named clouds / frameworks / numbers / license types).
3. **COMPOSITION HINTS** ← appended to subject (asymmetric negative space for headline overlay, landscape 1200x627).

## The new prompt template

```
<STYLE block from references/image-styles.md, exported as IMAGE_STYLE env var>

Subject: <one-sentence core visual concept derived from the offer.title + brief>

Concrete visual elements (these MUST appear in the image):
- <element 1 extracted from brief or offer>
- <element 2 ...>
- <element 3 ...>

Composition: 1200x627 landscape; asymmetric weight pushing the subject to the right or
center, leaving the LEFT portion lower-density for an overlay headline. No headline text
on the image itself (LinkedIn renders that separately).
```

The SUBJECT is *what the ad is about*, not *who's looking at the ad*. The audience controls STYLE, not subject.

## Worked example — the Shasta FOSS scanner ad

**Inputs:**
- Offer: `try-shasta` — "Try Shasta — Free, Open-Source Cloud & AI Security Scanner" — https://shasta.transilience.cloud
- Brief: "Promote Shasta as a free and open-source cloud and AI security scanner to security folks (not CISOs) in mid-market healthcare and financial services."
- Audience: `us-midmkt-healthfin-security-practitioners` → `preferred_image_styles[0] = ascii-diagram`

**Extracted specifics from offer + brief:**
- Multi-cloud coverage: AWS, Azure, GCP, Entra
- AI workload scanning included
- 8-framework compliance crosswalk
- MIT-licensed / open-source
- Deploys in your own AWS

**Constructed prompt:**

```
[IMAGE_STYLE = ascii-diagram block from image-styles.md]

Subject: An ASCII / terminal-style architecture diagram of a multi-cloud security
scanner crosswalking findings to compliance frameworks.

Concrete visual elements (these MUST appear in the image):
- Four cloud sources labeled AWS, Azure, GCP, Entra on the left, with ASCII arrows
  flowing into a central box labeled SHASTA
- The SHASTA box outputs arrows to a stack of labeled framework boxes on the right:
  NIST, SOC 2, ISO 27001, HIPAA, EU AI Act, OWASP LLM, NIST AI RMF, MITRE ATLAS
- A small footer line in monospace: "MIT licensed · deploys in your own AWS"
- Terminal window chrome (title bar, prompt symbol) framing the diagram

Composition: 1200x627 landscape; the diagram occupies the right two-thirds, leaving
the LEFT third darker / lower-density for a headline overlay. No marketing copy.
Reads like a real terminal screenshot a security engineer would recognize.
```

The image now answers *what the ad is about* (multi-cloud → Shasta → 8 frameworks, MIT, in-your-AWS) at a glance — not just *who would look at it*.

## How extraction works

When the orchestrator builds the prompt, it scans the offer.title, offer.url, and brief for:

| Signal | Extracted as visual elements |
|---|---|
| Named clouds (AWS, Azure, GCP, Entra, OCI) | Cloud icons / labels as sources or targets |
| Named frameworks (NIST, SOC 2, ISO 27001, HIPAA, GDPR, EU AI Act, OWASP, MITRE ATLAS) | Framework labels in a list / target |
| Numbers (e.g., "8 frameworks", "5,000 IOCs", "60% reduction") | A large single number prominent in the visual |
| License types (MIT, Apache 2, GPL) | Small footer annotation; possibly a license badge |
| Process verbs (scan, monitor, detect, prioritize, crosswalk) | A flow / pipeline shape |
| Tier / pricing words (free, open-source, demo, assessment) | Open/unlocked metaphor or "free" annotation |

If extraction finds fewer than 2 visual elements, the skill falls back to a generic subject hint and surfaces this in `internal_notes` of the staging file so KK can edit the brief or supply elements manually.

## Failure handling

If `gen_image.sh` exits non-zero:
1. Log stderr to `~/.linkedinads/failed-images/<slug>.log`.
2. Staging file writes with §5 in MISSING template (see `ad-template.md`).
3. §7 checklist gets `[ ] Regen or supply image before launching`.

If the generated image clearly doesn't carry the subject (e.g., the model produced a generic stock-photo person despite the elements list), KK regens with `/linkedin-ad regen-image <slug>` and either edits the brief or switches `--image-style`.

NEVER block staging on image failure — text-only is valid.

## Regen subcommand

`/linkedin-ad regen-image <slug> [--image-style <name>]`:
1. Read `<slug>`'s staging file.
2. Extract the existing brief + style.
3. Interactive: "edit subject elements, switch style, or accept?"
4. Re-resolve STYLE per the new flag (if passed) or accept the existing one.
5. Rebuild the prompt with any subject edits.
6. Invoke `gen_image.sh` with the new prompt.
7. Rewrite only §5 + `image_status:` frontmatter.

## Cost note

Nano Banana Pro lands around USD 0.04-0.06 per image. With one image per ad and an occasional regen, a typical week's worth of 3-5 ads costs <USD 0.50.
