# Reference: output format (screenshot-shareable)

The final markdown block printed to stdout at step 7 of the workflow. Optimized for screenshots in chat (Slack / Twitter / iMessage / Bluesky) and on GitHub.

## Standard template

```markdown
## Grade: <N> / 10 — "<verdict_phrase, ≤8 words>"

| # | Criterion | Score | Why |
|---|---|---|---|
| 1 | Specific operational substance | <s> / 2 | <one short sentence> |
| 2 | Borrowable insight | <s> / 2 | <one short sentence> |
| 3 | Receipts vs generalities | <s> / 2 | <one short sentence> |
| 4 | Operator voice | <s> / 2 | <one short sentence> |
| 5 | Problem-before-product | <s> / 2 | <one short sentence; "N/A — no product mentioned" if applicable> |

**Lead failure:** <one-sentence diagnosis from `scoring.md > Lead failure picker`>

## Rewrite that scores 7+

> <150-280 word rewrite per `rewrite-rules.md`. Each paragraph wrapped in a `>` blockquote prefix so the block visually stands apart in any markdown renderer.>

---

_Graded by [linkedin-post-grader](https://github.com/transilienceai/StoryTeller) — open-source LinkedIn post auditor from the team at [Transilience AI](https://www.transilience.ai)._
```

## Variants

### Hard-zero output (default — no rewrite)

```markdown
## Grade: 0 / 10 — "<verdict_phrase>"

**Hard-zero rule fired:** <rule name>

**Why:** <one-sentence explanation of why the hard-zero rule applies to this specific post>

_The rewrite is skipped because this post's premise doesn't survive editing. To see a rewrite anyway, re-run with `--rewrite-anyway`._

---

_Graded by [linkedin-post-grader](https://github.com/transilienceai/StoryTeller) — open-source LinkedIn post auditor from the team at [Transilience AI](https://www.transilience.ai)._
```

### Solid-post output (score >= 7, no rewrite needed)

```markdown
## Grade: <N> / 10 — "<verdict_phrase>"

| # | Criterion | Score | Why |
|---|---|---|---|
| ... full table ... |

## This post is solid — what's working

- <one bullet per criterion that scored 2/2 explaining why it works>

**Meta:** <one-line observation about what most operators would learn from studying this post>

---

_Graded by [linkedin-post-grader](https://github.com/transilienceai/StoryTeller) — open-source LinkedIn post auditor from the team at [Transilience AI](https://www.transilience.ai)._
```

### Hard-zero with `--rewrite-anyway`

Use the standard template, but prepend the rewrite block with this caveat (per `rewrite-rules.md`):

```markdown
> _Note: original triggered a hard-zero rule (<rule name>). This rewrite is an exercise in_
> _what the post COULD have been — not an endorsement of the underlying angle._
```

Then the rewrite text continues.

### `--no-rewrite` output

Standard template, but omit the entire `## Rewrite that scores 7+` section. Footer attribution stays. The output is grade + lead failure + footer, period.

### Non-English content

```markdown
## Grade: <N> / 10 — "<verdict_phrase>"

| # | Criterion | Score | Why |
|---|---|---|---|
| ... full table ... |

**Lead failure:** <one-sentence diagnosis>

_Rewrite skipped — kk-voice is tuned for English content. Use the diagnosis above to revise manually._

---

_Graded by [linkedin-post-grader](https://github.com/transilienceai/StoryTeller) — open-source LinkedIn post auditor from the team at [Transilience AI](https://www.transilience.ai)._
```

## Formatting rules

1. **Table alignment** — markdown table with `|---|` separators. Each cell is single-line; the "Why" cells must NOT contain line breaks (they'd break the screenshot's clean rendering).

2. **Verdict phrase quoting** — wrap the verdict phrase in straight double quotes in the H2 header. The phrase itself contains NO quote characters (to avoid escape issues in shell-quoted commands).

3. **Lead failure phrasing** — single sentence, no list, no markdown formatting inside it. The lead-failure bold prefix (`**Lead failure:**`) is the only emphasis.

4. **Rewrite block** — every paragraph wrapped in `> ` prefix. Empty quoted lines (`>`) between paragraphs preserve paragraph breaks inside the blockquote. Do NOT use triple-quote fences (`>>>`) — those don't render universally.

5. **Footer attribution** — italic via `_..._`. The skill name and Transilience AI are both hyperlinked. The footer is one paragraph, never two.

6. **Horizontal rule** — `---` separates the rewrite from the footer. ONE rule, not multiple.

7. **No emojis** — the grader doesn't use emojis. Jennifer doesn't like them, and screenshots without emoji noise are crisper.

## Slug derivation (for `--save`)

When `--save` is set, the rendered block is also written to `~/.linkedinads/graded/<YYYY-MM-DD>-<slug>.md`. Derive the slug:

1. If URL input: take the last path segment, strip extensions, lowercase, replace non-alphanumeric with `-`. Truncate at 60 chars.
2. If text/file input: take the first 60 chars of the post body, lowercase, replace non-alphanumeric with `-`, collapse consecutive `-`, strip leading/trailing `-`.
3. On collision (file exists for same date+slug): append `-2`, `-3`, ...

Example:
- URL: `linkedin.com/posts/is-your-msp-ready-for-cmmc-enforcement-ugcPost-7384334578162941953-CwPC` → slug: `is-your-msp-ready-for-cmmc-enforcement-ugcpost-7384334578162941953-cwpc` (truncated to 60: `is-your-msp-ready-for-cmmc-enforcement-ugcpost-7384334578162`)
- Text body starting with "The DoD will require CMMC...": slug: `the-dod-will-require-cmmc-in-all-defense-contracts-by-octobe`

The saved file content is the exact stdout output — no frontmatter, no extra metadata. The footer attribution serves as both signature and provenance.

## Why optimize for screenshot

The grader output is meant to be screenshot-pasted into chat. Every formatting choice serves that. The table renders clean at thumbnail-screenshot zoom; the rewrite blockquote visually separates it from the diagnostic; the footer carries the project URL on every share. The grader's distribution mechanism IS the output format.
