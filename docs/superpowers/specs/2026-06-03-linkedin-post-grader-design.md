# Spec: `linkedin-post-grader` skill

**Status:** Design, awaiting implementation.
**Owner:** KK + team at Transilience AI.
**Goal:** Ship a public-facing `/grade-post <url|text|file>` command that scores any LinkedIn post against the Jennifer pre-publish filter (0-10) and returns a rewrite that would score 7+. Output is optimized to be screenshot-shareable — that's the viral lever.

## Why this exists

Discussed 2026-06-03. The strongest viral entry-point for the StoryTeller toolkit isn't a new feature inside the existing skills — it's a **standalone grader command** that works on any LinkedIn post (yours, a competitor's, a viral thread) and returns a screenshot-worthy verdict + concrete rewrite. Every use is a sharable artifact. Lowest setup friction of any feature in the toolkit.

Validated 2026-06-03: WebFetch successfully read a real LinkedIn `ugcPost` URL (Todyl CMMC post) — full body extracted from OG metadata, author name + reaction count surfaced, no login wall. v1 ships with WebFetch only; Apify fallback deferred to v2 if traffic justifies it.

## Non-goals (v1)

- **No Apify integration.** WebFetch only. Long posts that get OG-truncated, private posts, or posts behind LinkedIn's rate-limit will politely fail — user is told to paste the body directly. v2 adds Apify MCP fallback if usage warrants.
- **No audience-detection.** The Jennifer filter is the bar. If a user wants to grade against a different audience, they fork `kk-voice` (already documented as the customization step). Detecting audience is a v2+ topic.
- **No file persistence by default.** The grade is a one-shot conversational output. Optional `--save` flag writes to `~/.linkedinads/graded/<YYYY-MM-DD>-<slug>.md` for users who want to archive a "wall of graded posts."
- **No multi-language support.** English posts only for v1. Rubric criteria are language-agnostic in principle, but the rewrite generation depends on kk-voice which is English-only.
- **No image / video / carousel post support.** Plain text posts (the LinkedIn long-post format) only. Other formats fail with a clear message.

## Architecture

New skill at `skill/linkedin-post-grader/`, symlinked from `~/.claude/skills/linkedin-post-grader/` via the existing install.sh pattern.

```
LinkedIn URL  ─┐
Pasted text   ─┼─→ resolve input ─→ load kk-voice + scoring rubric ─→ score (5 criteria, 0-2 each)
File path     ─┘                                                         │
                                                                         ▼
                                                                identify lead failure
                                                                         │
                                                                         ▼
                                                                draft rewrite (kk-voice)
                                                                         │
                                                                         ▼
                                                                render screenshot-shareable markdown
                                                                         │
                                                                         ▼
                                                                stdout (+ optional --save to graded/)
```

## Workflow

1. **Parse trigger.** `/grade-post <url|text|file>`:
   - If input starts with `http://` or `https://` AND host is `linkedin.com` or `www.linkedin.com`: treat as URL.
   - Else if input is a readable file path: treat as file → read.
   - Else: treat as pasted text body.
2. **Resolve body.**
   - URL path: WebFetch with extraction prompt → "extract the post body verbatim from OG metadata or page HTML, plus author name + visible reaction/comment counts. If the page requires authentication or returns a login wall, say so explicitly."
   - File / text path: skip fetch.
   - On WebFetch failure (login wall, 404, non-post URL, truncation < 100 chars of body): return error envelope per `Failure modes` table. Do NOT proceed to scoring.
3. **Load voice + rubric.** Mandatory: load `kk-voice` (audience filter + voice DNA) AND `~/.claude/skills/storyteller/references/scoring-rubric.md` (the 5-criterion rubric). These are the single sources of truth — do not re-invent.
4. **Score.** Apply the rubric exactly as storyteller does:
   - Hard-zero check first (excited-to-announce material with no substance, pure announcement, region-only content with no universal lesson, etc.). If hard-zero fires: score = 0, skip rubric, note which rule fired.
   - Else score each of 5 criteria 0/1/2, sum, cap at 10.
   - Criterion 5 (problem-before-product) defaults to 2 if Transilience-style branded product is not mentioned (which most graded posts won't have).
5. **Identify lead failure.** The single biggest reason the post didn't score higher. Pick:
   - If hard-zero fired: name the hard-zero rule.
   - Else: pick the LOWEST-scoring criterion (ties broken by criterion 3 receipts > 4 voice > 5 placement > 2 borrowable > 1 substance — the order roughly tracks "what Jennifer notices first").
   - Phrase the lead failure as a single sentence describing what's missing, NOT as a generic criterion name. Example: "Receipts are deferred to a gated eBook instead of delivered in the post itself" — not "Failed criterion 3."
6. **Draft rewrite.** Produce a rewrite that:
   - Preserves the post's topic + any verifiable facts (don't invent numbers).
   - Addresses the lead failure first (the rewrite's lead line should fix the hook).
   - Hits at least 7/10 on the same rubric (self-checked).
   - 150-280 words, matching the LinkedIn drafting contract storyteller already uses.
   - Voice: kk-voice DNA. Banned phrases checked.
   - Marked clearly as `## Rewrite that scores 7+` so the screenshot reads as a constructive offer, not a takedown.
7. **Render output.** Standard format (see Output contract below). Print to stdout. If `--save` flag: also write to `~/.linkedinads/graded/<YYYY-MM-DD>-<slug>.md`.

## Input contract

| Input type | Trigger | Parsing |
|---|---|---|
| LinkedIn URL | starts with `http(s)://(www.)?linkedin.com/` | WebFetch with extraction prompt |
| Pasted text | input has > 100 chars and is not a URL or file path | Treat as post body verbatim |
| File path | input is an existing readable file | Read file content, treat as body |
| (no input) | bare `/grade-post` | Prompt KK: "paste a LinkedIn URL or post body" |

URL validation:
- Must contain a post identifier (`ugcPost`, `activity`, or `share`) in the path. Otherwise reject with "this looks like a LinkedIn profile/article/page, not a post URL."
- Strip tracking params (`utm_*`, `rcm`) before WebFetch — they're noise.

## Scoring contract

Reuses `~/.claude/skills/storyteller/references/scoring-rubric.md` verbatim — DO NOT duplicate the rubric in this skill's references. If the rubric changes (e.g. storyteller adds a 6th criterion), this skill picks it up automatically.

The only adaptation for the grader use-case: criterion 5 (problem-before-product) defaults to **2 if no Transilience-style branded product appears in the post**. For ungated posts from random LinkedIn users, this is the common case.

## Output contract — screenshot-shareable format

The output is rendered as a single markdown block, optimized to be screenshot-pasted into a Twitter post or a Slack DM. Structure:

```markdown
## Grade: <N> / 10 — "<one-line verdict, ≤8 words>"

| # | Criterion | Score | Why |
|---|---|---|---|
| 1 | Specific operational substance | <0|1|2> / 2 | <one short sentence> |
| 2 | Borrowable insight | <0|1|2> / 2 | <one short sentence> |
| 3 | Receipts vs generalities | <0|1|2> / 2 | <one short sentence> |
| 4 | Operator voice | <0|1|2> / 2 | <one short sentence> |
| 5 | Problem-before-product | <0|1|2> / 2 | <one short sentence; "N/A" if no product mentioned> |

**Lead failure:** <one-sentence diagnosis of the single biggest reason the post didn't score higher>

## Rewrite that scores 7+

> <150-280 word rewrite in kk-voice, addressing the lead failure, preserving the topic, hitting the rubric>

---

_Graded by [linkedin-post-grader](https://github.com/transilienceai/StoryTeller) — open-source LinkedIn post auditor from the team at [Transilience AI](https://www.transilience.ai)._
```

The footer attribution is the viral hook — every screenshot carries the project URL + the Transilience team brand.

Output formatting rules:
- The "verdict" header phrase is the part people screenshot and quote. Examples: "Vendor pitch with a deadline glued to it" / "Founder journey post; no operator voice." Make it punchy, not generic.
- The rewrite block uses a `>` quote prefix so it visually stands apart in any markdown renderer.
- The footer link uses the `transilienceai/StoryTeller` URL as the canonical repo (matches the README convention as of 2026-06-03).

## Failure modes

| Symptom | Cause | Behavior |
|---|---|---|
| WebFetch returns < 100 chars of body | LinkedIn truncated OG, or login wall, or non-post URL | Output error envelope: "Couldn't read this post from the URL alone. Paste the body directly via `/grade-post '<paste body here>'`." Do NOT score on truncated content. |
| URL is LinkedIn but not a post (profile/article/page) | `ugcPost`/`activity`/`share` not in path | Reject: "This looks like a LinkedIn profile/article/page URL. /grade-post needs a post URL — try one ending in `…-ugcPost-<id>` or `…-activity-<id>`." |
| URL is not LinkedIn at all | Other domain | Reject: "/grade-post is for LinkedIn posts. If you want to grade arbitrary text, paste it directly." |
| Hard-zero scoring rule fires | Pure announcement, India/ME-only regional, "excited to announce" with no substance, etc. | Score = 0. Name the hard-zero rule in the lead failure line. Skip the rewrite section (a hard-zero post often shouldn't exist — KK can override with `--rewrite-anyway`). |
| Post body contains non-Latin script (Devanagari, CJK, Arabic) > 50% | Non-English content | Score with caveats noted. Skip the rewrite. Output footer: "Rewrite skipped — kk-voice is tuned for English content. Rewrite manually using the diagnosis above." |
| kk-voice skill not installed | User cloned the grader without the full StoryTeller toolkit | Output error: "linkedin-post-grader requires the kk-voice skill. Install the full toolkit: https://github.com/transilienceai/StoryTeller" |
| `--save` flag set but `~/.linkedinads/` doesn't exist | Standalone grader install without linkedin-ads | Create the dir lazily (skill owns its own bootstrap). |

All errors render in a tone consistent with the share-worthy moment — never internal-exception-style. Bad-error example: `Error: WebFetch returned 0 bytes`. Good-error example: `Couldn't read this post — LinkedIn returned a login wall. Paste the body directly?`

## Scope (v1)

In scope:
- ✅ `/grade-post <url|text|file>` trigger
- ✅ WebFetch primary, no Apify fallback
- ✅ Jennifer filter (kk-voice) as the audience bar
- ✅ Storyteller scoring rubric (reused verbatim)
- ✅ Screenshot-shareable markdown output with Transilience footer attribution
- ✅ `--save` flag for archival to `~/.linkedinads/graded/`
- ✅ Hard-zero detection
- ✅ Polite failure messages for login walls / non-post URLs / non-LinkedIn URLs
- ✅ Rewrite generation in kk-voice

Out of scope (Phase 2+):
- ❌ Apify MCP fallback (revisit when viral usage justifies it)
- ❌ Audience detection / pluggable voice files at runtime (user forks kk-voice for now)
- ❌ Multi-language support
- ❌ Image / video / carousel post grading
- ❌ Bulk grading of multiple URLs in one call
- ❌ Diff view between original post and rewrite
- ❌ Grading + tracking over time ("show me my last 10 graded posts")
- ❌ Browser extension form factor

## Prerequisites

- `kk-voice` skill installed at `~/.claude/skills/kk-voice/` (the audience + voice DNA). The grader's value entirely depends on this file; without it, output is generic.
- `storyteller` skill installed at `~/.claude/skills/storyteller/` (for the scoring rubric reference). The grader does NOT need any storyteller subcommands — only the rubric file. Long-term option: extract the rubric into a shared `references/` dir, but for v1 just cross-reference the existing path.
- WebFetch tool available in the Claude Code environment.

## File layout

New skill at `skill/linkedin-post-grader/`:

```
skill/linkedin-post-grader/
├── SKILL.md                       (thin workflow orchestrator)
└── references/
    ├── input-resolution.md        (URL / text / file parsing + WebFetch extraction prompt)
    ├── scoring.md                 (cross-ref to storyteller/references/scoring-rubric.md + the lead-failure picker)
    ├── rewrite-rules.md           (constraints on the rewrite: preserve facts, address lead failure, hit 7+)
    └── output-format.md           (the screenshot-shareable markdown template + footer attribution)
```

`scripts/install.sh` adds `linkedin-post-grader` to `SKILLS_TO_INSTALL`.

No `sample-config.yaml` — the grader has no user-tunable config in v1. Voice tuning happens via the existing kk-voice fork pattern.

## Viral mechanics — what the spec explicitly optimizes for

1. **Zero-setup first run.** The grader works on `/grade-post <any-linkedin-url>` immediately after install. No config, no audience picks, no offer setup.
2. **Screenshot moment.** The output format is markdown so it renders cleanly in chat (Slack / Twitter / iMessage / Bluesky) and on GitHub. The verdict phrase is the quoteable headline.
3. **Footer attribution.** Every output carries the repo URL + Transilience team link. Every screenshot is a backlink.
4. **Works on competitors.** No "must be your own post" constraint. People will run it on the cringe LinkedIn posts of their CEO / their competitor / a viral thread — that's the share-worthy moment.
5. **Constructive, not snarky.** The rewrite section converts the grade from "you got dunked on" to "here's a better version" — share-worthiness across the spectrum of senders, not just the grader-as-flame-thrower.

## Open questions for KK

- **Footer attribution wording** — drafted as "Graded by [linkedin-post-grader](repo) — open-source LinkedIn post auditor from the team at [Transilience AI](https://www.transilience.ai)." Confirm or rephrase.
- **`--rewrite-anyway` flag for hard-zero posts** — included as an escape hatch. Want me to ship it in v1, or hold for v2?
- **Save flag default** — currently `false` (don't persist). Want it `true` so grades archive by default and the user can browse `~/.linkedinads/graded/`?
- **Naming** — `linkedin-post-grader` vs `grade-post` vs `post-grader`. The command will be `/grade-post`; the skill folder name can differ. Confirm.

## Build sequence (after spec approval)

1. Scaffold `skill/linkedin-post-grader/` with SKILL.md + 4 reference files.
2. Update `scripts/install.sh` to include the new skill.
3. Symlink into `~/.claude/skills/`.
4. Sanity-test on 3 real LinkedIn URLs (one short post, one long post, one private post that should fail gracefully).
5. Add a section to the README pointing at `/grade-post` as the lowest-friction entry-point.
6. Commit + push to both remotes.
