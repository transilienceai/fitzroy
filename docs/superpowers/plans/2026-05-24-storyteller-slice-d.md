# StoryTeller Slice D Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `storyteller` Claude Code skill end-to-end for Slice D — GitHub PRs → Jennifer-rubric scoring → multi-format drafts (LinkedIn + X to Postiz, Instagram caption + Reels script held locally) → Slack notification — with state-based dedupe and dry-run support.

**Architecture:** A Claude Code skill (markdown + reference prompt templates) developed in this repo at `skill/storyteller/`, symlinked into `~/.claude/skills/storyteller/` for use. Orchestrates GitHub MCP, Postiz MCP, and Slack MCP. Delegates voice to existing `kk-voice` and `kk-short-form` skill bundles. User config and state in `~/.storyteller/`.

**Tech Stack:** Markdown (skill content), YAML (config), JSONL (state), shell (install/test runner scripts), MCPs (GitHub, Postiz, Slack), Claude Code skill system.

**Spec reference:** `docs/superpowers/specs/2026-05-24-storyteller-slice-d-design.md`

**TDD note for this plan:** Skills don't have traditional unit tests. The TDD analog (per `superpowers:writing-skills`) is RED-GREEN-REFACTOR with pressure scenarios and fixture-based prompt validation. Each task that produces a prompt template includes a fixture-based test step; the orchestration tasks include subagent-based scenario tests.

---

## Phase 1 — Verification & Setup (de-risk first)

### Task 1: Verify Postiz MCP draft semantics

**Files:**
- Create: `docs/superpowers/notes/postiz-mcp-findings.md`

The spec flagged this as the #1 risk. We need to know exactly which Postiz MCP tool to call and whether "draft" is a flag, a status enum, or requires a far-future scheduled date workaround. Do this BEFORE writing the publisher prompt.

- [ ] **Step 1: Confirm Postiz MCP is connected**

Run in Claude Code:
```
List all MCP tools whose name contains "postiz" or starts with "mcp__postiz".
```
Expected: 8 tools listed: `integrationList`, `integrationSchema`, `triggerTool`, `schedulePostTool`, `generateImageTool`, `generateVideoOptions`, `videoFunctionTool`, `generateVideoTool`.
If 0 tools: Postiz MCP not installed; stop and install before continuing.

- [ ] **Step 2: Read the schedulePostTool schema**

Run in Claude Code:
```
Show me the full JSON schema for the Postiz MCP tool that creates posts (likely schedulePostTool). I need to know:
- Required vs optional fields
- Whether there is a draft/status/state field
- How to specify a post that should NOT publish immediately
- Whether scheduling far-future creates a "draft" or a "scheduled" post
```

- [ ] **Step 3: Test create-as-draft with a throwaway post**

In Claude Code, use the Postiz MCP to create one test post containing the text `"StoryTeller MCP test — please delete"` such that it does NOT publish. Try the most-natural draft mechanism first (explicit flag/status if available; far-future schedule if not).
Expected: post appears in Postiz UI under Drafts (or scheduled-far-future queue), is NOT published to any social account.

- [ ] **Step 4: Document findings**

Write `docs/superpowers/notes/postiz-mcp-findings.md` containing:
- Exact MCP tool name to use for creating drafts
- Exact parameter shape (which fields, which values for "don't publish")
- Whether the API returns a `draft_id` we can store in state.jsonl
- Whether multiple integrations (linkedin + x) can be specified in a single call or require separate calls
- Any quirks (rate limits, character limits enforced server-side, etc.)

Template:
```markdown
# Postiz MCP Findings

## Tool to use for drafts
- Tool: `mcp__postiz__schedulePostTool` (or whatever actual name)
- Draft mechanism: <flag | status | far-future schedule>
- Exact parameter shape: <inline JSON>

## Return shape
- Field that contains the draft id: <name>

## Multi-platform behavior
- One call per platform: yes/no
- If one call: how to specify multiple integrations: <example>

## Quirks observed
- <any character limits, rate limits, surprises>
```

- [ ] **Step 5: Clean up the test post**

In Postiz UI (or via MCP if supported), delete the throwaway test post.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/notes/postiz-mcp-findings.md
git commit -m "docs: capture Postiz MCP draft semantics for storyteller publisher"
```

---

### Task 2: Verify GitHub MCP can list merged PRs across configured repos

**Files:**
- Append to: `docs/superpowers/notes/github-mcp-findings.md` (create if missing)

- [ ] **Step 1: List GitHub MCP tools**

Run in Claude Code:
```
List MCP tools whose name contains "github" or starts with "mcp__github".
Show the schema for the tool that lists pull requests.
```
Expected: at least one tool for listing PRs (likely `list_pull_requests` or `search_issues`). Capture the parameter shape (state filter, sort, repo specification).

- [ ] **Step 2: Test fetching merged PRs from one personal repo**

Run in Claude Code, replacing `<repo>` with one of your real personal repos:
```
Using the GitHub MCP, list all PRs merged into the default branch of kkmookhey/<repo> in the last 7 days. For each, return: number, title, url, merged_at, author, body (first 500 chars), and additions+deletions.
```
Expected: a list of PRs (could be empty if no recent activity) in a structured shape we can normalize into the Signal type.

- [ ] **Step 3: Document findings**

Write `docs/superpowers/notes/github-mcp-findings.md`:
```markdown
# GitHub MCP Findings

## Tool to list merged PRs
- Tool: <exact name>
- Parameter shape for "merged PRs in repo in last N days": <inline example>

## Return shape
- Fields available per PR: <list>
- How to access PR diff stats: <if separate call required, name it>

## Multi-repo behavior
- Can list across multiple repos in one call: yes/no
- If no: pattern for parallel calls: <example>

## Quirks
- <pagination defaults, rate limits, etc.>
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/notes/github-mcp-findings.md
git commit -m "docs: capture GitHub MCP PR-listing behavior for storyteller source adapter"
```

---

### Task 3: Initialize skill bundle structure and install script

**Files:**
- Create: `skill/storyteller/SKILL.md`
- Create: `skill/storyteller/sample-config.yaml`
- Create: `skill/storyteller/references/.gitkeep`
- Create: `scripts/install.sh`
- Create: `scripts/uninstall.sh`

- [ ] **Step 1: Create skeleton SKILL.md with valid frontmatter**

Write `skill/storyteller/SKILL.md`:
```markdown
---
name: storyteller
description: Use when KK wants to surface recent newsworthy product or company activity for social media posting. Triggers on /storyteller, "find me post ideas", "what's worth posting this week", "anything good from this week's PRs", scheduled Cowork runs, or any request to identify content-worthy moments from GitHub, Slack threads, or Confluence/Jira updates.
---

# StoryTeller — Signals → Ranked Drafts → Postiz

**SKELETON — workflow content added in Task 12.**

**REQUIRED VOICE SKILL:** kk-voice — load before any scoring or drafting step.
**REQUIRED FORMAT SKILL:** kk-short-form — load before drafting reels/shorts.
```

This skeleton exists so the install script has something to symlink. Workflow content lands in Task 12.

- [ ] **Step 2: Create sample-config.yaml**

Write `skill/storyteller/sample-config.yaml`:
```yaml
# StoryTeller configuration.
# Copy to ~/.storyteller/config.yaml and edit. The skill copies this automatically on first run.

sources:
  github:
    enabled: true
    repos:
      # Add your personal repos here as "owner/name"
      # - kkmookhey/your-repo
    only_authored_by_me: false
    lookback_days: 7

  slack:
    enabled: false  # Slice E
    channels: []
    lookback_days: 7
    min_reactions: 3

  atlassian:
    enabled: false  # Slice E
    confluence_spaces: []
    jira_jql: "status = Done AND updated >= -7d AND labels in (release, feature)"

scoring:
  rubric: jennifer
  top_n: 3

drafting:
  formats:
    - { platform: linkedin,  format: long-post, enabled: true }
    - { platform: x,         format: thread,    enabled: true }
    - { platform: instagram, format: caption,   enabled: true, hold: true }
    - { platform: reels,     format: script,    enabled: true, hold: true }

publishing:
  postiz:
    push_as_draft: true        # ALWAYS true. Never auto-publishes.
    workspace_id: null

notification:
  slack:
    target: ""                 # Your Slack user ID (e.g. U0123456789) or channel ID
    template: "{count} drafts queued in Postiz. Top: '{top_title}'. /storyteller to review."

state:
  retention_days: 90
