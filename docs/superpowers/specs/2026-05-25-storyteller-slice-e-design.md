# StoryTeller — Slice E Design (Spec)

**Date:** 2026-05-25
**Owner:** KK Mookhey
**Status:** Draft — awaiting user review
**Builds on:** [`2026-05-24-storyteller-slice-d-design.md`](2026-05-24-storyteller-slice-d-design.md) (Slice D shipped end-to-end, proven via dry-run)

## 1. Purpose

Two coupled changes to the storyteller skill:

1. **Add Slack as a signal source** alongside GitHub. Exercises the source-pluggable architecture for the first time.
2. **Change the workflow to idea-first selection.** Today's flow is `fetch → score → top-N → draft all → review`. New flow is `fetch → score → top-10 → KK picks 2-3 → draft picked → review`. Drafting effort is only spent on signals KK actually wants to develop.

Also folds in one bug fix surfaced by the Slice D dry-run:

3. **Postiz placeholder date** — `2099-01-01T00:00:00Z` causes Postiz Cloud UI to hide the draft (out-of-view in the calendar). Replace with `now + 24h` so drafts are reachable.

**Success looks like:** KK runs `/storyteller`, sees a 10-idea menu sourced from GitHub PRs + active Slack channels, types `1 5 8`, then sees 3 fully-drafted multi-format candidates in his Postiz inbox within ~60 seconds.

**Out of scope for Slice E** (explicit non-goals):
- Atlassian source (Slice F)
- Instagram caption push (Slice F)
- Reels video generation via Descript (Slice G)
- Scheduled Cowork mode (Slice H) — preserved working as-is (auto-picks top-N, skips idea-selection)
- Additional personas (Slice I)

---

## 2. Architecture Changes

The skill is still a markdown bundle at `~/.claude/skills/storyteller/` invoking CLIs and MCPs via Bash. No new system components.

**New reference file:**
- `references/source-slack.md` — Slack source adapter (analogous to existing `source-github.md`)

**Modified reference files:**
- `SKILL.md` — workflow steps reordered to insert idea-presentation between scoring and drafting
- `references/publish-postiz.md` — placeholder date changes from `2099-01-01T00:00:00Z` to `<now+24h>` ISO 8601

**New transient artifact:**
- The "10-idea menu" — a markdown-rendered table presented in interactive chat, plus a JSON sidecar saved to `~/.storyteller/last-ideas.json` so the picker step has a stable referent

