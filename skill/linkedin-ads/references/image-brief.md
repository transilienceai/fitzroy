# Reference: Image brief construction + Gemini invocation

How the skill turns the picked objective + audience + offer + brief into a Gemini prompt at step 7 of the workflow.

**Reuses:** `~/.claude/skills/storyteller/scripts/gen_image.sh` — no new script. The Quiet-Paper aesthetic block is baked into the helper.

## When to call

Step 7 of the SKILL.md workflow — after variants draft, before the review loop. ONE image per ad, shared across all 3 variants.

## File naming

```
~/.linkedinads/images/<slug>.png
```

Gemini may return JPEG even when the caller writes `.png`. `gen_image.sh` detects via magic bytes and renames to `.jpg` if needed. Track whichever path the helper echoes.

If the file already exists for this slug, the skill prompts: "image exists — reuse, regen, or skip?" Default: reuse.

## Prompt template

```
A single visual metaphor for a LinkedIn ad targeting <audience.description>.
Offer angle: <offer.title>.
KK's brief: <topic-first brief OR "amplify post: <original hook>">.
Mood: confident operator-first. No panic, no sensationalism.
Composition: 1200x627 landscape, generous negative space for LinkedIn's overlay safe zones.
Quiet-Paper aesthetic. No text on image (or at most 3 words of large editorial type).
No logos, no brand marks.
```

## Worked example

Inputs:
- Audience: `us-mid-market-ciso` (description: "Jennifer-shaped: Deputy CISO / CISO at US mid-market enterprises")
- Offer: `free-ai-readiness-assessment` (title: "Free AI Security Readiness Assessment")
- KK's brief: "promote the free CISO AI-readiness assessment"

Constructed prompt:
```
A single visual metaphor for a LinkedIn ad targeting Deputy CISO / CISO at US mid-market enterprises.
Offer angle: Free AI Security Readiness Assessment.
KK's brief: promote the free CISO AI-readiness assessment.
Mood: calm authority. A figure or object that suggests a clear scorecard, an honest mirror, a readiness check — not panicked, not selling.
Composition: 1200x627 landscape, generous negative space.
Quiet-Paper aesthetic. No text on image.
No logos, no brand marks.
```

The skill MAY elaborate the `Mood:` line based on the offer category — assessment offers get "calm authority", whitepaper offers get "considered analysis", demo offers get "ready hands". These elaborations are heuristic; KK can override via `regen-image`.

## Invocation

```bash
bash ~/.claude/skills/storyteller/scripts/gen_image.sh \
  "<the constructed prompt>" \
  "$HOME/.linkedinads/images/<slug>.png"
```

Stdout on success: the absolute path of the written image file (may be `.png` or `.jpg`).
Non-zero exit + stderr message on failure.

## Aspect ratio (v1 — prompt-only)

`gen_image.sh` defaults to 1080×1080. For LinkedIn we need 1200×627. v1 ships with the aspect-ratio hint in the prompt only (`"Composition: 1200x627 landscape"`) — current Gemini Nano Banana Pro honors this reasonably well.

If drift becomes a real problem (KK runs more than 2-3 regen-image cycles on consecutive ads), upgrade to passing an `--aspect` flag to `gen_image.sh`. That's a cross-cutting change to the StoryTeller script and is out of v1 scope.

## Error handling

If `gen_image.sh` exits non-zero:
1. Log stderr to `~/.linkedinads/failed-images/<slug>.log`.
2. Staging file still writes. The `## 5. Image` section uses the MISSING template (see `ad-template.md` §5).
3. Pre-launch checklist (§7 of staging file) gets the auto-added item: `[ ] Regen or supply image before launching`.

NEVER block staging on image failure — text-only is a valid staging output. The ad can still be reviewed and the image regenerated later via `/linkedin-ad regen-image <slug>`.

## Regen subcommand

`/linkedin-ad regen-image <slug>`:
1. Read `<slug>`'s staging file.
2. Extract the existing image brief from §5.
3. Interactive prompt: "edit brief or accept as-is?" — KK either supplies a new brief or hits enter.
4. Invoke `gen_image.sh` with the (possibly edited) brief.
5. Rewrite ONLY the `## 5. Image` section + the frontmatter `image_status:` field. Leave everything else untouched.

Useful when the first-pass image doesn't fit, or when KK wants to try a different visual metaphor without redoing the whole ad.

## Cost note

Nano Banana Pro lands around USD 0.04-0.06 per 1080×1080 (or 1200×627) image. With one image per ad and an occasional regen, a typical week's worth of 3-5 ads costs <USD 0.50.
