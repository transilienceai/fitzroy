# StoryTeller Slice E Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the storyteller skill with a Slack signal source and an idea-first workflow (top-10 menu → user picks 2-3 → only-then-draft), plus fix the Postiz placeholder date bug surfaced in the Slice D dry-run.

**Architecture:** Same shape as Slice D — markdown bundle at `~/.claude/skills/storyteller/` invoking CLIs and MCPs via Bash. One new reference file (`source-slack.md`), two modified reference files (`publish-postiz.md` date fix + SKILL.md workflow reorder), and one new transient artifact (`~/.storyteller/last-ideas.json`). Slack source uses the existing `mcp__claude_ai_Slack__*` MCP for both reaction-flagged messages (stage 1) and thread-root fallback (stage 2).

**Tech Stack:** Markdown (skill content), YAML (config schema), JSONL (state + idea sidecar), Bash (validators + helper scripts), `mcp__claude_ai_Slack__*` MCP tools, `postiz` CLI (existing).

**Spec reference:** `docs/superpowers/specs/2026-05-25-storyteller-slice-e-design.md`

**Builds on:** Slice D (shipped, dry-run validated end-to-end at commit `71b0249`).

**TDD note for this plan:** Same as Slice D — skills don't have traditional unit tests. The TDD analog is fixture-based structural validation for the source adapter, scenario-based validation for the workflow change, and an end-to-end dry-run for integration. Each task that produces a prompt template includes a fixture-based test step.

---

## File Structure (what we'll touch)

**Create:**
- `skill/storyteller/references/source-slack.md` — Slack source adapter prompt (analogous to existing `source-github.md`)
- `tests/scenarios/source-slack.md` — test specification for the Slack adapter
- `tests/fixtures/slack-search-sample.json` — real fixture captured from Slack MCP probe (Task 1)
- `tests/scenarios/idea-menu.md` — test specification for the idea-presentation step
- `tests/scenarios/pick-parser.md` — test specification for the pick-input parser
- `docs/superpowers/notes/slack-mcp-findings.md` — captured semantics of `slack_search_*` tools

**Modify:**
- `skill/storyteller/SKILL.md` — workflow steps 4-7 reorder (4 keeps top-menu_size, new step 5 presents menu, new step 6 picks, step 7 drafts only picked, steps 8-9 unchanged), still ≤500 words
- `skill/storyteller/sample-config.yaml` — add `sources.slack.min_replies`, `sources.slack.fallback_threshold`, `scoring.menu_size`
- `skill/storyteller/references/publish-postiz.md` — placeholder date changes from `2099-01-01` to `now + 24h`
- `~/.storyteller/config.yaml` (user-level, not committed) — enable `sources.slack`, add channel IDs

**No changes to:**
- All 4 drafter prompts (source-agnostic — they just consume ScoredSignal[])
- `references/scoring-rubric.md` (treats Slack signals identically to GitHub)
- `references/_drafting-shared.md` (cross-format conventions unchanged)
- `references/notify-slack.md` and `references/state-write.md` (unchanged)

---

## Phase 1 — Verification & Slack MCP probe

### Task 1: Probe Slack MCP for reaction-filtered message search

**Files:**
- Create: `docs/superpowers/notes/slack-mcp-findings.md`

The spec's #1 risk: the Slack MCP's `slack_search_public_and_private` may or may not support reaction-count filtering server-side. If it does, the adapter uses one call per channel. If it doesn't, the adapter fetches broader results and filters client-side. We need to know before writing the adapter.

- [ ] **Step 1: List the Slack MCP search/read tools available in this session**

Use ToolSearch with `+slack search` (max_results 8) to enumerate the actual Slack tools loaded. Confirm at least these exist:
- `mcp__claude_ai_Slack__slack_search_public_and_private` (preferred — covers both)
- `mcp__claude_ai_Slack__slack_search_public` (fallback if only public scope)
- `mcp__claude_ai_Slack__slack_read_channel` (used in fallback for recent messages)
- `mcp__claude_ai_Slack__slack_read_thread` (used to enrich thread-root signals)

If any are missing, stop and document which ones — we'll need to adapt the adapter to the available toolset.

- [ ] **Step 2: Read the schema of `slack_search_public_and_private`**

ToolSearch with `select:mcp__claude_ai_Slack__slack_search_public_and_private` to load the full schema. Look for:
- A query field — what syntax does it accept? (Slack search operators like `has:reactions`, `in:#channel`, `after:YYYY-MM-DD`?)
- A filter for reaction count threshold? (server-side filtering avoids fetching low-signal messages)
- Pagination semantics
- Whether results include reaction counts in the response

- [ ] **Step 3: Run a probe query**

KK has at least one Slack workspace connected. Probe with a search like:
```
query: "has::thumbsup: in:#engineering" (substituting a real channel name KK uses)
or
query: "after:2026-05-19 in:<channel>"
```