**Slack MCP usage (new):**
The Slack MCP tools we'll use:
- `mcp__claude_ai_Slack__slack_search_public_and_private` to find candidate messages with reactions ≥ threshold within lookback window per channel
- `mcp__claude_ai_Slack__slack_read_channel` to read recent messages from a configured channel (fallback path)
- `mcp__claude_ai_Slack__slack_read_thread` to read thread context when scoring a thread-root signal
- (We do NOT need `slack_send_message` here — that's already wired for notifications)

---

## 3. Revised Workflow (9 steps; was 8)

Changes from Slice D shown inline; unchanged steps quoted briefly.

1. **Load config** *(unchanged)* — also reads new `sources.slack` keys if Slack is enabled.

2. **Fetch signals in parallel** from each `enabled: true` source. Slice E enables `github` AND `slack` (Atlassian still disabled). Each adapter returns `Signal[]`; merge.

3. **Dedupe** vs `state.jsonl` *(unchanged)*.

4. **Score** in ONE batched call via `references/scoring-rubric.md` *(unchanged)*. Drop `score < 4`. Sort desc. **Keep top-`menu_size`** (default 10, configurable). On a thin week with fewer than `menu_size` signals above threshold, present what's available (no padding, no errors — just a shorter menu). Scoring is one batched call regardless of how many we keep; the wider candidate pool just lets KK pick from further down if the highest-scored signals don't excite him today.

5. **(NEW) Present ideas menu.** Render a markdown table of the top-10 signals in chat with: index, score, source, title, one-line `why_postworthy`, one-line `suggested_angle`, URL. Also save the same list as JSON to `~/.storyteller/last-ideas.json` for the picker step. **Scheduled-mode exception:** if invocation is headless (Cowork), skip this step entirely and auto-pick top-N (`config.scoring.top_n`, default 3) so existing scheduled behavior is preserved.

6. **(NEW) Wait for user pick.** Accept flexible input syntax:
   - `1 5 8` (space-separated indices)
   - `1, 5, 8` (comma-separated)
   - `pick 1 5 8` (verbose form)
   - `ids github:owner/repo:pr#42 slack:C123:1234.567` (by signal ID — for power users)
   - `none` or `skip` — exit cleanly with no drafts
   - `all` — draft all 10 (with confirmation: "this will produce 40 drafts; confirm?")
   - 1-3 picks normal; up to 5 picks allowed; > 5 picks asks for confirmation
   Reject empty pick, invalid index, or unknown signal_id with a one-line error and re-prompt.

7. **Draft** picked signals only in every `enabled: true` format per matching `references/drafting-*.md`. (Was step 5 in Slice D.) The drafter precondition stays "score ≥ 4 survived the workflow filter."

8. **(Interactive only)** Render drafts as markdown. Loop on edits ("tighten draft 2 hook", "kill X for 3") until "ship it". *(Was step 6.)* Scheduled mode skips this.

9. **Publish + notify + state** — combines the old steps 7 and 8. Same Postiz CLI invocation, same Slack DM template, same state.jsonl append.

**Net effect for the user:** one extra interactive prompt (the picker) plus a wider initial menu. For the system: drafting cost scales with picks (1-3 typical), not with top-N (always 3). Tokens saved on the 0-2 signals KK skips.

---

## 4. Slack Source Adapter

### 4.1 Two-stage fetch with fallback

**Stage 1 (reactions pass):** for each `channel_id` in `config.sources.slack.channels`, fetch recent messages within `lookback_days` (default 7) whose reaction count ≥ `config.sources.slack.min_reactions` (default 3).

**Stage 2 (threads fallback):** if the merged Stage 1 result across channels has fewer than `2 × config.scoring.top_n` (default 6) signals, run a second pass: fetch thread roots within the same channels and lookback window whose reply count ≥ `config.sources.slack.min_replies` (default 3). Merge with Stage 1, dedupe by `(channel_id, ts)`.

**Why this threshold:** the idea-menu shows 10 items, and we want enough Slack signal to fill the menu alongside GitHub. `2 × top_n` is a heuristic — adjustable if KK finds it noisy.

### 4.2 Signal shape (Slack-specific)

Same normalized `Signal` envelope as Slice D. Slack-specific values:

```yaml
Signal:
  source: slack
  id: slack:<channel_id>:<message_ts>          # e.g., slack:C0123456789:1716537600.001
  url: <permalink to the message>              # via mcp__claude_ai_Slack__... permalink resolution if available, else constructed
  title: <first 80 chars of the message text, single-line>
  summary: <2-4 sentence synthesis of message + (if thread) top reactions/replies — NOT a verbatim copy>
  timestamp: <ISO 8601 of the message>
  author: <user display name OR user_id if name not resolvable>
  raw:
    channel_id: <channel id>
    ts: <message ts>
    reaction_count: <integer>
    reactions: ["thumbsup", "fire", ...]      # emoji names that hit the count
    reply_count: <integer, 0 if not a thread root>
    text_excerpt: <first 500 chars of message body>
    is_thread_root: <bool>
```

### 4.3 What goes in `summary`

The scorer reads `summary` and `raw.text_excerpt`. For Slack, the summary synthesizes:
- The message itself
- For thread roots: the top 1-2 reply themes or notable replies (Slice E doesn't deep-read every reply — costly — just notes "thread of N replies, top theme: X")
- The reaction signal ("3 thumbsup + 2 fire = team thought this was important")

NOT a verbatim copy. Same anti-pattern rule as the GitHub adapter.

### 4.4 Filtering (channel-level)

The adapter respects `config.sources.slack.channels` (allowlist). No global Slack scan — only configured channels. Recommended channel choices for KK: customer-win channels, engineering channels, incident postmortem channels. NOT DMs (the search MCP excludes them by default for safety).

---

## 5. Idea Card Format

### 5.1 Markdown rendering in interactive chat

```markdown
## Ideas — week of 2026-05-25

Pick 2-3 to draft. Reply with indices (e.g., `1 5 8`) or `none` to skip.

| #  | Score | Source       | Title                                                      | Why post-worthy                                              | Suggested angle                                              |
|----|-------|--------------|------------------------------------------------------------|--------------------------------------------------------------|--------------------------------------------------------------|
| 1  | 8     | github       | feat(cme-v2): Slice 2 — rewrite tables for 5 AI frameworks | 65 source-verified rules + 3 named upstream drift bugs       | "Your scanner is lying about which framework you're failing" |
| 2  | 7     | github       | feat(cme-v2): NIST 600-1 GAI-N → 2.N canonical rewrites    | NIST 600-1 GAI-N→2.N + ATLAS v4.7 (12+18 entries)            | "Why your AI compliance dashboard is one rev behind"         |
| 3  | 7     | slack        | "Customer X just closed on the AI-SPM POC..."             | Real customer win, names the product + the deal pattern      | "What sales cycles look like in AI-SPM right now"            |
| ...                                                                                                                                                                                                                                  |
| 10 | 4     | github       | chore(deps): bump axios from 1.6 to 1.7                    | Routine bump; substance unclear without diff                 | "Skip" (low priority)                                        |
```

URLs are not in the table (clutter) but available in `~/.storyteller/last-ideas.json` for reference. The picker can output URLs in confirmation: "Drafting: pr#18 (LinkedIn + X + Instagram + Reels), pr#21 (...), customer-x-win-thread (...)"

### 5.2 JSON sidecar

`~/.storyteller/last-ideas.json` — overwritten each run. Format:

```json
{
  "generated_at": "2026-05-25T08:00:00Z",
  "ideas": [
    {
      "index": 1,
      "signal_id": "github:kkmookhey/ciso-copilot:pr#18",
      "score": 8,
      "why_postworthy": "...",
      "suggested_angle": "...",
      "source": "github",
      "title": "...",
      "url": "https://github.com/..."
    }
  ]
}
```

The picker step reads this to resolve index → signal_id deterministically.

### 5.3 Pick parsing

Pseudo-grammar:
```
pick_input := "all" | "none" | "skip" | pick_list
pick_list  := pick_item ("," pick_item | " " pick_item)*
pick_item  := integer (1-10) | signal_id_string
```

Validation rules:
- `all` requires confirmation (prints "this will produce N × formats drafts; confirm?")
- 1-3 picks: proceed
- 4-5 picks: proceed with mild warning ("drafting N picks will take ~M minutes")
- > 5 picks: requires confirmation (explicit "yes" before drafting)
- Invalid index (< 1 or > 10): error, re-prompt
- Unknown signal_id: error, re-prompt
- Empty pick: treated as `none`

---

## 6. Postiz Date Fix

Per `[[feedback-postiz-future-dates]]` memory: Postiz Cloud UI hides drafts dated in the past or far future. The `2099-01-01T00:00:00Z` placeholder we used in Slice D made drafts invisible in KK's Postiz UI.

**Fix:** In `references/publish-postiz.md`, replace the placeholder generation with `now + 24h` ISO 8601:

```bash
# macOS
SCHEDULE_DATE=$(date -u -v+24H +"%Y-%m-%dT%H:%M:%SZ")
# Linux
SCHEDULE_DATE=$(date -u -d "+24 hours" +"%Y-%m-%dT%H:%M:%SZ")
```

Pass `-s "$SCHEDULE_DATE"` to `postiz posts:create`. Drafts will appear in Postiz's "tomorrow" calendar bucket — visible, navigable, and meaningless (since `-t draft` means they don't auto-publish anyway). The date is just where Postiz indexes them in its UI.

---

## 7. Config Schema Extensions

Existing `~/.storyteller/config.yaml` extends like so:

```yaml
sources:
  github:
    # ... unchanged
  slack:
    enabled: true                  # was false in Slice D
    channels:
      - C0123456789                # add real channel IDs
    lookback_days: 7
    min_reactions: 3               # stage 1 threshold
    min_replies: 3                 # stage 2 fallback threshold
    fallback_threshold: 6          # auto-derived as 2 × scoring.top_n if omitted

scoring:
  rubric: jennifer
  top_n: 3                         # used by scheduled mode + post-pick draft count
  menu_size: 10                    # NEW: how many ideas to present in interactive mode
```

`menu_size` defaults to 10. Configurable so KK can dial it down if 10 feels too many.

---

## 8. Failure Handling

### 8.1 Slack source failures
- Channel not accessible (permission error): log to stderr, skip that channel, continue with others
- Slack MCP timeout: retry once with 5s backoff; on second failure, skip this source entirely and continue with GitHub-only
- All Slack channels fail: log a warning in the Slack notification ("Slack source unavailable this run")
- Fewer than `2 × top_n` reaction-flagged messages: fall back to threads (designed behavior, not a failure)
- Fewer than `top_n` signals total across both stages: present what you have, don't error

### 8.2 Idea-pick failures
- User types garbage: re-prompt with the syntax help
- User picks nothing (`none`): exit with "no drafts produced this run" message + Slack notification with `{count}: 0`
- User picks more than `menu_size`: error ("there are only N ideas; you picked indices outside that range")

### 8.3 Scheduled mode
- No interactive prompt available → skip step 5 (idea menu), skip step 6 (picker), auto-select top-N from config — IDENTICAL to Slice D scheduled behavior. The only visible difference is the order signals are processed: in Slice E scheduled mode still keeps top-N from the larger candidate pool (now top-10 sorted-by-score is just sliced to top-N).

---

## 9. Testing

### 9.1 Slack adapter tests
- Fixture: a synthetic Slack response with messages at various reaction counts + thread depths
- Validate the adapter produces correct Signal[] for: messages above threshold, thread roots above threshold, messages below threshold (excluded), edge cases (0 reactions, 1 reply)
- Validate the fallback trigger fires when stage 1 returns < 6 signals
- Validate dedupe between stages (a thread root that's also reaction-flagged appears once)

### 9.2 Idea-menu and picker tests
- Render-correctness: 10-row markdown table matches the JSON sidecar
- Pick parsing: cover all syntax forms (indices, commas, verbose, signal_ids, all/none/skip, confirmation flows)
- Edge cases: 0 signals (no menu, exit gracefully), 1-9 signals (smaller menu), > 10 signals (top-10 only)

### 9.3 End-to-end dry-run
- Configure Slack source with one real channel, GitHub still enabled
- `/storyteller --dry-run` produces a 10-idea menu mixing both sources
- Pick 2-3 ideas, verify only those are drafted (token economy)
- Verify scheduled mode still auto-picks top-N (regression check on Slice D headless behavior)

### 9.4 Postiz date fix verification
- Live `postiz posts:create` with new `now + 24h` date — verify the draft appears in Postiz UI's calendar (visible, not hidden)

---

## 10. Acceptance Criteria for Slice E

- [ ] Slack source adapter produces valid `Signal[]` for configured channels (verified via fixture)
- [ ] Fallback to threads triggers when Stage 1 returns < 6 signals (verified via threshold test)
- [ ] `/storyteller --dry-run` produces a 10-row idea menu mixing GitHub + Slack signals
- [ ] Pick parsing handles indices, signal_ids, all/none/skip, and rejects invalid inputs
- [ ] Drafting cost scales with picks (1-3 typical = 4-12 drafter calls instead of always 12)
- [ ] Postiz drafts visible in Postiz Cloud UI after the date fix (KK eyeballs)
- [ ] Scheduled mode (simulated by running without TTY check) auto-picks top-N — Slice D regression check
- [ ] State.jsonl entries written only for drafted (picked) signals, not for skipped ones

---

## 11. Risks Flagged Up Front

1. **Slack MCP search semantics** — the Slack MCP's `slack_search_public_and_private` may or may not support reaction-count filtering directly. **First task in the plan: verify by inspecting the MCP tool schema and running a probe call.** If reaction-count isn't a server-side filter, the adapter will fetch broader results and filter client-side (still works, just more tokens).

2. **Menu cognitive load** — 10 ideas may be too many to scan. The `menu_size` config knob is the mitigation; if KK finds 10 noisy in practice, dial down to 5-7.

3. **Pick step latency** — the dry-run showed scoring + presentation in ~30-60 seconds. The picker step adds an interactive pause (KK's reading time). Drafting then takes another ~30s per picked signal × N picks. Total interactive cost may be 2-3 minutes for a typical 3-pick run. Acceptable but worth measuring.

4. **Scheduled-mode behavior preserved** — the auto-pick top-N path is preserved as-is so Slice H (cron scheduling) can land without further workflow rework. Verify this regression doesn't break.

5. **Token economy isn't a real concern at current scale** — we're already trimming drafting effort from "always 12 drafts" to "drafts for 1-3 picks." Whichever way scaling goes, this is a net reduction. Don't over-optimize.

---

## 12. Open Questions for Implementation Plan

The writing-plans phase should resolve these:

1. Exact Slack MCP tool to query for reaction-filtered messages (probe first task)
2. Permalink resolution for Slack signal URLs (MCP-supported or constructed from channel + ts?)
3. Exactly how to detect "interactive mode vs scheduled mode" inside the skill — TTY check? Explicit flag from invocation? Cowork harness env var?
4. Exact pseudo-code for the pick-input parser (regex + validation)
5. Whether `last-ideas.json` should retain history (N most recent menus) or be ephemeral (only the most recent)

---

## 13. Dependencies

**External (must exist):**
- Slack MCP configured and authenticated with read scope on the channels KK lists in config
- All Slice D dependencies (gh CLI, postiz CLI + key, kk-voice + kk-short-form skills)

**Internal (Slice D shipped):**
- `skill/storyteller/SKILL.md` (workflow being modified)
- `skill/storyteller/references/source-github.md` (pattern for new Slack adapter)
- `skill/storyteller/references/scoring-rubric.md` (unchanged, processes both sources uniformly)
- `skill/storyteller/references/_drafting-shared.md` (unchanged)
- `skill/storyteller/references/publish-postiz.md` (date fix only)
- All 4 drafter prompts (unchanged — they're source-agnostic)