```

- [ ] **Step 3: Placeholder for references/**

Write `skill/storyteller/references/.gitkeep` (empty file). Reference prompts land in Tasks 4-11.

- [ ] **Step 4: Write install script**

Write `scripts/install.sh`:
```bash
#!/usr/bin/env bash
# Install the storyteller skill into ~/.claude/skills/ via symlink and
# bootstrap user data dir at ~/.storyteller/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_SRC="${REPO_ROOT}/skill/storyteller"
SKILL_DEST="${HOME}/.claude/skills/storyteller"
USER_DATA="${HOME}/.storyteller"

if [[ ! -d "${SKILL_SRC}" ]]; then
  echo "Skill source missing: ${SKILL_SRC}" >&2
  exit 1
fi

mkdir -p "$(dirname "${SKILL_DEST}")"
if [[ -e "${SKILL_DEST}" || -L "${SKILL_DEST}" ]]; then
  echo "Removing existing ${SKILL_DEST}"
  rm -rf "${SKILL_DEST}"
fi
ln -s "${SKILL_SRC}" "${SKILL_DEST}"
echo "Linked ${SKILL_DEST} -> ${SKILL_SRC}"

mkdir -p "${USER_DATA}/pending-video" "${USER_DATA}/failed-pushes"
if [[ ! -f "${USER_DATA}/config.yaml" ]]; then
  cp "${SKILL_SRC}/sample-config.yaml" "${USER_DATA}/config.yaml"
  echo "Created ${USER_DATA}/config.yaml from sample. Edit it to add your repos and Slack target."
fi
touch "${USER_DATA}/state.jsonl"

echo
echo "StoryTeller installed."
echo "Edit ${USER_DATA}/config.yaml then run /storyteller in Claude Code."
```

- [ ] **Step 5: Write uninstall script**

Write `scripts/uninstall.sh`:
```bash
#!/usr/bin/env bash
# Remove the storyteller skill symlink. Does NOT touch ~/.storyteller/
# (your config and state are preserved).
set -euo pipefail
SKILL_DEST="${HOME}/.claude/skills/storyteller"
if [[ -L "${SKILL_DEST}" ]]; then
  rm "${SKILL_DEST}"
  echo "Removed symlink ${SKILL_DEST}"
elif [[ -e "${SKILL_DEST}" ]]; then
  echo "Refusing to remove ${SKILL_DEST}: it is a directory, not a symlink." >&2
  echo "Remove it manually if you intended to." >&2
  exit 1
else
  echo "Nothing to remove at ${SKILL_DEST}"