The intent is to discover:
- Does the search support `has:<reaction>` operators?
- What shape does each result message have? (Reaction counts inline? Permalink? user_id vs display name?)
- Can we filter `after:<date>` for the lookback window?

If KK isn't available to share a channel ID, use any public channel ID visible via `mcp__claude_ai_Slack__slack_search_channels` first.

Capture the JSON shape of one or two real results.

- [ ] **Step 4: Probe thread-root retrieval**

The fallback path needs thread roots. Test:
- Does `slack_read_channel` return reply_count per message?
- Or do we need `slack_read_thread` per message to determine if it's a thread root with N replies?

Capture which call returns reply count without requiring a per-message round-trip.

- [ ] **Step 5: Save fixture**

Save one realistic search result to `tests/fixtures/slack-search-sample.json`. Format the file as a JSON array of 3-5 message objects representing what Stage 1 might return. Include at least one thread root (with reply_count) and one regular message (with reaction_count). Anonymize content if KK's workspace channels have any sensitive details — use placeholder text like `"[redacted customer name]"` if needed.

- [ ] **Step 6: Document findings**

Write `docs/superpowers/notes/slack-mcp-findings.md`:

```markdown
# Slack MCP Findings

## Tool used for reaction-filtered search
- Tool: `mcp__claude_ai_Slack__slack_search_public_and_private` (or whatever the verified primary is)
- Query syntax for "messages with N+ reactions in channel C within last D days":
  - <inline example>
- Server-side filtering supported: yes/no
- If no: client-side filter pattern: <inline example>

## Tool used for thread-root retrieval
- Tool: <name>
- Returns reply_count inline: yes/no
- If no: per-message thread enrichment cost: <O(N) calls>

## Sample result shape
<inline JSON of one realistic message + one thread root>

## Permalink resolution
- Built-in permalink field: yes/no
- If no: how to construct: `https://<workspace>.slack.com/archives/<channel_id>/p<ts-without-dot>`

## Authentication
- KK's Slack MCP is auth'd via OAuth (user-level), scope confirmed: yes/no
- DM channels excluded by default: yes

## Quirks observed
- <any rate limits, pagination defaults, etc.>
```

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/notes/slack-mcp-findings.md tests/fixtures/slack-search-sample.json
git commit -m "docs: capture Slack MCP semantics for storyteller Slack source adapter"
```

---

## Phase 2 — Slack source adapter

### Task 2: Build and validate `references/source-slack.md`

**Files:**
- Create: `skill/storyteller/references/source-slack.md`
- Create: `tests/scenarios/source-slack.md`

This is the format-defining prompt — analogous to `source-github.md` but with Slack-specific stage-1/stage-2 fallback logic.

- [ ] **Step 1: Write the test scenario**

Write `tests/scenarios/source-slack.md`:

```markdown
# Test: source-slack adapter

## Given
Fixture at `tests/fixtures/slack-search-sample.json` — array of raw Slack message objects from the MCP.

## When
The `skill/storyteller/references/source-slack.md` prompt is applied to that fixture (treating it as the Stage 1 reaction-flagged result).

## Then expect
A JSON array of Signal objects, one per qualifying input message (filter: reaction_count >= min_reactions OR — in fallback simulation — reply_count >= min_replies), each with exactly these keys:
- `source` (string, exactly `"slack"`)
- `id` (string, format `slack:<channel_id>:<message_ts>`)
- `url` (string, Slack permalink)
- `title` (string, first 80 chars of message text, single-line, no newlines)
- `summary` (string, 2-4 sentences synthesizing the message + reactions/threadreplies — NOT a verbatim copy)
- `timestamp` (string, ISO 8601, derived from the Slack ts)
- `author` (string, user display name or user_id)
- `raw` (object containing: `channel_id`, `ts`, `reaction_count`, `reactions`, `reply_count`, `text_excerpt`, `is_thread_root`)

## Fall-back behavior expectation
If the input array would produce < `2 * top_n` (=6) qualifying signals at the reaction threshold, the prompt MUST instruct the consumer to perform a Stage 2 fetch (thread roots with replies >= min_replies) and merge+dedupe by `(channel_id, ts)`. The test scenario uses a SIMULATED Stage 2 result also embedded in the fixture.

## Fail conditions
- Missing key on any signal
- `id` doesn't match `slack:<channel>:<ts>` format
- `summary` is a verbatim copy of `text_excerpt`
- Stage 2 not invoked when Stage 1 < 6 signals (logic check)
- Duplicate signals between Stage 1 and Stage 2 results
- Output is not strict JSON

## Validator script

```bash
python3 -c '
import json, re
data = json.load(open("/tmp/source-slack-out.json"))
assert isinstance(data, list), "not a list"
required = {"source","id","url","title","summary","timestamp","author","raw"}
seen_ids = set()
for i, s in enumerate(data):
    missing = required - set(s.keys())
    assert not missing, f"signal {i} missing: {missing}"
    assert s["source"] == "slack", f"signal {i} wrong source"
    assert re.match(r"^slack:[A-Z0-9]+:\d+\.\d+$", s["id"]), f"signal {i} bad id: {s[\"id\"]}"
    assert s["id"] not in seen_ids, f"signal {i} duplicate id: {s[\"id\"]}"
    seen_ids.add(s["id"])
    assert s["raw"]["text_excerpt"] != s["summary"], f"signal {i} summary verbatim"
    raw_keys = {"channel_id","ts","reaction_count","reactions","reply_count","text_excerpt","is_thread_root"}
    missing_raw = raw_keys - set(s["raw"].keys())
    assert not missing_raw, f"signal {i} raw missing: {missing_raw}"
