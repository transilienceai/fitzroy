---
name: linkedin-post-grader
description: Use when KK or anyone wants to grade a LinkedIn post (their own, a competitor's, a viral thread) against the Jennifer pre-publish filter and get a screenshot-shareable verdict + rewrite. Triggers on /grade-post, "grade this LinkedIn post", "score this post", "is this LinkedIn post good", "would Jennifer like this post", "audit this LinkedIn post", "rewrite this LinkedIn post in KK's voice", or any request to evaluate / score / critique / improve an existing LinkedIn post. Does NOT fire for drafting new posts from scratch (use kk-voice for that) or for surfacing post ideas from signals (use storyteller for that).
---

# LinkedIn Post Grader — URL or text → 0-10 score + lead failure + rewrite

Orchestrate the pipeline. Detail lives in `references/`.

Output is a single markdown block printed to stdout, optimized to be screenshot-shareable. The grader is conversational by default; the optional `--save` flag persists to disk.

## Workflow

1. **Parse trigger.** `/grade-post <url|text|file>`. If input is missing or empty: prompt "paste a LinkedIn URL or post body."
2. **Resolve input** per `references/input-resolution.md`:
   - URL → strip tracking params (`utm_*`, `rcm`), validate it's a LinkedIn POST URL (contains `ugcPost` / `activity` / `share` in the path), WebFetch to extract author + body + reaction count from OG metadata + page HTML.
   - File path → read file, treat as body.
   - Pasted text (> 100 chars, no URL/path markers) → treat as body verbatim.
   - On WebFetch failure (login wall, truncation < 100 chars, non-LinkedIn URL): render the polite failure envelope per `references/input-resolution.md > Failure modes`. Do NOT proceed.
3. **Load voice + rubric.** Mandatory: `kk-voice` (Jennifer filter + voice DNA) AND read `~/.claude/skills/storyteller/references/scoring-rubric.md` (the 5-criterion rubric). Do not re-invent.
4. **Score** per `references/scoring.md`:
   - Hard-zero check first. If any hard-zero rule fires: score = 0, note which rule, skip the rubric.
   - Else score each of 5 criteria 0/1/2, sum, cap at 10.
   - Criterion 5 (problem-before-product) defaults to 2 if no Transilience-style branded product appears in the post.
5. **Identify lead failure** per `references/scoring.md > Lead failure picker`. The single biggest reason the post didn't score higher, phrased as one diagnostic sentence (NOT "Failed criterion 3").
6. **Draft rewrite** per `references/rewrite-rules.md`:
   - Preserve the post's topic + verifiable facts (don't invent numbers).
   - Address the lead failure first.
   - Hit 7+ on the same rubric.
   - 150-280 words, kk-voice DNA, banned-phrases check.
   - SKIP this step if hard-zero fired UNLESS `--rewrite-anyway` flag is set.
   - SKIP this step if post body is >50% non-Latin script (non-English).
7. **Render output** per `references/output-format.md`. Print the markdown block to stdout.
8. **Optional save.** If `--save`: also write the same block to `~/.linkedinads/graded/<YYYY-MM-DD>-<slug>.md` (slug derived from first 60 chars of the post body or the URL's last path segment).

## Flags

- **`--save`** — also persist the rendered grade to `~/.linkedinads/graded/<YYYY-MM-DD>-<slug>.md`. Default: false (conversational, ephemeral).
- **`--rewrite-anyway`** — force the rewrite section even if a hard-zero rule fired. Useful for "let me see what the better version would look like even though this post shouldn't exist."
- **`--no-rewrite`** — skip the rewrite section entirely (grade-only output). Useful when KK wants to share the diagnosis without offering a free rewrite.

## Failure-mode anti-patterns

- Do NOT score on truncated content. If WebFetch returns < 100 chars of body OR the body looks like a "see more on LinkedIn" stub, fail politely instead of grading the stub.
- Do NOT invent receipts in the rewrite. Numbers, named tools, and named frameworks in the rewrite MUST come from the original post or be marked as `[placeholder — verify before posting]`.
- Do NOT render internal-exception-style errors. All failure messages must be share-worthy: written for the human reader who tried to grade a post and hit a wall, not for a developer looking at a stack trace.
- Do NOT cross-platform — grader is LinkedIn-only in v1. Reject Twitter / Bluesky / Mastodon URLs with a clear message.
- Do NOT cache grades across runs. Every invocation re-fetches + re-scores. (Optional `--save` writes to disk but does NOT short-circuit subsequent runs.)
- Do NOT score posts in non-English content (>50% non-Latin script). The rubric is language-agnostic in principle but kk-voice is English-only — output a grade with caveats, skip the rewrite.

## Prerequisites

- `kk-voice` skill installed at `~/.claude/skills/kk-voice/` — the audience filter + voice DNA. Without it the grade is generic and the rewrite is unusable.
- `storyteller` skill installed at `~/.claude/skills/storyteller/` — for `references/scoring-rubric.md`. The grader does NOT need any storyteller subcommands; it just reads that one reference file.
- `WebFetch` tool available in the Claude Code environment.

## Scope (v1)

- **Input:** LinkedIn post URL OR pasted text OR file path. English content only.
- **Source:** WebFetch only (no Apify fallback yet).
- **Audience:** Jennifer filter (kk-voice). User forks kk-voice to change.
- **Output:** screenshot-shareable markdown block. Optional `--save` to disk.

## Phase 2 (deferred)

- **Apify MCP fallback** — when WebFetch hits LinkedIn's anti-bot / login wall, fall back to `apify/linkedin-post-scraper` via Apify MCP. Ship when usage shows fetch-failure rates above ~15%.
- **Audience detection** — automatically pick the right voice file based on the post's apparent target audience. Currently the user forks kk-voice for this.
- **Bulk grading** — `/grade-post --batch <url-list-file>` for grading multiple posts in one run, producing a summary table.
- **Diff view** — side-by-side original vs rewrite rendering.
- **Image / video / carousel post grading** — extract text from images via OCR + grade the combined content.
- **Multi-language support** — requires non-English voice files.

## Viral mechanic (what this skill optimizes for)

Every output is share-worthy. The verdict header is the quoteable headline; the rewrite block is the constructive offer; the footer attribution carries the repo URL + Transilience team brand on every screenshot. Zero-setup first run — `/grade-post <any-linkedin-url>` works immediately after install. Works on competitors' posts, not just your own.