fi
echo "Note: ~/.storyteller/ is preserved (config + state). Delete manually if you want a full reset."
```

- [ ] **Step 6: Make scripts executable and run install**

```bash
chmod +x scripts/install.sh scripts/uninstall.sh
./scripts/install.sh
```
Expected output:
```
Linked $HOME/.claude/skills/storyteller -> $HOME/Projects/StoryTeller/skill/storyteller
Created $HOME/.storyteller/config.yaml from sample. ...
StoryTeller installed.
```

- [ ] **Step 7: Verify the skill is discoverable**

Open a new Claude Code session in any directory and ask:
```
Is there a "storyteller" skill installed? Show me its description.
```
Expected: Claude reports the skill exists and reads back the description from frontmatter.

- [ ] **Step 8: Commit**

```bash
git add skill/ scripts/
git commit -m "feat(skill): initialize storyteller skill skeleton and install scripts"
```

---

## Phase 2 — Source adapter (GitHub)

### Task 4: Build and validate `references/source-github.md`

**Files:**
- Create: `skill/storyteller/references/source-github.md`
- Create: `tests/fixtures/github-prs-sample.json`
- Create: `tests/scenarios/source-github.md`

- [ ] **Step 1: Capture a real fixture from your GitHub**

In Claude Code, using the tool name learned in Task 2:
```
Using the GitHub MCP, list the last 5 merged PRs (any age) from kkmookhey/<one-of-your-repos>.
For each, give me: number, title, url, merged_at, author, body (first 500 chars), additions, deletions.
Output strict JSON array.
```
Save the output as `tests/fixtures/github-prs-sample.json`.

- [ ] **Step 2: Write the scenario doc (test specification)**

Write `tests/scenarios/source-github.md`:
````markdown
# Test: source-github adapter

## Given
Fixture at `tests/fixtures/github-prs-sample.json` — array of raw PR objects from GitHub MCP.

## When
The `references/source-github.md` prompt is applied to that fixture.

## Then expect
A JSON array of Signal objects, one per input PR, each with exactly these keys:
- `source` (string, exactly `"github"`)
- `id` (string, format: `github:<owner>/<repo>:pr#<number>`)
- `url` (string, the PR's HTML URL)
- `title` (string, the PR title)
- `summary` (string, 2-4 sentences synthesizing the PR title + body — NOT a copy of the body)
- `timestamp` (string, ISO 8601, equal to merged_at)
- `author` (string, the PR author login)
- `raw` (object, containing at minimum: `number`, `additions`, `deletions`, `body_excerpt` (first 500 chars))

## Fail conditions
- Missing key on any signal
- `id` doesn't match the expected format
- `summary` is a verbatim copy of `body_excerpt`
- Output is not strict JSON
````

- [ ] **Step 3: Write the prompt template**

Write `skill/storyteller/references/source-github.md`:
````markdown
# Source: GitHub

Normalize raw GitHub PR data from the GitHub MCP into the StoryTeller Signal shape.

## How to call

For each repo in `config.sources.github.repos`, query the GitHub MCP for PRs merged into the default branch within `config.sources.github.lookback_days`. If `only_authored_by_me` is true, filter to PRs where `user.login` equals the authenticated user's login.

Run repo queries in parallel (one MCP call per repo) and concatenate results.

## Per-PR transformation

For each raw PR object, produce a Signal with these keys:

```json
{
  "source": "github",
  "id": "github:<owner>/<repo>:pr#<number>",
  "url": "<pr.html_url>",
  "title": "<pr.title>",
  "summary": "<2-4 sentence synthesis of title + body — what the PR actually did and why it matters. NOT a verbatim copy of the PR body.>",
  "timestamp": "<pr.merged_at in ISO 8601>",
  "author": "<pr.user.login>",
  "raw": {
    "number": <pr.number>,
    "additions": <pr.additions>,
    "deletions": <pr.deletions>,
    "body_excerpt": "<first 500 chars of pr.body>"
  }
}
```

## Summary writing rules

The `summary` is for the scorer to judge post-worthiness. It must:
- Be 2-4 sentences (not bullets, not headings)
- Describe what shipped and why it might matter (user-facing impact, technical decision, risk surfaced)
- Avoid being a verbatim copy of the PR body
- Avoid restating the title
- If the PR body is empty or trivial, derive the summary from the title + diff stats only and note "minimal description provided" in the summary

## Output

Return a strict JSON array of Signals — no prose around it, no markdown fence.
````

- [ ] **Step 4: Run the test scenario**

In Claude Code:
```
Load tests/fixtures/github-prs-sample.json. Apply the transformation rules in
skill/storyteller/references/source-github.md to each PR in the fixture.
Return the resulting Signal[] as strict JSON.
```
Save output to `/tmp/source-github-out.json`. Then validate:
```bash
python3 -c '
import json, sys
data = json.load(open("/tmp/source-github-out.json"))
fixture = json.load(open("tests/fixtures/github-prs-sample.json"))
assert isinstance(data, list), "not a list"
assert len(data) == len(fixture), f"len mismatch: {len(data)} vs {len(fixture)}"
required = {"source","id","url","title","summary","timestamp","author","raw"}
for i, s in enumerate(data):
    missing = required - set(s.keys())
    assert not missing, f"signal {i} missing: {missing}"
    assert s["source"] == "github", f"signal {i} wrong source"
    assert s["id"].startswith("github:"), f"signal {i} bad id format: {s[\"id\"]}"
    assert s["raw"]["body_excerpt"] != s["summary"], f"signal {i} summary is verbatim body"
print("PASS:", len(data), "signals validated")
'
```
Expected output: `PASS: N signals validated`

If FAIL: iterate on `references/source-github.md` until passing. Common fixes: tighten the summary instructions, explicitly forbid verbatim copying, give an example.

- [ ] **Step 5: Commit**

```bash
git add skill/storyteller/references/source-github.md tests/fixtures/github-prs-sample.json tests/scenarios/source-github.md
git commit -m "feat(skill): add github source adapter prompt with fixture-based test"
```

---

## Phase 3 — Scoring

### Task 5: Build `references/scoring-rubric.md`

**Files:**
- Create: `skill/storyteller/references/scoring-rubric.md`
- Create: `tests/scenarios/scoring-rubric.md`

- [ ] **Step 1: Write the scenario doc**

Write `tests/scenarios/scoring-rubric.md`:
````markdown
# Test: scoring-rubric

## Given
A list of Signal objects (from any source adapter test output, e.g., source-github output).

## When
The `references/scoring-rubric.md` prompt is applied to the list, with the `kk-voice` skill loaded.

## Then expect
A JSON array, one object per input signal (same length, same order), each with exactly:
- `signal_id` (string, must equal the input signal's `id`)
- `score` (integer 0-10)
- `why_postworthy` (string, one sentence)
- `suggested_angle` (string, one sentence)

## Fail conditions
- Length mismatch with input
- Missing `signal_id` on any item
- `signal_id` doesn't match an input signal
- `score` out of range (not 0-10) or non-integer
- Any field missing
- Output is not strict JSON
````

- [ ] **Step 2: Write the prompt template**

Write `skill/storyteller/references/scoring-rubric.md`:
````markdown
# Scoring Rubric — Jennifer Filter

Score each Signal against KK Mookhey's Jennifer Chen filter.

**REQUIRED VOICE SKILL:** Load `kk-voice` before applying this rubric. Use its Jennifer Chen audience definition and pre-publish checklist as the source of truth.

## Rubric

Each criterion contributes 0-2 to a 0-10 score (cap at 10):

| Criterion | 0 | 1 | 2 |
|---|---|---|---|
| Specific operational substance | abstract, no named tools/numbers | partial specificity | named tools, concrete numbers, real scenario |
| Borrowable insight | not borrowable | borrowable but generic | Jennifer can paraphrase in her next meeting and sound sharper |
| Receipts vs generalities | claims without evidence | one piece of evidence | receipts throughout (numbers, named tools, outcomes) |
| Operator voice over founder voice | centers founder journey | mixed | centers "what we saw doing the work" |
| Problem-before-product (if Transilience appears) | product first | balanced | problem dominates first 80% |

If Transilience is NOT mentioned, score the last criterion based on whether the post centers the user's problem (2) vs the writer's announcement (0).

## Hard zeros

Score = 0 (do not waste a draft slot) for signals that are:
- Internal HR/admin (vacation, team restructure, hiring announcements with no insight)
- Customer-confidential with no extractable lesson
- India/ME-regional only with no universal lesson
- "Excited to announce" material
- Pure dependency bumps, lint fixes, or trivial chore PRs

## Output

Return strictly a JSON array — no prose around it, no markdown fence. Maintain input order. One object per input signal:

```json
[
  {
    "signal_id": "<exactly the input signal id>",
    "score": <integer 0-10>,
    "why_postworthy": "<one sentence — what makes this Jennifer-worthy, or why it isn't>",
    "suggested_angle": "<one sentence — the angle that would maximize Jennifer-fit>"
  }
]
```

## Inputs

`{signals_json}` — JSON array of Signal objects to score.
````

- [ ] **Step 3: Smoke-test the prompt**

In Claude Code:
```
Make sure the kk-voice skill is loaded. Then apply the rubric in
skill/storyteller/references/scoring-rubric.md to the Signal[] in
/tmp/source-github-out.json. Return strict JSON.
```
Save to `/tmp/scoring-out.json`. Validate structure:
```bash
python3 -c '
import json
out = json.load(open("/tmp/scoring-out.json"))
sigs = json.load(open("/tmp/source-github-out.json"))
assert isinstance(out, list), "not a list"
assert len(out) == len(sigs), f"len mismatch: {len(out)} vs {len(sigs)}"
ids = {s["id"] for s in sigs}
for i, item in enumerate(out):
    for k in ("signal_id","score","why_postworthy","suggested_angle"):
        assert k in item, f"item {i} missing {k}"
    assert item["signal_id"] in ids, f"item {i} unknown signal_id {item[\"signal_id\"]}"
    assert isinstance(item["score"], int), f"item {i} score not int"
    assert 0 <= item["score"] <= 10, f"item {i} score out of range"
print("PASS:", len(out), "scores validated")
'
```
Expected: `PASS: N scores validated`

- [ ] **Step 4: Commit**

```bash
git add skill/storyteller/references/scoring-rubric.md tests/scenarios/scoring-rubric.md
git commit -m "feat(skill): add Jennifer-filter scoring rubric with structure test"
```

---

### Task 6: Generate the golden-set fixture for scoring calibration

**Files:**
- Create: `tests/fixtures/scoring-golden-set.json`

This is the calibration material. The fixture pairs KK's manual scores with PRs/signals; Task 7 measures how closely Claude's scores agree.

- [ ] **Step 1: Pick 15-20 candidate signals**

Pull a diverse set from your personal repos (use the Task 4 fixture or fetch fresh). Aim for variety:
- 4-5 that you'd score high (8-10) — actually interesting, post-worthy
- 4-5 mid (4-7) — fine but not exciting
- 4-5 low (0-3) — dependency bumps, lint fixes, internal cleanup

- [ ] **Step 2: Hand-rate each one**

For each signal, write your own score (0-10) and a one-line reason. Don't peek at Claude's output yet — that defeats the calibration.

- [ ] **Step 3: Save the golden set**

Write `tests/fixtures/scoring-golden-set.json`:
```json
[
  {
    "signal": { /* full Signal object */ },
    "kk_score": 9,
    "kk_reason": "Real receipts on prompt injection at tool boundary. Exact Jennifer wheelhouse."
  },
  {
    "signal": { /* full Signal object */ },
    "kk_score": 2,
    "kk_reason": "Lint cleanup. No story. Skip."
  }
  // ...
]
```

- [ ] **Step 4: Commit**

```bash
git add tests/fixtures/scoring-golden-set.json
git commit -m "test(fixture): add scoring calibration golden set (15-20 hand-rated signals)"
```

---

### Task 7: Calibrate the scorer to ≥80% correlation with KK's scores

**Files:**
- Create: `scripts/calibrate-scoring.py`

- [ ] **Step 1: Write the calibration script**

Write `scripts/calibrate-scoring.py`:
```python
#!/usr/bin/env python3
"""Compare Claude's scores against KK's golden-set scores.

Usage:
  1. In Claude Code, run the scoring rubric against the Signal[] extracted from
     tests/fixtures/scoring-golden-set.json. Save the JSON output to
     /tmp/claude-scores.json.
  2. Run this script.

Exits 0 if Pearson correlation >= 0.80, else exits 1.
"""
import json
import sys
from pathlib import Path

GOLDEN = Path("tests/fixtures/scoring-golden-set.json")
CLAUDE = Path("/tmp/claude-scores.json")

def pearson(xs, ys):
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    den_x = (sum((x - mx) ** 2 for x in xs)) ** 0.5
    den_y = (sum((y - my) ** 2 for y in ys)) ** 0.5
    if den_x == 0 or den_y == 0:
        return 0.0
    return num / (den_x * den_y)

def main() -> int:
    if not GOLDEN.exists():
        print(f"Missing {GOLDEN}", file=sys.stderr)
        return 2
    if not CLAUDE.exists():
        print(f"Missing {CLAUDE}. Run the scoring rubric in Claude Code first.", file=sys.stderr)
        return 2
    golden = json.loads(GOLDEN.read_text())
    claude = json.loads(CLAUDE.read_text())
    by_id = {c["signal_id"]: c for c in claude}

    pairs = []
    for entry in golden:
        sid = entry["signal"]["id"]
        if sid not in by_id:
            print(f"  MISSING: Claude did not score {sid}", file=sys.stderr)
            continue
        pairs.append((entry["kk_score"], by_id[sid]["score"], sid, entry["kk_reason"], by_id[sid]["why_postworthy"]))

    if not pairs:
        print("No overlap between golden set and Claude scores.", file=sys.stderr)
        return 2

    xs = [p[0] for p in pairs]
    ys = [p[1] for p in pairs]
    r = pearson(xs, ys)

    print(f"{'KK':>4} {'Claude':>6}  ID")
    print("-" * 80)
    for kk, cl, sid, kr, cr in sorted(pairs, key=lambda p: -abs(p[0] - p[1])):
        flag = "  <-- big diff" if abs(kk - cl) >= 3 else ""
        print(f"{kk:>4} {cl:>6}  {sid}{flag}")
        if abs(kk - cl) >= 3:
            print(f"       KK:     {kr}")
            print(f"       Claude: {cr}")

    print()
    print(f"Pearson correlation: {r:.3f}")
    print(f"Mean absolute error: {sum(abs(a-b) for a,b in zip(xs,ys))/len(xs):.2f}")
    if r >= 0.80:
        print("PASS: r >= 0.80")
        return 0
    print("FAIL: r < 0.80 — tighten the rubric and retry.")
    return 1

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run scoring in Claude Code against the golden set**

In Claude Code:
```
Load tests/fixtures/scoring-golden-set.json. Extract the .signal field from each entry
into a Signal[] array. Apply skill/storyteller/references/scoring-rubric.md to that array.
Return the raw JSON output.
```
Save the output to `/tmp/claude-scores.json`.

- [ ] **Step 3: Run the calibration script**

```bash
chmod +x scripts/calibrate-scoring.py
python3 scripts/calibrate-scoring.py
```

- [ ] **Step 4: If r < 0.80, tighten the rubric**

Look at the "big diff" rows. For each, ask: did Claude misread the rubric, or is the rubric ambiguous? Common fixes:
- Add a concrete example to the rubric ("score 9: PR title 'add prompt-injection guardrails at tool boundary' — score 9 because…")
- Sharpen a vague criterion (replace "borrowable insight" with a more operational definition)
- Add a hard-zero criterion you missed (e.g., "PR is a release-tag bump only")

Re-run Steps 2-3 until r >= 0.80. Document each rubric change in a brief commit.

- [ ] **Step 5: Commit calibration script + final rubric**

```bash
git add scripts/calibrate-scoring.py skill/storyteller/references/scoring-rubric.md
git commit -m "test(calibration): scoring rubric correlates >=0.80 with KK's golden set"
```

---

## Phase 4 — Drafting (4 formats)

### Task 8: Build and validate `references/drafting-linkedin.md`

**Files:**
- Create: `skill/storyteller/references/drafting-linkedin.md`
- Create: `tests/scenarios/drafting-linkedin.md`

- [ ] **Step 1: Write the scenario doc**

Write `tests/scenarios/drafting-linkedin.md`:
````markdown
# Test: drafting-linkedin

## Given
A single ScoredSignal (Signal + score + why_postworthy + suggested_angle) chosen from /tmp/claude-scores.json with score >= 7.

## When
The `references/drafting-linkedin.md` prompt is applied with `kk-voice` skill loaded.

## Then expect
A single JSON object:
- `platform` == "linkedin"
- `format` == "long-post"
- `content` (string) — between 150 and 280 words
- `hashtags` (array of strings, each starts with "#", 2-5 items)
- `internal_notes` (string)

## Then qualitative-judge (second Claude call)
Apply the kk-voice Jennifer pre-publish checklist (7 items) to `content`. Must pass all 7.

## Fail conditions
- Word count outside 150-280
- Hashtags count outside 2-5
- Content contains banned phrases from kk-voice (e.g., "leverage", "synergy", "excited to announce")
- Content fails any Jennifer filter item
````

- [ ] **Step 2: Write the prompt template**

Write `skill/storyteller/references/drafting-linkedin.md`:
````markdown
# Drafting — LinkedIn Long-Form Post

**REQUIRED VOICE SKILL:** Load `kk-voice` before drafting. Apply its Jennifer pre-publish checklist as the bar — the output MUST pass all 7 checks before being returned.

## Input

A single ScoredSignal:
```json
{
  "signal": { /* the Signal object */ },
  "score": <int>,
  "why_postworthy": "<one sentence>",
  "suggested_angle": "<one sentence>"
}
```

## Structure

- **Hook (1-2 lines):** First two lines visible above the LinkedIn "...see more" fold MUST name Jennifer-relevant stakes. No "excited to announce". No questions to the audience as the hook.
- **Body (150-280 words):** Receipts first. Named tools, real numbers, concrete scenario from the Signal. No general industry observations until you have laid down receipts.
- **Generalized lesson (1 line):** A borrowable insight Jennifer can paraphrase in her next meeting. NOT a CTA, NOT a question.
- **Optional closing line:** Only if it adds a thought worth sharing. No "What do you think?" / "Drop your thoughts below" / "Comments welcome".

## Voice constraints (cross-check against kk-voice)

- Conversational professional register
- Sentences mostly medium-length, occasional short punches
- Contractions natural ("you're", "it's", "don't")
- No corporate jargon ("leverage", "synergy", "alignment", "stakeholder buy-in", "deep dive", "circle back")
- No AI-slop ("It's important to note", "In today's rapidly evolving landscape")
- No founder-journey framing for Jennifer ("how I scaled to $X ARR")
- No India/ME-first framing (color is fine; subject is not)
- If Transilience appears: problem dominates first 80%; product appears only in last 20%

## Output

Return ONLY a single JSON object — no prose around it, no markdown fence:

```json
{
  "platform": "linkedin",
  "format": "long-post",
  "content": "<the post body as a single string with \\n line breaks>",
  "hashtags": ["#cybersecurity", "..."],
  "internal_notes": "<one line: which 2-3 Jennifer filter criteria this draft hits hardest, in your judgment>"
}
```
````

- [ ] **Step 3: Pick a high-scoring signal for the test**

In Claude Code:
```
From /tmp/claude-scores.json, pick the highest-scoring signal (any signal with score >= 7).
Combine with its full Signal object from /tmp/source-github-out.json. Save as
/tmp/scored-signal-sample.json in the ScoredSignal shape.
```

- [ ] **Step 4: Run the drafting prompt**

In Claude Code:
```
Ensure kk-voice skill is loaded. Apply skill/storyteller/references/drafting-linkedin.md
to /tmp/scored-signal-sample.json. Return strict JSON.
```
Save to `/tmp/linkedin-draft.json`.

- [ ] **Step 5: Structural validation**

```bash
python3 -c '
import json, re
d = json.load(open("/tmp/linkedin-draft.json"))
assert d["platform"] == "linkedin", "wrong platform"
assert d["format"] == "long-post", "wrong format"
wc = len(d["content"].split())
assert 150 <= wc <= 280, f"word count {wc} outside 150-280"
tags = d["hashtags"]
assert isinstance(tags, list) and 2 <= len(tags) <= 5, f"hashtags count {len(tags)} outside 2-5"
for t in tags: assert t.startswith("#"), f"hashtag missing #: {t}"
banned = ["leverage", "synergy", "excited to announce", "stakeholder buy-in"]
lower = d["content"].lower()
for b in banned:
    assert b not in lower, f"banned phrase found: {b}"
print(f"PASS: {wc} words, {len(tags)} hashtags, no banned phrases")
'
```
Expected: `PASS: <N> words, <M> hashtags, no banned phrases`

- [ ] **Step 6: Voice-judge validation (second Claude call)**

In Claude Code:
```
Load kk-voice. Read the LinkedIn post in /tmp/linkedin-draft.json's "content" field.
Apply the Jennifer pre-publish checklist (7 items). For each item, return JSON:
{"item": <number>, "name": "<short item name>", "passes": true|false, "reason": "<one sentence>"}
Return strict JSON array of 7 items.
```
Save to `/tmp/jennifer-judgment.json` and check:
```bash
python3 -c '
import json
items = json.load(open("/tmp/jennifer-judgment.json"))
assert len(items) == 7, f"expected 7 items, got {len(items)}"
failed = [i for i in items if not i["passes"]]
if failed:
    print("FAILED items:")
    for f in failed:
        print(f"  - {f[\"name\"]}: {f[\"reason\"]}")
    raise SystemExit(1)
print("PASS: all 7 Jennifer checks")
'
```
Expected: `PASS: all 7 Jennifer checks`

If FAIL: iterate on `references/drafting-linkedin.md`. Common fixes: tighten the hook instructions, add an explicit example of a passing post, add the failing item as an explicit constraint.

- [ ] **Step 7: Commit**

```bash
git add skill/storyteller/references/drafting-linkedin.md tests/scenarios/drafting-linkedin.md
git commit -m "feat(skill): add LinkedIn drafting prompt with structural and Jennifer-filter tests"
```

---

### Task 9: Build and validate `references/drafting-x-thread.md`

**Files:**
- Create: `skill/storyteller/references/drafting-x-thread.md`
- Create: `tests/scenarios/drafting-x-thread.md`

- [ ] **Step 1: Write the scenario doc**

Write `tests/scenarios/drafting-x-thread.md`:
````markdown
# Test: drafting-x-thread

## Given
Same ScoredSignal as Task 8.

## When
The `references/drafting-x-thread.md` prompt is applied with kk-voice loaded.

## Then expect
A JSON object:
- `platform` == "x"
- `format` == "thread"
- `content` (array of 3-5 strings; each <= 280 chars)
- `hashtags` (array, 0-3 items)
- `internal_notes` (string)

## Fail conditions
- Any thread post > 280 chars
- Thread count outside 3-5
- Hashtags > 3
- Voice violations (same banned-phrase list as LinkedIn)
````

- [ ] **Step 2: Write the prompt template**

Write `skill/storyteller/references/drafting-x-thread.md`:
````markdown
# Drafting — X (Twitter) Thread

**REQUIRED VOICE SKILL:** Load `kk-voice`. Same voice constraints as LinkedIn; tighter compression. Same banned-phrase list. Same Jennifer filter applies, scaled to 280-char posts.

## Input

A single ScoredSignal (same shape as drafting-linkedin).

## Structure

3-5 posts. Each MUST be <= 280 characters (including spaces and any inline numbering).

- **Post 1 (hook):** The post that earns the rest. Names stakes, hints at the receipt.
- **Posts 2 to N-1 (receipts):** Named tools, numbers, concrete scenario. One distinct point per post.
- **Post N (close):** One borrowable insight. NO "follow for more", NO "what do you think", NO link to LinkedIn version.

Do NOT insert "1/", "2/" prefixes — Postiz handles thread numbering. Write each post as standalone text.

## Voice constraints

Identical to drafting-linkedin's voice constraints section — same banned phrases, same anti-patterns.

## Output

```json
{
  "platform": "x",
  "format": "thread",
  "content": [
    "<post 1 text, <=280 chars>",
    "<post 2 text, <=280 chars>",
    "<post 3 text, <=280 chars>"
  ],
  "hashtags": ["#cybersecurity"],
  "internal_notes": "<one line: hardest-hitting Jennifer criteria>"
}
```
````

- [ ] **Step 3: Run drafting and validate**

In Claude Code:
```
With kk-voice loaded, apply skill/storyteller/references/drafting-x-thread.md
to /tmp/scored-signal-sample.json. Return strict JSON.
```
Save to `/tmp/x-thread.json` and validate:
```bash
python3 -c '
import json
d = json.load(open("/tmp/x-thread.json"))
assert d["platform"] == "x" and d["format"] == "thread"
assert isinstance(d["content"], list)
assert 3 <= len(d["content"]) <= 5, f"thread count {len(d[\"content\"])} outside 3-5"
for i, p in enumerate(d["content"]):
    assert len(p) <= 280, f"post {i} is {len(p)} chars, exceeds 280"
assert 0 <= len(d["hashtags"]) <= 3, f"hashtags count {len(d[\"hashtags\"])}"
banned = ["leverage", "synergy", "excited to announce"]
for i, p in enumerate(d["content"]):
    for b in banned:
        assert b not in p.lower(), f"post {i} contains banned phrase: {b}"
print(f"PASS: {len(d[\"content\"])} posts, all under 280 chars")
'
```

- [ ] **Step 4: Commit**

```bash
git add skill/storyteller/references/drafting-x-thread.md tests/scenarios/drafting-x-thread.md
git commit -m "feat(skill): add X thread drafting prompt with per-post length validation"
```

---

### Task 10: Build `references/drafting-instagram.md` (held content — no live publish)

**Files:**
- Create: `skill/storyteller/references/drafting-instagram.md`
- Create: `tests/scenarios/drafting-instagram.md`

- [ ] **Step 1: Write the scenario doc**

Write `tests/scenarios/drafting-instagram.md`:
````markdown
# Test: drafting-instagram

## Given
Same ScoredSignal as Task 8.

## When
The `references/drafting-instagram.md` prompt is applied with kk-voice loaded.

## Then expect
A JSON object:
- `platform` == "instagram"
- `format` == "caption"
- `content` (string, <= 2200 chars including hashtags)
- `hashtags` (array; in this format hashtags are embedded in content, so this array is informational and may be empty)
- `internal_notes` (string)
- `hold: true` flag — this draft is NOT pushed to Postiz

## Fail conditions
- content > 2200 chars
- hashtags not at end of content
- Voice violations
````

- [ ] **Step 2: Write the prompt template**

Write `skill/storyteller/references/drafting-instagram.md`:
````markdown
# Drafting — Instagram Caption

**REQUIRED VOICE SKILL:** Load `kk-voice`. NOTE: Instagram's audience (KK's @settlingforless1) is Meera/Rohan, not Jennifer. See `kk-short-form` for that audience profile. Caption tone is warmer and more direct than LinkedIn; less corporate.

This draft is HELD in Slice D — it does NOT push to Postiz. It pairs with a Reels video in a later slice.

## Input

A single ScoredSignal.

## Structure

A single caption string. Up to 2200 characters total (Instagram limit).

- Opening line: Meera/Rohan-relevant stakes (per kk-short-form audience definition). If the signal is too Jennifer-skewed to land for Meera, the caption acknowledges this and is targeted at Rohan instead.
- Body: 2-4 short paragraphs. Specific, not abstract.
- Hashtag block at the very end, separated by 3 lines of single periods (Instagram convention):
  ```
  .
  .
  .
  #cybersecurity #aisecurity ...
  ```

## Voice constraints

- Same anti-patterns as LinkedIn for KK voice
- Hashtags: 3-7 max, primary always #cybersecurity

## Output

```json
{
  "platform": "instagram",
  "format": "caption",
  "content": "<full caption including the trailing hashtag block>",
  "hashtags": [],
  "hold": true,
  "internal_notes": "<one line: Meera vs Rohan targeting, why>"
}
```

The `hold: true` flag tells the publisher to write this draft to `~/.storyteller/pending-video/<signal_id>-instagram.json` instead of pushing to Postiz.
````

- [ ] **Step 3: Run and structurally validate**

In Claude Code:
```
With kk-voice loaded, apply skill/storyteller/references/drafting-instagram.md
to /tmp/scored-signal-sample.json. Return strict JSON.
```
Save to `/tmp/instagram-caption.json` and validate:
```bash
python3 -c '
import json
d = json.load(open("/tmp/instagram-caption.json"))
assert d["platform"] == "instagram" and d["format"] == "caption"
assert d["hold"] is True, "must be held"
assert len(d["content"]) <= 2200, f"content {len(d[\"content\"])} > 2200"
assert "\n.\n.\n.\n" in d["content"] or "\n.\n.\n.\n#" in d["content"], "missing period separator before hashtags"
assert "#" in d["content"], "no hashtags in content"
print(f"PASS: {len(d[\"content\"])} chars, hold=true")
'
```

- [ ] **Step 4: Commit**

```bash
git add skill/storyteller/references/drafting-instagram.md tests/scenarios/drafting-instagram.md
git commit -m "feat(skill): add Instagram caption drafting (held content, pairs with future video)"
```

---

### Task 11: Build `references/drafting-reels.md` (held content — script for future video)

**Files:**
- Create: `skill/storyteller/references/drafting-reels.md`
- Create: `tests/scenarios/drafting-reels.md`

- [ ] **Step 1: Write the scenario doc**

Write `tests/scenarios/drafting-reels.md`:
````markdown
# Test: drafting-reels

## Given
Same ScoredSignal as Task 8.

## When
The `references/drafting-reels.md` prompt is applied with kk-voice AND kk-short-form loaded.

## Then expect
A JSON object:
- `platform` == "reels"
- `format` == "script"
- `content_markdown` (string, structured script with timestamps)
- `caption_for_post` (string, <= 2200 chars — caption to publish alongside the video later)
- `hashtags` (array, 3-7 items)
- `video_pending: true`
- `internal_notes` (string)

## Fail conditions
- content_markdown missing timestamps in [00:00–00:0X] format
- Banned hooks (e.g., "Hey guys", "Welcome back", "The biggest news in")
- Length target violations (Meera reel >35s implied length, etc.)
- caption_for_post > 2200 chars
````

- [ ] **Step 2: Write the prompt template**

Write `skill/storyteller/references/drafting-reels.md`:
````markdown
# Drafting — Instagram Reels / YouTube Shorts Script

**REQUIRED VOICE SKILL:** Load `kk-voice`.
**REQUIRED FORMAT SKILL:** Load `kk-short-form` — use its 4-part structure, hook formulas, pacing rules, and pre-publish checklist as the bar.

This draft is HELD in Slice D — no video exists yet. Saves to `~/.storyteller/pending-video/<signal_id>-reels.json` for the Descript slice to pick up.

## Input

A single ScoredSignal.

## Decide audience first

Per kk-short-form's 60/30/10 ratio: classify the signal as Meera (PSA-style for non-tech), Rohan (technical reveal for tech-adjacent), or Story (reflective). Default to Rohan for GitHub PR signals — they are technical by nature. Use Meera ONLY if the PR has a clear non-tech consumer safety/privacy angle. Use Story only for retrospective or philosophical PRs.

## Structure (from kk-short-form 4-part architecture)

Script in markdown with timestamps. Length targets from kk-short-form:
- Rohan reel: 35-60s
- Meera reel: 20-35s
- Story reel: 30-45s

```
# TITLE: <working title>
AUDIENCE: <Meera | Rohan | Story>
LENGTH TARGET: <range>

[00:00–00:03] HOOK
VO: <hook line — one sentence, names audience + stakes>
Text overlay: <bold short overlay>
Visual: <what's on screen>

[00:03–00:10] SETUP
VO: <1-2 sentences of specific context>
Text overlay: <specific noun>
Visual: <B-roll suggestion>

[00:10–00:XX] PAYOFF
VO: <the actual value — steps OR technical reveal OR story beat>
Text overlay: <numbered steps OR key stat OR specific finding>
Visual: <screen recording suggestion>
Re-hook every 8-10 seconds: <list 1-3 re-hooks>

[FINAL 5-10s] CLOSE
VO: <loop-back line OR forward-prompt with named recipient>
Text overlay: <final punch>
Visual: <return to opening visual OR direct-camera>
```

## Pre-publish checklist (cross-check before returning)

Apply kk-short-form's 10-item pre-publish checklist. If any item fails, revise.

Banned hooks (auto-fail if used): "Hey guys", "Welcome back", "The biggest news in", "Guys you won't believe", "In today's video".

## Output

```json
{
  "platform": "reels",
  "format": "script",
  "content_markdown": "<the full script as markdown with timestamps>",
  "caption_for_post": "<caption to publish alongside the video — <=2200 chars, ends with hashtag block>",
  "hashtags": ["#cybersecurity", "..."],
  "hold": true,
  "video_pending": true,
  "internal_notes": "<one line: chosen audience and why, key kk-short-form criteria hit>"
}
```

`hold: true` is the orchestrator-facing flag — SKILL.md step 7 routes any draft with `hold: true` to `~/.storyteller/pending-video/`. `video_pending: true` is semantic metadata for Slice G (Descript) to find Reels scripts awaiting video generation.
````

- [ ] **Step 3: Run and validate**

In Claude Code:
```
With kk-voice AND kk-short-form loaded, apply skill/storyteller/references/drafting-reels.md
to /tmp/scored-signal-sample.json. Return strict JSON.
```
Save to `/tmp/reels-script.json` and validate:
```bash
python3 -c '
import json, re
d = json.load(open("/tmp/reels-script.json"))
assert d["platform"] == "reels" and d["format"] == "script"
assert d["hold"] is True, "hold flag must be true (orchestrator routes to pending-video/)"
assert d["video_pending"] is True, "video_pending must be true (Slice G looks for this)"
md = d["content_markdown"]
assert re.search(r"\[\d{2}:\d{2}", md), "no timestamp markers in script"
banned_hooks = ["hey guys", "welcome back", "the biggest news in", "guys you won't believe", "in today's video"]
for b in banned_hooks:
    assert b not in md.lower(), f"banned hook: {b}"
assert len(d["caption_for_post"]) <= 2200, f"caption {len(d[\"caption_for_post\"])} > 2200"
assert 3 <= len(d["hashtags"]) <= 7, f"hashtag count {len(d[\"hashtags\"])}"
print("PASS: script has timestamps, no banned hooks, caption within limits")
'
```

- [ ] **Step 4: Commit**

```bash
git add skill/storyteller/references/drafting-reels.md tests/scenarios/drafting-reels.md
git commit -m "feat(skill): add Reels script drafting using kk-short-form structure (held for video slice)"
```

---

## Phase 5 — Orchestration

### Task 12: Flesh out SKILL.md with the 8-step workflow

**Files:**
- Modify: `skill/storyteller/SKILL.md`

- [ ] **Step 1: Word-count baseline of current SKILL.md**

```bash
wc -w skill/storyteller/SKILL.md
```
Target after this task: <500 words.

- [ ] **Step 2: Replace the skeleton with the full workflow**

Overwrite `skill/storyteller/SKILL.md` with:
```markdown
---
name: storyteller
description: Use when KK wants to surface recent newsworthy product or company activity for social media posting. Triggers on /storyteller, "find me post ideas", "what's worth posting this week", "anything good from this week's PRs", scheduled Cowork runs, or any request to identify content-worthy moments from GitHub, Slack threads, or Confluence/Jira updates.
---

# StoryTeller — Signals → Ranked Drafts → Postiz

**REQUIRED VOICE SKILL:** kk-voice — load before any scoring or drafting step.
**REQUIRED FORMAT SKILL:** kk-short-form — load before drafting reels/shorts.
**REQUIRED BACKGROUND:** superpowers:test-driven-development (applies when validating the skill).

## Prerequisites

- MCPs configured and authenticated: GitHub, Postiz, Slack (write).
- Config exists at `~/.storyteller/config.yaml`. If missing, copy from this skill's `sample-config.yaml` and stop with a message telling KK to fill in repos and Slack target.

## Workflow

1. **Load config** from `~/.storyteller/config.yaml`. If `sources.github.repos` is empty, stop and tell the user to add repos.

2. **Fetch signals in parallel** from each enabled source using `references/source-<name>.md`. Slice D enables `github` only. Each adapter returns Signal[]. Merge results.

3. **Dedupe** against `~/.storyteller/state.jsonl`. Drop signals whose `id` appears in any prior entry. Drop entries older than `state.retention_days` from the state file as a maintenance step.

4. **Score and rank** in ONE batched call using `references/scoring-rubric.md` with `kk-voice` loaded. Drop signals with score < 4. Sort desc by score. Keep top-N from `scoring.top_n` (default 3).

5. **Draft** each top signal in every enabled format using the matching `references/drafting-*.md`. Voice delegated to `kk-voice` / `kk-short-form`. Drafts that produce structurally invalid JSON are retried once with a stricter prompt; on second failure, the signal is skipped and flagged in the final Slack notification.

6. **Interactive mode only:** Show the ranked drafts as markdown. Loop on user edits ("tighten draft 2 hook", "kill X thread for draft 3", "redraft draft 1 with sharper angle") until the user says "ship it". Skip this step entirely in scheduled mode (Cowork) — proceed directly to step 7.

7. **Publish:** For each draft NOT marked `hold: true`, push to Postiz as a draft (NEVER `publish: true`) using the tool and parameters documented in `docs/superpowers/notes/postiz-mcp-findings.md`. For drafts WITH `hold: true`, save to `~/.storyteller/pending-video/<signal_id>-<platform>.json`. Capture returned Postiz draft IDs. On push failure, retry once; on second failure, save the draft to `~/.storyteller/failed-pushes/` and continue.

8. **Notify Slack** using `notification.slack.template` with `{count}` (total drafts pushed) and `{top_title}` (title of highest-scored signal). Send via Slack MCP to `notification.slack.target`. **Append to state.jsonl** for each drafted signal: `{"signal_id": "...", "drafted_at": "<ISO>", "postiz_draft_ids": [...]}`.

## Modes

- **Interactive:** Invoked via `/storyteller`. Includes step 6.
- **Scheduled (Cowork):** Same workflow, skips step 6. User reviews in Postiz.

## Flags

Parse from the invocation prompt:
- `--dry-run`: run steps 1-5 normally; skip step 6's user prompt by auto-shipping; in step 7 do NOT push to Postiz and do NOT write to pending-video/; in step 8 print the would-be Slack message but don't send; don't append to state.jsonl.
- `--source <name>`: in step 2, only fetch from the named source.
- `--no-postiz`: in step 7, skip Postiz push but still write `hold` content to pending-video/ and still write state.jsonl.
- `--no-notify`: skip step 8's Slack send (still write state.jsonl).

## Failure handling

- Source MCP error: log, continue with remaining sources. If ALL sources fail, abort with a Slack error.
- Postiz push failure: retry once, then move draft to `~/.storyteller/failed-pushes/<signal_id>-<platform>.json` and flag in the final Slack notification.
- Scoring returns malformed JSON: retry once with a stricter "JSON ONLY, NO PROSE" prefix. On second failure, fall back to chronological order (most recent first) and flag in Slack.

## Failure-mode anti-patterns (DO NOT do these)

- Do NOT pass `publish: true` to Postiz under any circumstances. The user has explicitly forbidden auto-posting.
- Do NOT skip step 3 (dedupe) — without it the same PR gets redrafted every run.
- Do NOT generate drafts BEFORE scoring — only top-N signals get drafted.
- Do NOT silently swallow scoring/drafting failures — surface them in the Slack notification.
```

- [ ] **Step 3: Verify word count**

```bash
wc -w skill/storyteller/SKILL.md
```
Expected: <500 words. If over, tighten by moving examples to references/ or removing redundancy.

- [ ] **Step 4: Verify Claude can find and read it**

In a fresh Claude Code session:
```
What does the storyteller skill do? Quote its workflow in your own summary.
```
Expected: Claude loads the skill, summarizes the 8-step workflow accurately. Failure mode: Claude claims it does something the workflow doesn't say — that means the description is misleading or the workflow is unclear.

- [ ] **Step 5: Commit**

```bash
git add skill/storyteller/SKILL.md
git commit -m "feat(skill): flesh out 8-step workflow, modes, flags, and failure handling"
```

---

### Task 13: Wire the Postiz publisher step

**Files:**
- Create: `skill/storyteller/references/publish-postiz.md`

- [ ] **Step 1: Write the publisher reference**

Write `skill/storyteller/references/publish-postiz.md`, using EXACT tool name and parameters from `docs/superpowers/notes/postiz-mcp-findings.md`:
````markdown
# Publish — Postiz

Push a Draft to Postiz as a DRAFT (never publish immediately).

## Input

A Draft JSON object (LinkedIn, X, or Instagram — Reels never reaches this step, it's held).

## Rules

- Always push as draft. Reference `docs/superpowers/notes/postiz-mcp-findings.md` for the exact mechanism (flag, status, or far-future date).
- For X threads (`format: thread`), `content` is an array — pass it as the thread sequence per Postiz MCP's thread API.
- For LinkedIn (`format: long-post`), `content` is a single string.
- Instagram captions are HELD in Slice D (`hold: true`) and never reach this step.

## Steps

1. Determine the Postiz integration ID for the draft's `platform`. Cache this once per run (use `integrationList` if needed).
2. Build the request per `postiz-mcp-findings.md` for "create draft".
3. Call the Postiz MCP tool. Capture the returned draft ID.
4. On HTTP-style failure (timeout, 5xx, rate limit), retry once after 5 seconds. On second failure, return `{"status": "failed", "error": "<message>", "draft_json": <the input>}` so the caller can save it to `~/.storyteller/failed-pushes/`.

## Output

For success:
```json
{"status": "ok", "postiz_draft_id": "<id>", "platform": "<platform>"}
```

For failure:
```json
{"status": "failed", "error": "<message>", "draft_json": <the input draft>}
```
````

- [ ] **Step 2: Dry-run test (don't actually push)**

In Claude Code:
```
Read skill/storyteller/references/publish-postiz.md. For the LinkedIn draft in
/tmp/linkedin-draft.json, describe in detail (don't execute) the Postiz MCP call
you would make. Include: tool name, full parameter object, expected return shape.
```
Verify the description matches `postiz-mcp-findings.md`. If it doesn't, tighten the reference.

- [ ] **Step 3: Live test with ONE draft**

In Claude Code:
```
Now actually execute that Postiz MCP call from Step 2. After it returns, give me
the draft ID. Do NOT publish — push as draft only.
```
Verify in Postiz UI: the draft appears under Drafts (not Scheduled, not Published).

- [ ] **Step 4: Clean up the test draft in Postiz UI**

- [ ] **Step 5: Commit**

```bash
git add skill/storyteller/references/publish-postiz.md
git commit -m "feat(skill): wire Postiz publisher with draft-only enforcement"
```

---

### Task 14: Wire the Slack notification and state write

**Files:**
- Create: `skill/storyteller/references/notify-slack.md`
- Create: `skill/storyteller/references/state-write.md`

- [ ] **Step 1: Write the Slack notification reference**

Write `skill/storyteller/references/notify-slack.md`:
````markdown
# Notify — Slack

Send one-line summary DM/channel message via Slack MCP after a run.

## Input

- `count`: int — number of drafts successfully pushed to Postiz
- `top_title`: str — title of the highest-scored signal that produced a draft
- `failures`: list of {signal_id, platform, error} — drafts that failed to push (may be empty)
- `target`: str — Slack user ID or channel ID from config

## Message template

Base message from `notification.slack.template` in config. Default:
```
{count} drafts queued in Postiz. Top: '{top_title}'. /storyteller to review.
```

If `failures` is non-empty, append a second block:
```
⚠ {len(failures)} drafts failed to push. Saved to ~/.storyteller/failed-pushes/.
```

## Steps

1. Substitute `{count}` and `{top_title}` into the template.
2. If failures non-empty, append the warning block.
3. Send via Slack MCP to `target`. Use a DM if `target` starts with `U`; channel post if starts with `C`.

## Output

```json
{"status": "ok"}
```
or `{"status": "failed", "error": "..."}` (state.jsonl is still written even if Slack fails).
````

- [ ] **Step 2: Write the state-write reference**

Write `skill/storyteller/references/state-write.md`:
````markdown
# State Write

Append one entry per successfully-drafted signal to `~/.storyteller/state.jsonl`.

## Input

For each signal that was drafted (at least one format pushed or held):
- `signal_id`: str
- `drafted_at`: ISO 8601 UTC timestamp
- `postiz_draft_ids`: list[str] — IDs returned by Postiz publisher (may be empty if all formats for this signal were held)

## Format

One JSON object per line. Append-only — never rewrite existing lines.

```json
{"signal_id":"github:owner/repo:pr#42","drafted_at":"2026-05-24T08:00:00Z","postiz_draft_ids":["pst_abc","pst_def"]}
```

## Retention pruning

Once per run (before step 8), read the file. Drop entries where `drafted_at` is older than `config.state.retention_days` days ago. Rewrite the file with the surviving entries. This is the ONE exception to append-only.

## Failure handling

If the state file write fails, log to stderr and continue. Better to ship drafts and lose dedupe than to lose drafts. The next run may re-draft already-drafted signals — KK can delete duplicates in Postiz.
````

- [ ] **Step 3: Smoke-test state write**

In a temp dir, manually verify the appendwrite-and-prune logic:
```bash
mkdir -p /tmp/st-test && cat > /tmp/st-test/state.jsonl <<'EOF'
{"signal_id":"a","drafted_at":"2025-01-01T00:00:00Z","postiz_draft_ids":["x"]}
{"signal_id":"b","drafted_at":"2026-05-24T00:00:00Z","postiz_draft_ids":["y"]}
EOF
```
In Claude Code:
```
Read skill/storyteller/references/state-write.md. Apply its retention-prune logic
to /tmp/st-test/state.jsonl assuming retention_days=90 and today is 2026-05-24.
Then append a new entry for signal_id "c" drafted now with postiz_draft_ids ["z"].
Show me the resulting file contents.
```
Expected: entry "a" (Jan 2025) is dropped, "b" survives, "c" appended.

- [ ] **Step 4: Commit**

```bash
git add skill/storyteller/references/notify-slack.md skill/storyteller/references/state-write.md
git commit -m "feat(skill): add Slack notification and state.jsonl write/prune logic"
```

---

## Phase 6 — TDD validation (RED-GREEN-REFACTOR per writing-skills)

### Task 15: RED — baseline scenarios without the skill installed

**Files:**
- Create: `tests/scenarios/red-baseline.md`

This is the "watch the test fail" step. We need to know what generic Claude does before the skill exists so we can verify the skill changes that behavior in Task 16.

- [ ] **Step 1: Uninstall the skill temporarily**

```bash
./scripts/uninstall.sh
```

- [ ] **Step 2: Write the scenarios doc**

Write `tests/scenarios/red-baseline.md`:
````markdown
# RED — Baseline scenarios (skill NOT installed)

For each scenario, dispatch a fresh subagent (or open a new Claude Code session)
with NO StoryTeller skill loaded. Record verbatim what the agent does. We want
to capture the rationalizations and gaps that the skill must close.

## Scenario 1: Direct request, no context

Prompt: "Find me what's worth posting on social media from this week's PRs in
kkmookhey/<your-repo>."

Expected baseline failures (these are what the skill must fix):
- No scoring — agent will dump all PRs without ranking
- No voice fidelity — drafts (if produced) won't pass Jennifer filter
- No multi-format — likely just one generic post
- No Postiz integration — agent will offer to "show you a draft" but not push
- No dedupe — every rerun produces the same drafts

Record actual behavior verbatim in `tests/scenarios/red-baseline-results.md`.

## Scenario 2: Quality pressure

Prompt: "Draft me three LinkedIn posts about this PR: <real PR URL>. Make them
worthy of a Deputy CISO's attention."

Expected baseline failures:
- Generic LinkedIn-influencer voice ("Excited to share...")
- Founder-journey framing
- Missing receipts, abstract claims
- "What do you think?" CTAs

## Scenario 3: Scheduled (headless) intent

Prompt: "I want to set up something that runs every morning and finds me 3 things
worth posting about from my GitHub. What would you do?"

Expected baseline failures:
- Agent invents an architecture (likely suggests a custom app or cron + Python)
- No mention of skills, no mention of Postiz draft pattern
- No source-pluggable design

## Documenting failures

For each scenario, capture in `tests/scenarios/red-baseline-results.md`:
- The exact agent response (verbatim)
- A bullet list of how it violates the StoryTeller design
- Any rationalizations the agent used (e.g., "I'll just give you a generic template")
````

- [ ] **Step 3: Run each scenario and record results**

For each of the 3 scenarios:
1. Open a fresh Claude Code session (or `Task` subagent without the skill loaded)
2. Paste the prompt
3. Copy the agent's full response into `tests/scenarios/red-baseline-results.md` under a labeled section

Write the results file structured like:
```markdown
# RED Baseline Results

## Scenario 1 (...)
### Agent response
<verbatim>

### Violations
- ...

## Scenario 2 (...)
...
```

- [ ] **Step 4: Reinstall the skill**

```bash
./scripts/install.sh
```

- [ ] **Step 5: Commit**

```bash
git add tests/scenarios/red-baseline.md tests/scenarios/red-baseline-results.md
git commit -m "test(red): document baseline behavior without storyteller skill installed"
```

---

### Task 16: GREEN — verify skill compliance on the same scenarios

**Files:**
- Create: `tests/scenarios/green-with-skill.md`

- [ ] **Step 1: Write the GREEN scenarios doc**

Write `tests/scenarios/green-with-skill.md`:
````markdown
# GREEN — Same scenarios, skill installed

Run the same 3 scenarios from RED. Record what changes. For each scenario, the
agent should now exhibit the behavior the skill defines.

## Expectations per scenario

### Scenario 1
- Agent loads the storyteller skill (verbalizes or visibly follows it)
- Agent reads config from ~/.storyteller/config.yaml
- Agent fetches signals via GitHub MCP
- Agent scores using the Jennifer rubric (mentions/cites kk-voice)
- Agent presents top-N in ranked order
- Agent drafts multi-format
- Agent offers to push to Postiz as drafts (does NOT auto-publish without user confirmation)

### Scenario 2
- Agent loads kk-voice before drafting
- Drafts pass structural validation
- Drafts pass the 7-item Jennifer pre-publish checklist (use the voice-judge from Task 8 Step 6)

### Scenario 3
- Agent recommends the storyteller skill itself
- Agent recommends the Cowork scheduled-agent pattern from spec Section 2
- Agent does NOT propose building a separate app or custom Python
````

- [ ] **Step 2: Run each GREEN scenario**

Repeat the 3 RED scenarios in fresh sessions, but WITH the skill installed. Record results in `tests/scenarios/green-with-skill-results.md` mirroring the RED results file structure.

- [ ] **Step 3: Compare RED vs GREEN explicitly**

In `tests/scenarios/green-with-skill-results.md`, for each scenario add a "Compliance" subsection that checks each expected behavior from the doc as ✓ or ✗.

- [ ] **Step 4: If any ✗, proceed to Task 17. If all ✓, mark GREEN passing and skip to Task 18.**

- [ ] **Step 5: Commit**

```bash
git add tests/scenarios/green-with-skill.md tests/scenarios/green-with-skill-results.md
git commit -m "test(green): document skill-installed behavior, compare against baseline"
```

---

### Task 17: REFACTOR — close any loopholes from GREEN failures

**Files:**
- Modify: `skill/storyteller/SKILL.md` (and/or references/)

Only do this task if Task 16 surfaced ✗ items. Otherwise skip to Task 18.

- [ ] **Step 1: For each ✗, identify the loophole**

For each failed expectation, write down: what specifically did the agent do wrong? What in the skill (or absence in the skill) enabled that?

- [ ] **Step 2: Add an explicit counter in SKILL.md**

Append to the "Failure-mode anti-patterns" section of SKILL.md a line for each loophole, in the form:
> Do NOT <verb> <object> — <one-line reason>.

- [ ] **Step 3: Re-run the failing GREEN scenario**

Repeat the scenario that failed, with the updated skill. Verify it now passes.

- [ ] **Step 4: Commit each refactor cycle**

```bash
git add skill/storyteller/SKILL.md
git commit -m "fix(skill): close loophole — <one-line description>"
```

Repeat Steps 1-4 until all GREEN expectations pass.

---

## Phase 7 — End-to-end & acceptance

### Task 18: End-to-end dry-run on a real personal repo

- [ ] **Step 1: Update ~/.storyteller/config.yaml**

Add at least one real personal repo to `sources.github.repos`. Set `notification.slack.target` to your Slack user ID.

- [ ] **Step 2: Run dry-run**

In Claude Code:
```
/storyteller --dry-run
```
Expected behavior:
- Skill loads config
- Fetches PRs via GitHub MCP
- Scores via Jennifer rubric
- Presents top-N ranked
- Generates 4 format drafts for each (LinkedIn, X, Instagram, Reels)
- Shows what it WOULD push to Postiz
- Shows the Slack message it WOULD send
- Does NOT push to Postiz
- Does NOT write to state.jsonl
- Does NOT send Slack

- [ ] **Step 3: Verify nothing was actually pushed**

- Check Postiz UI: no new drafts
- Check `~/.storyteller/state.jsonl`: not modified (compare `wc -l` before and after)
- Check Slack: no DM

- [ ] **Step 4: Document findings**

Note anything surprising or that needs polish. Don't fix yet unless critical — capture as follow-ups for after the acceptance run.

---

### Task 19: End-to-end live run

- [ ] **Step 1: Capture state.jsonl baseline**

```bash
wc -l ~/.storyteller/state.jsonl
```

- [ ] **Step 2: Run live**

In Claude Code:
```
/storyteller
```

In interactive mode, when shown the drafts:
- Verify they render as readable markdown
- Try one edit ("tighten draft 1's hook") — verify regeneration works
- Say "ship it"

- [ ] **Step 3: Verify drafts appeared in Postiz UI**

Open Postiz in your browser. Expected:
- LinkedIn long-post drafts (one per top-N signal) appear in Drafts
- X thread drafts (one per top-N signal) appear in Drafts
- NOTHING is published or scheduled-near-future

- [ ] **Step 4: Verify held content**

```bash
ls ~/.storyteller/pending-video/
```
Expected: Instagram caption + Reels script files, one of each per top-N signal.

- [ ] **Step 5: Verify state and Slack**

```bash
wc -l ~/.storyteller/state.jsonl
```
Expected: `state.jsonl` grew by exactly `top_n` lines.

Check Slack: DM arrived with the configured template.

- [ ] **Step 6: Qualitative check**

Read the top draft. Does it pass the Jennifer filter qualitatively (no banned phrases, real receipts, borrowable, etc.)? If not, capture as a follow-up to refine `drafting-linkedin.md`.

---

### Task 20: Verify rerun dedupe

- [ ] **Step 1: Run /storyteller again immediately**

```
/storyteller
```

- [ ] **Step 2: Verify**

Expected:
- Skill reports either "no new signals" OR processes only signals NOT in state.jsonl
- No duplicates appear in Postiz

- [ ] **Step 3: Acceptance criteria check**

Open `docs/superpowers/specs/2026-05-24-storyteller-slice-d-design.md` Section 10. Tick off each acceptance criterion:
- [ ] `/storyteller --dry-run` produces ranked PRs + multi-format drafts
- [ ] Live `/storyteller` puts LinkedIn + X drafts in Postiz
- [ ] Instagram caption + Reels script appear in `~/.storyteller/pending-video/`
- [ ] Slack notification arrives with top-draft title
- [ ] Rerun within lookback window does not redraft same PRs
- [ ] 3 sample LinkedIn drafts pass Jennifer filter qualitatively
- [ ] Golden-set scoring calibration achieves ≥80% correlation (verified in Task 7)
- [ ] All TDD RED scenarios failed without skill; pass with skill installed (verified in Tasks 15-16)

If any criterion fails, create a follow-up task — do NOT mark Slice D complete.

- [ ] **Step 4: Final commit and tag**

```bash
git add -A
git commit --allow-empty -m "chore(slice-d): acceptance criteria met, ready for daily use"
git tag slice-d-shipped
git push origin main --tags
```

---

## Cleanup checklist

- [ ] All Postiz test drafts deleted from Postiz UI
- [ ] `docs/superpowers/notes/postiz-mcp-findings.md` accurately reflects what worked
- [ ] `~/.storyteller/config.yaml` has your real repos and Slack target (this file is NOT in the repo)
- [ ] `.gitignore` excludes `.superpowers/` (already done)
- [ ] README.md exists at repo root with install/usage instructions (one-screen length; cross-reference the spec for detail)

---

## Out of scope — explicit non-goals for this plan

Per the spec, these are Slice E+ and MUST NOT be built as part of this plan:
- Slack source adapter (read messages as signals)
- Atlassian source adapter (Confluence pages + Jira tickets)
- Instagram caption actual push (needs media)
- Reels video generation (Descript MCP, Slice G)
- Scheduled Cowork mode (Slice H)
- Additional personas beyond KK (Slice I)