print("PASS:", len(data), "Slack signals validated")
'
```
```

- [ ] **Step 2: Write the prompt template**

Write `skill/storyteller/references/source-slack.md`:

```markdown
# Source: Slack

Normalize raw Slack messages (from `mcp__claude_ai_Slack__slack_search_*` tools) into the StoryTeller Signal shape.

## How to call

For each channel in `config.sources.slack.channels`, perform a two-stage fetch within `lookback_days`:

### Stage 1: reaction-flagged messages

Per `docs/superpowers/notes/slack-mcp-findings.md`, the exact query form depends on what the MCP supports. The general intent:

- Tool: `mcp__claude_ai_Slack__slack_search_public_and_private`
- Filter: messages in channel with reaction count >= `config.sources.slack.min_reactions` (default 3)
- Time window: last `config.sources.slack.lookback_days` days

If the MCP supports `has:<reaction>` query operators server-side, use them. Otherwise fetch all recent messages from the channel via `slack_read_channel` and filter client-side by `reaction_count`.

### Stage 2: thread-root fallback (conditional)

After Stage 1 across all channels, count the resulting signals. If the count is below `config.sources.slack.fallback_threshold` (default = `2 * config.scoring.top_n` = 6), run Stage 2:

- For each channel, fetch recent messages with `slack_read_channel` and filter to thread roots (`reply_count >= min_replies`, default 3)
- Merge Stage 1 + Stage 2 results
- Dedupe by `(channel_id, ts)` — a thread root that was ALSO reaction-flagged counts once
- Mark `raw.is_thread_root: true` on signals that came from Stage 2 (or were thread roots in Stage 1)

### Skip Stage 2 when

- Stage 1 count >= `fallback_threshold` (sufficient signal density)
- All Stage 1 channel queries failed (Stage 2 won't recover from auth/access errors)
- `lookback_days` was 0 (intentional "no Slack this run")

## Per-message transformation

For each qualifying raw message, produce a Signal with these keys:

```json
{
  "source": "slack",
  "id": "slack:<channel_id>:<ts>",
  "url": "<permalink — from message.permalink if present, else constructed per slack-mcp-findings.md>",
  "title": "<first 80 chars of message.text, collapsed to single line (replace \\n with ' '), no trailing ellipsis>",
  "summary": "<2-4 sentence synthesis described below>",
  "timestamp": "<ts converted to ISO 8601 UTC: parseFloat(ts) * 1000 → milliseconds → ISO>",
  "author": "<message.user_profile.display_name if present, else message.username, else message.user>",
  "raw": {
    "channel_id": "<C-prefixed channel id>",
    "ts": "<message.ts as string, e.g. '1716537600.001'>",
    "reaction_count": <sum of reactions[*].count, integer; 0 if no reactions>,
    "reactions": [<distinct reaction emoji names like 'thumbsup', 'fire'; empty list if none>],
    "reply_count": <message.reply_count or 0>,
    "text_excerpt": "<first 500 chars of message.text, preserve newlines>",
    "is_thread_root": <true if reply_count > 0, else false>
  }
}
```

## Summary writing rules

The `summary` is for the scorer. It must:

- Be 2-4 sentences (not bullets, not headings)
- Synthesize: what was said + why the team reacted/replied (e.g., "Customer X closed on the AI-SPM POC after 3 cycles. Thread has 12 replies — engineering walking through the win pattern.")
- Avoid being a verbatim copy of `text_excerpt`
- Avoid restating the title verbatim
- If the message is a thread root, briefly note thread shape (e.g., "8 replies", "team postmortem thread") without deep-reading every reply (deep-thread enrichment is a Slice F concern, not Slice E)
- For Slack-specific edge cases:
  - Bot messages (`message.bot_id` present): include "bot post" framing only if KK's reactions to it are the signal (e.g., team reacting to a Datadog alert with `:fire:`)
  - File-only messages (no text, just attachment): summary describes the file purpose if discernible from `message.files[0].title`, else "file attachment with N reactions"

## Output

Return a strict JSON array of Signals — no prose around it, no markdown fence. Maintain a stable order (Stage 1 first by `ts` desc, then Stage 2 by `ts` desc, deduped).

## Inputs

- `{channels_json}` — list of channel IDs from config
- `{lookback_days}` — integer from config
- `{min_reactions}` — integer (default 3)
- `{min_replies}` — integer (default 3)
- `{fallback_threshold}` — integer (default 2 * top_n = 6)
```

