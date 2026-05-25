# gh CLI Findings

**Date:** 2026-05-24
**CLI:** `gh` (GitHub CLI)
**Auth:** OAuth as `kkmookhey`, scopes: `gist, read:org, repo, workflow`

## Command to list merged PRs in a date range

**macOS (KK's setup):**
```bash
gh pr list --repo <owner>/<repo> --state merged --limit 100 \
  --search "merged:>=$(date -u -v-7d +%Y-%m-%d)" \
  --json number,title,url,mergedAt,author,body,additions,deletions
```

**Linux (for portability in Cowork/CI later):**
```bash
gh pr list --repo <owner>/<repo> --state merged --limit 100 \
  --search "merged:>=$(date -u -d '7 days ago' +%Y-%m-%d)" \
  --json number,title,url,mergedAt,author,body,additions,deletions
```

The skill's source-github adapter should detect platform with `[[ "$OSTYPE" == darwin* ]]` and pick the right `date` form.

## Return shape

Top-level: JSON array. Per-PR fields (selectable via `--json`):

| Field | Type | Notes |
|---|---|---|
| `number` | int | PR number |
| `title` | string | |
| `url` | string | HTML URL |
| `mergedAt` | string | ISO 8601 with Z suffix |
| `author` | object | `{ id, login, name, is_bot }` — access login via `.author.login` |
| `body` | string | Empty body appears as `""` not `null` |
| `additions` | int | Lines added |
| `deletions` | int | Lines deleted |
| `baseRefName` | string | Base branch (use to filter to default branch if needed) |
| `headRefName` | string | Source branch |
| `labels` | array | `[{name, color, description}]` |

## Sample real output (one PR from kkmookhey/ciso-copilot)

```json
{
  "additions": 37,
  "author": {"id": "MDQ6VXNlcjExODM0Mjk1", "is_bot": false, "login": "kkmookhey", "name": ""},
  "deletions": 12,
  "mergedAt": "2026-05-25T02:08:52Z",
  "number": 22,
  "title": "fix(web): /ai framework-tile drill-down + cleaner empty-state copy",
  "url": "https://github.com/kkmookhey/ciso-copilot/pull/22"
}
```

## Multi-repo behavior

One `gh pr list` invocation per repo. For multiple repos, the skill should run them in parallel:

```bash
# Pattern the source adapter uses
for repo in "${REPOS[@]}"; do
  gh pr list --repo "$repo" ... &
done
wait
```

Or with `xargs -P 4` for explicit parallelism.

## Pagination

- Default `--limit` is 30. We set `--limit 100` to be safe for active repos.
- For repos with >100 merged PRs in the lookback window (unlikely for personal repos), switch to `gh api 'repos/<owner>/<repo>/pulls?state=closed&...' --paginate`.

## Author filtering (for `only_authored_by_me`)

```bash
gh pr list --repo <owner>/<repo> --state merged --author "@me" ...
```

The `@me` shorthand resolves to the authenticated user. Use this when `config.sources.github.only_authored_by_me: true`.

## Quirks

- `--search "merged:>=DATE"` uses GitHub Issues search syntax internally
- Empty `body` field appears as empty string, not null — `.body | select(length > 0)` if filtering
- `mergedAt` is always ISO 8601 with Z (UTC)
- `gh pr list` doesn't return the PR's full diff — only stats (additions/deletions). If the source adapter needs diff content for richer summaries in a later slice, use `gh pr diff <number> --repo <owner>/<repo>` separately

## KK's available repos (from `gh repo list kkmookhey --limit 5`)

| Repo | Visibility | Updated |
|---|---|---|
| StoryTeller | private | 2026-05-25 |
| ciso-copilot | public | 2026-05-25 |
| concourse | private | 2026-05-17 |
| basecamp-ai-sec | public | 2026-05-21 |
| communitytools | public | 2026-05-21 |

`ciso-copilot` has 5+ recent merged PRs and is the best candidate for the Task 4 fixture.

## Implications for the storyteller skill

1. The `references/source-github.md` prompt should instruct Claude to: (a) detect OS for date syntax, (b) run one `gh pr list` per configured repo in parallel via background processes, (c) merge results into Signal[].
2. The Signal `id` format becomes `github:<owner>/<repo>:pr#<number>` per the spec.
3. `author` is an object in `gh` output but the Signal schema expects a string — adapter unwraps `.author.login`.
4. Empty body strings should be treated as missing in the summary-generation step (the prompt already accounts for this).
