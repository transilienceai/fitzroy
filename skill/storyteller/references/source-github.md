# Source: GitHub

Normalize raw GitHub PR data (from `gh` CLI) into the StoryTeller Signal shape.

## How to call

For each repo in `config.sources.github.repos`, query the `gh` CLI for merged PRs within `config.sources.github.lookback_days`.

**macOS:**
```bash
gh pr list --repo <owner>/<repo> --state merged --limit 100 \
  --search "merged:>=$(date -u -v-<N>d +%Y-%m-%d)" \
  --json number,title,url,mergedAt,author,body,additions,deletions
```

**Linux:**
```bash
gh pr list --repo <owner>/<repo> --state merged --limit 100 \
  --search "merged:>=$(date -u -d '<N> days ago' +%Y-%m-%d)" \
  --json number,title,url,mergedAt,author,body,additions,deletions
```

If `only_authored_by_me: true` in config, add `--author "@me"`.

Run repo queries in parallel (background processes + wait, OR `xargs -P`) and concatenate results.

## Per-PR transformation

For each raw PR object, produce a Signal with these keys:

```json
{
  "source": "github",
  "id": "github:<owner>/<repo>:pr#<number>",
  "url": "<pr.url>",
  "title": "<pr.title>",
  "summary": "<2-4 sentence synthesis of title + body — what the PR actually did and why it matters. NOT a verbatim copy of the PR body.>",
  "timestamp": "<pr.mergedAt>",
  "author": "<pr.author.login>",
  "raw": {
    "number": <pr.number>,
    "additions": <pr.additions>,
    "deletions": <pr.deletions>,
    "body_excerpt": "<first 500 chars of pr.body>"
  }
}
```

Notes:
- `author` in the gh output is an object — extract `.author.login` as a string.
- `id` is derived from the `pr.url` (the canonical `https://github.com/<owner>/<repo>/pull/<number>` form) or by combining the repo passed to `gh pr list` with `pr.number`. Always lowercase the owner/repo segment exactly as it appears in the URL.
- `body_excerpt` is the literal first 500 characters of `pr.body` (no trimming, no rewriting). If `pr.body` is empty, use `""`.

## Summary writing rules

The `summary` is for the scorer to judge post-worthiness. It MUST follow ALL of these rules:

1. **2-4 sentences.** Prose. No bullets, no headings, no markdown.
2. **Synthesize, do not copy.** The summary must be a fresh paraphrase. It must NOT be a substring of the PR body and must NOT contain any sentence verbatim from the body. If you find yourself copying a phrase longer than ~10 consecutive words from the body, rewrite it.
3. **The summary text MUST be different from `body_excerpt`.** This is a hard invariant — the validator checks `summary != body_excerpt`. Never set them equal.
4. **Describe what shipped and why it might matter.** Capture user-facing impact, technical decision, or risk surfaced. Don't just restate the title.
5. **Don't restate the title verbatim** — assume the reader already has it.
6. **Empty/trivial body:** If `pr.body` is empty or under ~50 characters, derive the summary from the title + diff stats (`additions`/`deletions`) only, and include the phrase `minimal description provided` somewhere in the summary.

### Example (do)

Title: `fix(web): /ai framework-tile drill-down + cleaner empty-state copy`
Body: long markdown with `## Summary` headings, test plan checklists, etc.

Good summary:
> Reworks the framework tiles on the /ai page so the primary label drills into the filtered findings view while the source-doc link demotes to a small icon, keeping the disclaimer tooltip intact. Also trims the AI-users empty-state copy now that the /connect banner covers the Entra ID guidance. Tightens UX on a high-traffic page without changing data flow.

### Example (don't)

Bad summary (verbatim copy of body):
> ## Summary
> Two BACKLOG §E follow-ups + D-1 closeout doc.

## Output

Return a strict JSON array of Signals — no prose around it, no markdown fence, no commentary. The first character of the output must be `[` and the last `]`.