- [ ] **Step 3: Apply the prompt to the fixture**

In your context, read `tests/fixtures/slack-search-sample.json`, apply the transformation rules above (manually walking through Stage 1 + Stage 2 logic), produce the Signal[]. Save to `/tmp/source-slack-out.json`.

- [ ] **Step 4: Run the validator**

Run the validator script from Step 1. Expected: `PASS: <N> Slack signals validated`.

If FAIL: iterate on the prompt template until it passes. Common fixes: tighten the dedupe instructions, sharpen the summary anti-verbatim rule, fix the id-format regex.

- [ ] **Step 5: Commit**

```bash
git add skill/storyteller/references/source-slack.md tests/scenarios/source-slack.md
git commit -m "feat(skill): add Slack source adapter (two-stage fetch with reactions + threads fallback)"
```

---

## Phase 3 — Workflow reorder (idea-first)

### Task 3: Modify SKILL.md workflow steps 4-7

**Files:**
- Modify: `skill/storyteller/SKILL.md`

This is the largest delta — reorder the workflow from "fetch → score → draft all top-N → review" to "fetch → score → present menu → user picks → draft picked → review". Stay under the 500-word SKILL.md cap.

- [ ] **Step 1: Read the current SKILL.md and confirm the cap budget**

```bash
wc -w skill/storyteller/SKILL.md
```

Current is 491 words after Slice D. Target stays ≤500. Budget for new content: 9 words. The reorder must net out near-zero or smaller.

- [ ] **Step 2: Read current step 4 (the one we're modifying first)**

Read the current step 4 to know the exact text being replaced.

- [ ] **Step 3: Replace step 4 with menu-size-keeping version**

Replace step 4 with this version (slightly shorter than the prior "top-N" version):

```
4. **Score** in ONE batched call via `references/scoring-rubric.md` with `kk-voice` loaded. Drop `score < 4`. Sort desc. Keep top `config.scoring.menu_size` (default 10) — the candidate pool for the idea menu. Scoring is one batched call regardless of pool width.
```

- [ ] **Step 4: Insert new step 5 (idea menu) BEFORE the current step 5 (drafting)**

The current step 5 is `**Draft** each top signal in every enabled format...`. Before it, insert:

```
5. **Present idea menu** (interactive mode only). Render the top-`menu_size` signals as a markdown table in chat: index, score, source, title, one-line `why_postworthy`, one-line `suggested_angle`. Also write the same list as JSON to `~/.storyteller/last-ideas.json` so the picker step resolves indices deterministically. **Scheduled mode skips this step** — proceeds directly to step 6 with auto-pick=top-N (`config.scoring.top_n`, default 3) from the candidate pool.

6. **Wait for user pick** (interactive mode only). Accept syntax: indices (`1 5 8`), comma-separated (`1, 5, 8`), verbose (`pick 1 5 8`), signal IDs, or `all`/`none`/`skip`. 1-3 picks proceed; 4-5 warn; >5 require confirmation. Reject invalid indices or unknown IDs with one-line error and re-prompt. **Scheduled mode**: skip this — the auto-pick from step 5 IS the pick.
```

- [ ] **Step 5: Renumber and modify the old steps 5-8 to become 7-9**

The old step 5 (draft) becomes step 7. Old step 6 (interactive review) becomes step 8. Old steps 7-8 (publish + notify) merge into a single step 9.

Final structure after rewrite (verify against the file):

```
1. Load config
2. Fetch signals from enabled sources
3. Dedupe vs state.jsonl
4. Score, drop <4, keep top-menu_size
5. NEW: present idea menu (interactive only)
6. NEW: wait for user pick (interactive only)
7. Draft picked signals (was: draft top-N)
8. Interactive review loop (was step 6)
9. Publish + notify + state (was steps 7+8)
```

The "9" is a small numbering bump from 8 — acceptable.

- [ ] **Step 6: Update the Modes section**

Old text mentions "Interactive: includes step 6. Scheduled: skips step 6." Update to reflect the new structure:

```
## Modes
- **Interactive:** `/storyteller`. Includes steps 5, 6, 8 (menu, pick, review).
- **Scheduled (Cowork):** Skips steps 5, 6, 8. Auto-picks top-N from candidate pool. User reviews in Postiz.
```

- [ ] **Step 7: Update the Flags section**

The `--dry-run` flag semantics change slightly:

```
- `--dry-run`: run 1-7; step 5 still renders menu; step 6 auto-ships first N picks (no user prompt); steps 7-9 skip push/save/state/Slack send.
```

The `--no-postiz` and `--no-notify` flags are unchanged in semantics.

- [ ] **Step 8: Update the Failure-mode anti-patterns section**

Add one new anti-pattern (the others stay):

```
- Do NOT draft BEFORE the user picks in interactive mode — drafting effort is reserved for picked signals only.
```

- [ ] **Step 9: Word count check**

```bash
wc -w skill/storyteller/SKILL.md
```

Target: ≤500 words. If over, tighten by collapsing redundant phrasing in steps 5-6 (the new ones). Pre-Slice-D-revision the file was 491 words; the new steps add ~80 words but the renumber-and-merge of old 5-8 should save ~30. Aim for net +50 = 541 → trim back to ≤500.

If genuinely cannot fit under 500: move the verbose pick-syntax description to a new reference file `references/pick-parser.md` and just reference it from step 6. (Don't do this preemptively — only if word count fails.)

- [ ] **Step 10: Sanity-read the file end-to-end**

Confirm the 9-step flow reads coherently to a fresh reader. Especially: does the interactive-vs-scheduled-mode distinction make sense without re-reading the Modes section?

- [ ] **Step 11: Commit**

```bash
git add skill/storyteller/SKILL.md
git commit -m "feat(skill): reorder SKILL.md workflow to idea-first (top-menu_size + pick + draft-picked)"
```

---

### Task 4: Update sample-config.yaml with new keys

**Files:**
- Modify: `skill/storyteller/sample-config.yaml`

- [ ] **Step 1: Read the current sample config**

- [ ] **Step 2: Enable Slack source (commented placeholder for channels)**

Replace the current `sources.slack` block (which has `enabled: false`) with:

```yaml
  slack:
    enabled: true                  # Slice E
    channels:
      # Add real Slack channel IDs here. Use mcp__claude_ai_Slack__slack_search_channels
      # to find them. KK's commonly-used channels:
      # - C0123456789  # #wins
      # - C0123456790  # #engineering
    lookback_days: 7
    min_reactions: 3               # Stage 1 threshold
    min_replies: 3                 # Stage 2 (thread-root fallback) threshold
    fallback_threshold: 6          # When Stage 1 returns < this, run Stage 2. Defaults to 2 * scoring.top_n.
```

Note: `channels` list is empty by default. KK must add at least one for the slack source to do anything. The skill should detect this and report "Slack source enabled but no channels configured — add channel IDs to ~/.storyteller/config.yaml" in step 1 of the workflow.

- [ ] **Step 3: Add `menu_size` to scoring section**

Update the `scoring` block:

```yaml
scoring:
  rubric: jennifer
  top_n: 3                         # used by scheduled mode auto-pick + post-pick draft count
  menu_size: 10                    # NEW: candidate-pool width for the interactive idea menu
```

- [ ] **Step 4: Verify YAML is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('skill/storyteller/sample-config.yaml')); print('OK')"
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add skill/storyteller/sample-config.yaml
git commit -m "feat(skill): extend sample-config.yaml with Slack source and menu_size"
```

---

### Task 5: Pick parser test scenario

**Files:**
- Create: `tests/scenarios/pick-parser.md`

This is purely a specification — the parser logic lives inside the SKILL.md workflow step 6, and Claude interprets it at runtime. We test by feeding example inputs and verifying the resulting pick set.

- [ ] **Step 1: Write the scenario**

Write `tests/scenarios/pick-parser.md`:

```markdown
# Test: pick-parser (SKILL.md step 6)

## Given
A `last-ideas.json` with 10 ideas indexed 1-10.

## When
The user input is parsed per the rules in SKILL.md step 6.

## Then expect (positive cases)

| Input            | Expected picks (indices) | Confirmation required? |
|------------------|--------------------------|-----------------------|
| `1`              | [1]                      | no                    |
| `1 5 8`          | [1,5,8]                  | no                    |
| `1, 5, 8`        | [1,5,8]                  | no                    |
| `1,5,8`          | [1,5,8]                  | no                    |
| `pick 1 5 8`     | [1,5,8]                  | no                    |
| `Pick 2`         | [2]                      | no (case-insensitive verb) |
| `1 2 3 4`        | [1,2,3,4]                | mild warn (4-5 range) |
| `1 2 3 4 5`      | [1,2,3,4,5]              | mild warn             |
| `1 2 3 4 5 6`    | [1,2,3,4,5,6]            | YES (>5 needs confirm) |
| `all`            | [1..10]                  | YES (mass confirm)    |
| `none`           | []                       | no — exits cleanly    |
| `skip`           | []                       | no — exits cleanly    |
| (empty input)    | []                       | no — treated as `none` |
| `ids slack:C123:1716000000.001` | [signal matched by id] | no |
| `1 ids github:owner/repo:pr#42` | [1, signal-by-id] | no (mixed) |

## Then expect (negative cases — re-prompt with one-line error)

| Input          | Error message |
|----------------|---------------|
| `0`            | "Invalid index 0. Pick between 1 and N." |
| `11`           | "Invalid index 11. Pick between 1 and N." |
| `abc`          | "Unrecognized input 'abc'. Use indices, signal IDs, or all/none/skip." |
| `pick`         | "Empty pick. Use indices or signal IDs after 'pick'." |
| `ids` (no IDs) | "Empty 'ids' list. Append signal IDs." |
| `ids foo`      | "Unknown signal ID 'foo' — not in current menu." |
| `1 1 1`        | "Duplicate indices: 1 appears 3 times." |

## Validation approach

This is interpreted at runtime by Claude reading SKILL.md step 6. To test:

1. Feed Claude a synthetic `last-ideas.json` (10 ideas) and one of the inputs above.
2. Ask Claude to parse the input per SKILL.md step 6 rules.
3. Assert the resulting pick set (or error message) matches the table above.

Run this manually against 3-5 representative inputs as a smoke test, not all 20.
```

- [ ] **Step 2: Commit**

```bash
git add tests/scenarios/pick-parser.md
git commit -m "test(scenario): pick-parser test cases for SKILL.md step 6"
```

---

### Task 6: Idea-menu test scenario

**Files:**
- Create: `tests/scenarios/idea-menu.md`

- [ ] **Step 1: Write the scenario**

Write `tests/scenarios/idea-menu.md`:

```markdown
# Test: idea-menu (SKILL.md step 5)

## Given
A ScoredSignal[] sorted descending by score (top-menu_size = 10 entries, mixing GitHub + Slack sources).

## When
SKILL.md step 5 (render the menu + write JSON sidecar) is executed.

## Then expect (markdown rendering)
A markdown table with exactly these columns: `#`, `Score`, `Source`, `Title`, `Why post-worthy`, `Suggested angle`.

- Row count == min(10, len(input)) — i.e., thin weeks render shorter menus, not padded.
- `#` is 1-indexed.
- `Title` truncated to ~60 chars with ellipsis if longer (keep table readable).
- `Why post-worthy` and `Suggested angle` are single-sentence strings (no newlines).
- The table is preceded by a one-line header: `## Ideas — week of YYYY-MM-DD` (date = today).
- Followed by a one-line instruction: `Pick 2-3 to draft. Reply with indices (e.g., `1 5 8`) or `none` to skip.`

## Then expect (JSON sidecar)
`~/.storyteller/last-ideas.json` exists and matches:

```json
{
  "generated_at": "<ISO 8601 UTC of this run>",
  "ideas": [
    {
      "index": 1,
      "signal_id": "<canonical id matching input>",
      "score": <integer>,
      "why_postworthy": "<full why_postworthy, NOT truncated>",
      "suggested_angle": "<full suggested_angle, NOT truncated>",
      "source": "github" | "slack",
      "title": "<full title, NOT truncated>",
      "url": "<full URL>"
    },
    ...
  ]
}
```

The JSON contains the FULL data (not truncated like the markdown for display).

## Fail conditions
- Markdown table missing any column
- Row count exceeds menu_size (10)
- JSON sidecar not written
- JSON `index` doesn't match the row position in the markdown
- JSON `ideas[].signal_id` doesn't match an input signal_id

## Validation approach

Run via end-to-end dry-run (Task 10). The manual eyeball check is: open `~/.storyteller/last-ideas.json` after a run, confirm 10 entries, confirm indices 1-10 match the markdown row order.
```

- [ ] **Step 2: Commit**

```bash
git add tests/scenarios/idea-menu.md
git commit -m "test(scenario): idea-menu rendering + JSON sidecar"
```

---

## Phase 4 — Postiz date fix

### Task 7: Fix Postiz placeholder date

**Files:**
- Modify: `skill/storyteller/references/publish-postiz.md`

- [ ] **Step 1: Read the current `publish-postiz.md`**

Find the section that mentions the placeholder date `2099-01-01T00:00:00Z`.

- [ ] **Step 2: Replace with `now + 24h` logic**

Replace the Bash invocation example sections (the LinkedIn one and the X thread one) so the `-s` argument is computed:

For LinkedIn:
```bash
# Compute placeholder schedule date (now + 24h, ISO 8601 UTC)
if [[ "$(uname -s)" == "Darwin" ]]; then
  SCHEDULE_DATE=$(date -u -v+24H +"%Y-%m-%dT%H:%M:%SZ")
else
  SCHEDULE_DATE=$(date -u -d "+24 hours" +"%Y-%m-%dT%H:%M:%SZ")
fi

postiz posts:create \
  -c '<escaped content>' \
  -t draft \
  -s "$SCHEDULE_DATE" \
  -i "<integration_id>"
```

For X thread:
```bash
if [[ "$(uname -s)" == "Darwin" ]]; then
  SCHEDULE_DATE=$(date -u -v+24H +"%Y-%m-%dT%H:%M:%SZ")
else
  SCHEDULE_DATE=$(date -u -d "+24 hours" +"%Y-%m-%dT%H:%M:%SZ")
fi

postiz posts:create \
  -c '<post 1>' \
  -c '<post 2>' \
  -c '<post 3>' \
  -d 0 \
  -t draft \
  -s "$SCHEDULE_DATE" \
  -i "<integration_id>"
```

- [ ] **Step 3: Add a "Why now+24h?" note**

Add a short note in the reference file (one paragraph, after the invocation examples):

```markdown
**Why `now + 24h` not a far-future date:**

Postiz Cloud's UI hides drafts dated in the past or far future (out-of-view in the calendar). The far-future placeholder we used initially (`2099-01-01`) caused drafts to be invisible in KK's UI. `now + 24h` puts them in tomorrow's calendar bucket — visible, navigable, and still draft-typed (the `-t draft` flag means they NEVER auto-publish regardless of the schedule date).
```

- [ ] **Step 4: Verify the file ends cleanly (no orphaned references)**

Skim the whole file. Confirm: no other places mention the `2099` date. No prose says "far-future placeholder" without updating.

- [ ] **Step 5: Smoke test the date computation**

```bash
date -u -v+24H +"%Y-%m-%dT%H:%M:%SZ"
```

Expected: an ISO 8601 date approximately 24 hours from now in UTC.

- [ ] **Step 6: Commit**

```bash
git add skill/storyteller/references/publish-postiz.md
git commit -m "fix(publish-postiz): use now+24h placeholder date (Postiz Cloud hides far-future drafts)"
```

---

## Phase 5 — End-to-end validation

### Task 8: User configures Slack channels

**Files:**
- Modify: `~/.storyteller/config.yaml` (user-level, NOT in repo)

This task is a KK action, not an implementer action. Document it here so the plan is complete.

- [ ] **Step 1: KK identifies 1-3 Slack channels to enable**

Suggested channels (from spec section 4.4): customer-win channels, engineering channels, incident postmortem channels. NOT DMs.

- [ ] **Step 2: KK gets channel IDs**

In Slack: right-click a channel → View channel details → at the bottom shows "Channel ID: C0123456789". Or run `mcp__claude_ai_Slack__slack_search_channels` to find them.

- [ ] **Step 3: KK updates `~/.storyteller/config.yaml`**

```yaml
sources:
  slack:
    enabled: true
    channels:
      - C0123456789  # actual channel ID
      - C0123456790  # actual channel ID
    lookback_days: 7
    min_reactions: 3
    min_replies: 3
    fallback_threshold: 6
```

Also add `menu_size: 10` under `scoring:` if it's not already there.

- [ ] **Step 4: Confirm config parses**

```bash
python3 -c "import yaml; print(yaml.safe_load(open(\"$HOME/.storyteller/config.yaml\")))" | grep -A 5 slack
```

Expected output shows the channels list populated.

---

### Task 9: End-to-end dry-run with Slack enabled

- [ ] **Step 1: Run `/storyteller --dry-run`** (or invoke the equivalent skill-following pattern that the Slice D dry-run used)

The implementer subagent should follow the full SKILL.md workflow with these expectations:

- Step 1 reads config and confirms Slack is enabled with channels
- Step 2 fetches signals in parallel from GitHub (gh CLI) AND Slack (MCP tools per source-slack.md)
- Step 3 dedupes vs state.jsonl
- Step 4 scores all signals together, keeps top-menu_size (10), drops <4
- Step 5 renders a markdown menu in the agent's output AND writes `~/.storyteller/last-ideas.json`
- Step 6 (in dry-run) auto-picks the first N (config.scoring.top_n) without user prompt
- Step 7 drafts only the picked signals in all enabled formats
- Steps 8-9 (in dry-run) print what would be pushed/sent without doing it

- [ ] **Step 2: Verify outputs**

Capture each of these in the dry-run report:
- Slack signal count after Stage 1 alone
- Stage 2 invoked? (yes/no based on whether count < 6)
- Mixed-source menu shows both GitHub and Slack entries
- `~/.storyteller/last-ideas.json` exists and has 10 (or fewer, if thin) entries
- Drafted set matches auto-picked top-N
- No drafts produced for non-picked signals (token economy validation)

- [ ] **Step 3: Sanity-check a Slack-sourced draft**

Pick a Slack-sourced signal that made it into the auto-pick. Verify its LinkedIn draft:
- Reads in KK's voice (Jennifer-grade per kk-voice 7-item checklist)
- Doesn't leak Slack-specific framing ("our team reacted to this" — not Jennifer-relevant unless KK is the one teaching the lesson)
- Treats the Slack signal as a "what we observed in our internal channels" angle when appropriate

- [ ] **Step 4: Document the dry-run findings**

Append to `docs/superpowers/notes/slice-e-dryrun.md`:

```markdown
# Slice E Dry-Run Findings

Date: <run date>

## Signal counts
- GitHub: N PRs in last 7 days
- Slack Stage 1: M reaction-flagged messages
- Slack Stage 2 (if invoked): K thread roots
- Merged after dedupe: T total signals
- Above score threshold (>= 4): S
- Top-menu_size kept: min(10, S)

## Auto-picks (scheduled-mode simulation)
- Picked top-N: <ids>
- Drafts produced: <N × formats>

## Voice quality on Slack-sourced drafts
- <one paragraph on whether the LinkedIn/X drafts from Slack signals read naturally>

## Issues / regressions
- <any cascading bugs surfaced>
```

- [ ] **Step 5: Commit if no blockers**

```bash
git add docs/superpowers/notes/slice-e-dryrun.md
git commit -m "docs: capture Slice E dry-run findings (Slack source + idea-menu + auto-pick)"
```

---

### Task 10: Interactive-mode live test

This is a KK action.

- [ ] **Step 1: KK opens a fresh Claude Code session**

So the updated `storyteller` skill description is loaded.

- [ ] **Step 2: KK runs `/storyteller`** (no `--dry-run`)

- [ ] **Step 3: Observe the 10-idea menu**

The skill should:
- Render the top-10 menu (mixing GitHub + Slack signals)
- Pause for input

- [ ] **Step 4: KK picks 2-3 ideas**

Type indices (e.g., `1 5 8`) or signal IDs.

- [ ] **Step 5: Verify drafts produced for picks only**

The skill should produce drafts only for the picked signals. Other signals are NOT drafted. Token cost is proportional to picks.

- [ ] **Step 6: KK reviews drafts in chat**

Optionally requests an edit ("tighten draft 2's hook"). Then says "ship it".

- [ ] **Step 7: Verify Postiz**

Open Postiz Cloud UI. Drafts should appear in TOMORROW's calendar bucket (per Task 7 fix) and be navigable. NO drafts in past dates, no drafts hidden far-future.

- [ ] **Step 8: Verify Slack DM**

KK gets a DM at `U0EXAMPLE01` with the count and top-title template.

- [ ] **Step 9: Verify state.jsonl**

```bash
wc -l ~/.storyteller/state.jsonl
```

Should have grown by exactly the number of picked signals (NOT the number of menu entries — token economy).

- [ ] **Step 10: KK runs `/storyteller` again immediately**

The dedupe step should detect that all picked signals are already in state.jsonl. The menu should now show only NEW signals (or be empty/short if nothing new in the lookback window).

- [ ] **Step 11: Mark Slice E acceptance complete**

If steps 3-10 all pass, Slice E is acceptable. Tag the commit:

```bash
git tag slice-e-shipped
git push origin main --tags
```

---

## Acceptance criteria for Slice E

(Mirror of spec section 10, with tickets to the tasks that prove them)

- [ ] Slack source adapter produces valid `Signal[]` (Task 2 validator)
- [ ] Fallback to threads triggers when Stage 1 returns < `fallback_threshold` (Task 2 logic + Task 9 dry-run)
- [ ] `/storyteller --dry-run` produces a 10-row idea menu mixing GitHub + Slack signals (Task 9)
- [ ] Pick parsing handles all syntax forms and rejects invalid inputs (Task 5 + Task 10 step 4)
- [ ] Drafting cost scales with picks (Task 9 step 2)
- [ ] Postiz drafts visible in Postiz Cloud UI (Task 7 fix + Task 10 step 7)
- [ ] Scheduled mode auto-picks top-N (regression check via Task 9 step 1 dry-run simulating scheduled mode)
- [ ] State.jsonl entries written only for picked signals (Task 9 step 2 + Task 10 step 9)

---

## Out of scope — explicit non-goals for Slice E

Per spec section 1 — these are Slice F+ and MUST NOT be built in this plan:

- Atlassian source (Confluence + Jira)
- Instagram caption push (still held)
- Reels video via Descript
- Additional personas (CTO, FDE, etc.)
- Scheduled-mode rework (preserved as auto-pick top-N; full rework is Slice H)

---

## Risks flagged (mirror of spec section 11)

1. **Slack MCP query semantics** — verified in Task 1 before any adapter work. If `has:<reaction>` operators aren't supported, the adapter fetches broader and filters client-side. Documented in `slack-mcp-findings.md`.

2. **Menu cognitive load** — `menu_size: 10` is the default but configurable down. If KK finds 10 noisy after Slice E ships, dial to 5-7 via config.

3. **Pick step latency** — adds an interactive pause. Total interactive cost: ~3 minutes for a typical 3-pick run. Acceptable.

4. **Scheduled-mode preservation** — Task 9 step 1 explicitly simulates scheduled mode to verify no regression.

5. **Token economy** — Slice E is a net token reduction (drafting 1-3 instead of always 3, but presenting 10 instead of 3). At current usage (pennies per run), this isn't a real constraint.
