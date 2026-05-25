# StoryTeller — Slice D Design (Spec)

**Date:** 2026-05-24
**Owner:** KK Mookhey
**Status:** Draft — awaiting user review
**Slice scope:** End-to-end thin vertical slice — GitHub signal source, KK persona only, drafts pushed to Postiz (LinkedIn + X), Instagram caption + Reels script generated and held locally for later video slice.

---

## 1. Purpose

Build a local automation that turns recent product/company activity into ranked, persona-flavored social media drafts pushed to Postiz for review and publishing. Slice D demonstrates the full loop with one signal source (GitHub) wired up, while establishing the source-pluggable architecture so later slices can add Slack, Atlassian, Gmail, Teams, etc. without rework.

**Success looks like:** KK runs `/storyteller` (or it runs on a daily Cowork schedule), sees three ranked drafts for LinkedIn + X in Postiz within ~60 seconds, edits them in Postiz if he wants, and publishes the ones he likes. Nothing auto-publishes. Voice fidelity is enforced by the existing `kk-voice` and `kk-short-form` skills, which are the single source of truth for KK's voice.

**Out of scope for Slice D** (named for clarity — these come in later slices):
- Slack, Confluence, Jira, Gmail, Teams, HubSpot signal sources
- Video generation via Descript MCP
- Additional personas (CTO, FDE, Product Engineer, Sales)
- Instagram caption publishing (held until paired with media)
- YouTube publishing (held until video slice via Descript)

---

## 2. Architecture

StoryTeller is a **Claude Code skill** (`storyteller`) installed at `~/.claude/skills/storyteller/`. It is not a web app. There is no frontend, no backend server, no custom auth.

The skill is invoked two ways:

1. **Interactive** — `/storyteller` in Claude Code or Claude Desktop. Review/edit happens conversationally as markdown rendered in the chat.
2. **Scheduled** — A scheduled remote agent (Cowork-style) runs the same skill headlessly on a cadence (e.g., daily 8am), drops drafts into Postiz, pings Slack with a one-line summary. No human in the loop until KK opens Postiz to review.

**Slice D scope clarification:** The skill is *architecturally* runnable in both modes from day one — the same `storyteller` code paths work whether invoked interactively or headlessly. However, Slice D only ships the interactive invocation; operationally enabling the daily Cowork schedule (cron config, headless-agent prompt, Slack notification routing) is Slice H. Slice D acceptance criteria only test interactive invocation.

The skill orchestrates these MCPs (assumed already connected and authenticated in KK's environment):

| MCP | Purpose in Slice D | Slice D status |
|---|---|---|
| GitHub MCP | Read merged PRs from configured personal repos | Active |
| Postiz MCP | Push drafts (never auto-publish) | Active |
| Slack MCP | Send "drafts ready" notification | Active |
| Slack MCP (read) | Read messages from configured channels as signals | Held for Slice E |
| Atlassian MCP | Read Confluence pages + Jira tickets as signals | Held for Slice E |
| Descript MCP | Text → video → YouTube/Reels publishing | Held for Slice G |

The skill loads two existing skill bundles as voice authorities:

- **`kk-voice`** — Jennifer Chen filter for scoring; KK's voice rules for drafting
- **`kk-short-form`** — Reels/Shorts script structure for vertical video

**Source-pluggability is a first-class design property.** Each signal source returns the same normalized `Signal` shape. The scoring, ranking, and drafting steps are source-agnostic. Adding Teams, Gmail, RSS, etc. = write one source adapter, nothing downstream changes.

---

## 3. Components & Data Flow

Eight components run in one linear pass per invocation:

```
config.yaml ──▶ [1] ConfigLoader
                  │
                  ▶ [2] SignalFetchers (parallel; Slice D = GitHub only)
                  │       └── GitHubSource → Signal[]
                  ▼
                  [3] Deduplicator ── reads state.jsonl, drops already-drafted signals
                  ▼
                  [4] Scorer ── one batched Claude call; applies Jennifer rubric
                                  returns [{signal_id, score, why, angle}, …]
                  ▼
                  [5] Ranker+Cutoff ── sort desc by score, keep top-N (config; default 3)
                  ▼
                  [6] Drafter ── per top signal, generate per enabled format:
                                  • LinkedIn long-post (kk-voice)
                                  • X thread (kk-voice)
                                  • Instagram caption (kk-voice; held locally)
                                  • Reels script (kk-short-form; held locally)
                  ▼
                  [7] PostizPublisher ── push LinkedIn + X drafts as DRAFTS only
                                          held content → ~/.storyteller/pending-video/
                  ▼
                  [8] SlackNotifier ── one DM summary
                  ▼
                  StateWriter ── append signal IDs to state.jsonl
```

### 3.1 Signal shape

```yaml
Signal:
  source: github | slack | atlassian       # extensible
  id: stable unique id (e.g., "github:user/repo:pr#42")
  url: canonical link
  title: short headline
  summary: 2-4 sentence digest
  timestamp: ISO 8601
  author: optional
  raw: source-specific blob (PR diff stats, Slack thread, etc.)

ScoredSignal = Signal + {score, why_postworthy, suggested_angle}
```

### 3.2 Draft shapes

**Three audiences, three representations:**

| Audience | Format |
|---|---|
| Skill internals (piping between steps) | JSON envelope |
| KK in interactive Claude Code | Markdown rendering of the JSON's content fields |
| Postiz API | Plain text extracted from `content` field |

**LinkedIn (single post):**
```json
{
  "platform": "linkedin",
  "format": "long-post",
  "content": "Plain text with \\n line breaks.",
  "hashtags": ["#cybersecurity", "#aisecurity"],
  "internal_notes": "Which Jennifer-filter criteria this hits hardest"
}
```

**X (thread):**
```json
{
  "platform": "x",
  "format": "thread",
  "content": ["Post 1", "Post 2", "Post 3"],
  "hashtags": ["#cybersecurity"],
  "internal_notes": "..."
}
```

**Instagram caption** (held in Slice D; pairs with media in Slice F):
```json
{
  "platform": "instagram",
  "format": "caption",
  "content": "Caption body...\\n\\n.\\n.\\n.\\n\\n#cybersecurity",
  "hashtags": [],
  "internal_notes": "Pairs with Reels video when generated"
}
```

**Reels script** (held in Slice D; hydrated to video in Slice G):
```json
{
  "platform": "reels",
  "format": "script",
  "content_markdown": "# TITLE\\n\\n[00:00–00:03] HOOK\\nVO: ...\\nText: ...\\nVisual: ...",
  "caption_for_post": "Instagram/YouTube Shorts caption for when video uploads",
  "hashtags": ["#cybersecurity", "#scamalert"],
  "video_pending": true,
  "internal_notes": "kk-short-form Meera/Rohan template indicated"
}
```

### 3.3 What enters Postiz in Slice D

- LinkedIn long-post ✓ (content string)
- X thread ✓ (content array)
- Instagram caption ✗ (held — needs media)
- Reels script ✗ (held — needs video)

---

## 4. On-Disk Layout

```
~/.claude/skills/storyteller/        ← skill bundle (read-only after install)
├── SKILL.md                          ← entry point
├── sample-config.yaml                ← template, copied to user dir on first run
└── references/                       ← prompt templates, loaded on demand
    ├── scoring-rubric.md
    ├── source-github.md
    ├── drafting-linkedin.md
    ├── drafting-x-thread.md
    ├── drafting-instagram.md
    └── drafting-reels.md

~/.storyteller/                       ← user-writable state and config
├── config.yaml                       ← user settings
├── state.jsonl                       ← append-only drafted-signal log
├── pending-video/                    ← Reels scripts + Instagram captions awaiting video
└── failed-pushes/                    ← drafts whose Postiz push failed (for retry)

~/.claude/skills/kk-voice/            ← pre-existing dependency
~/.claude/skills/kk-short-form/       ← pre-existing dependency
```

---

## 5. `~/.storyteller/config.yaml` Schema

```yaml
sources:
  github:
    enabled: true
    repos:                            # user-configurable
      - kkmookhey/repo-a
      - kkmookhey/repo-b
    only_authored_by_me: false        # if true, ignore PRs not opened by KK
    lookback_days: 7

  slack:                              # disabled in Slice D; structure shown for Slice E continuity
    enabled: false
    channels: []
    lookback_days: 7
    min_reactions: 3

  atlassian:                          # disabled in Slice D
    enabled: false
    confluence_spaces: []
    jira_jql: "status = Done AND updated >= -7d AND labels in (release, feature)"

scoring:
  rubric: jennifer                    # only rubric in Slice D
  top_n: 3                            # how many signals to draft

drafting:
  formats:
    - { platform: linkedin,  format: long-post, enabled: true }
    - { platform: x,         format: thread,    enabled: true }
    - { platform: instagram, format: caption,   enabled: true, hold: true }
    - { platform: reels,     format: script,    enabled: true, hold: true }

publishing:
  postiz:
    push_as_draft: true               # ALWAYS true — never auto-publishes
    workspace_id: null                # optional, for multi-workspace Postiz accounts

notification:
  slack:
    target: U0123456789               # DM yourself; channel ID also works
    template: "{count} drafts queued in Postiz. Top: '{top_title}'. /storyteller to review."

state:
  retention_days: 90                  # prune drafted-signal log older than this
```

### 5.1 `~/.storyteller/state.jsonl` format

Append-only, one JSON object per line:

```json
{"signal_id":"github:kkmookhey/repo-a:pr#42","drafted_at":"2026-05-24T08:00:00Z","postiz_draft_ids":["pst_abc","pst_def"]}
```

Postiz remains authoritative for "what was actually posted vs is still a draft." This log only tracks "we drafted about this signal already, don't redraft."

---

## 6. SKILL.md Authoring Constraints

The `storyteller` SKILL.md MUST comply with `superpowers:writing-skills`:

1. **Frontmatter description** is triggering conditions ONLY — not a workflow summary. Workflow summaries in descriptions cause Claude to follow the description instead of the full skill body.

   **Approved description** (triggering conditions only — no workflow verbs like "ranks", "scores", "drafts"):
   > Use when KK wants to surface recent newsworthy product or company activity for social media posting. Triggers on /storyteller, "find me post ideas", "what's worth posting this week", "anything good from this week's PRs", scheduled Cowork runs, or any request to identify content-worthy moments from GitHub, Slack threads, or Confluence/Jira updates.

2. **SKILL.md ≤500 words.** The 8-step workflow is numbered single-sentence steps. Per-step detail lives in `references/`.

3. **Cross-references use skill names with REQUIRED markers**, never `@` links:
   - `**REQUIRED VOICE SKILL:** kk-voice — load before any drafting step`
   - `**REQUIRED FORMAT SKILL:** kk-short-form — load before drafting reels`
   - `**REQUIRED BACKGROUND:** superpowers:test-driven-development`

4. **Skill name** uses letters, numbers, hyphens only: `storyteller`.

5. **Heavy reference moved to separate files** in `references/` — scoring rubric prompt, per-source instructions, per-format drafting prompts.

---

## 7. SKILL.md Workflow (numbered, ≤500 words)

```markdown
---
name: storyteller
description: Use when KK wants to surface recent newsworthy product or company activity for social media posting. Triggers on /storyteller, "find me post ideas", "what's worth posting this week", "anything good from this week's PRs", scheduled Cowork runs, or any request to identify content-worthy moments from GitHub, Slack threads, or Confluence/Jira updates.
---

# StoryTeller — Signals → Ranked Drafts → Postiz

**REQUIRED VOICE SKILL:** kk-voice — load before any scoring or drafting step.
**REQUIRED FORMAT SKILL:** kk-short-form — load before drafting reels/shorts.

## Prerequisites
- MCPs configured: GitHub, Postiz, Slack (write)
- Config exists at ~/.storyteller/config.yaml (if missing, copy sample-config.yaml and pause for user to fill repos)

## Workflow

1. **Load config** from ~/.storyteller/config.yaml. If missing, initialize from sample and stop.
2. **Fetch signals** from each enabled source in parallel using references/source-<name>.md. Each returns Signal[].
3. **Dedupe** against ~/.storyteller/state.jsonl. Drop signals already drafted.
4. **Score+rank** remaining signals in ONE batched call using references/scoring-rubric.md. Keep top-N from config.
5. **Draft** each top signal in every enabled format using the matching references/drafting-*.md.
6. **(Interactive mode only)** Show ranked drafts. Loop on edits ("tighten draft 2 hook", "kill X for draft 3") until user says ship.
7. **Push drafts** to Postiz with push_as_draft=true. Save `hold: true` content to ~/.storyteller/pending-video/.
8. **Notify Slack** with template. **Append signal IDs** to state.jsonl.

## Modes
- **Interactive:** /storyteller invocation. Includes step 6 (iterate-on-drafts loop).
- **Scheduled (Cowork):** Skips step 6 entirely. User reviews in Postiz.

## Failure handling
- Source MCP error → log, continue with remaining sources.
- Postiz push fail → retry once, then move to ~/.storyteller/failed-pushes/, flag in Slack notification.
- Malformed scoring JSON → retry once with stricter prompt; on second fail, fall back to chronological order and flag in Slack.

## Flags (CLI / prompt args)
- `--dry-run` — run pipeline; skip Postiz push, state write, Slack notify
- `--source <name>` — restrict to one source for debugging
- `--no-postiz` — generate drafts but don't push
- `--no-notify` — skip Slack
```

---

## 8. Key Prompts (in `references/`)

### 8.1 `references/scoring-rubric.md`

Sketch — full file lives in the skill bundle, not in this spec:

```
You are scoring potential social-media-post candidates against KK Mookhey's
Jennifer Chen filter (defined in kk-voice skill — load if not already loaded).

For each Signal below, return JSON:
{ "signal_id": "...", "score": <1-10>, "why_postworthy": "<one sentence>",
  "suggested_angle": "<one sentence>" }

Scoring rubric (each 0-2):
- Specific operational substance (named tools, numbers, concrete scenario)
- Borrowable insight (Jennifer can paraphrase in her next meeting)
- Receipts vs generalities
- Operator voice (not founder-journey)
- Problem-before-product (if Transilience appears)

Score = sum, capped at 10.
Score=0 for: internal/HR/admin, customer-confidential without extractable lesson,
India/ME-only with no universal lesson, "excited to announce" material.

Return strictly a JSON array. No prose.
Signals: {signals_json}
```

### 8.2 `references/drafting-linkedin.md`

Sketch:

```
Draft a LinkedIn long-form post for KK Mookhey.

VOICE: Apply kk-voice skill including Jennifer pre-publish checklist.
Must pass all 7 Jennifer filter checks.

INPUT: Signal + score + suggested_angle

STRUCTURE:
- Hook (1-2 lines) names Jennifer-relevant stakes before "see more" fold
- Body: receipts first; named tools, numbers, concrete scenario. 150-280 words.
- Generalized lesson line Jennifer can borrow.
- No "excited to announce"; no founder-journey; no India-first framing.
- If Transilience appears: problem in first 80%, solution in last 20%.

OUTPUT (JSON only):
{ "platform": "linkedin", "format": "long-post", "content": "<post>",
  "hashtags": [...], "internal_notes": "<which Jennifer criteria hit hardest>" }
```

Equivalent prompts exist for X thread, Instagram caption, Reels script. All delegate voice to `kk-voice` / `kk-short-form`. None contain voice rules — single source of truth stays in those skills.

---

## 9. Testing Approach

Skills don't have traditional unit tests. Testing is:

1. **Dry-run mode** — `--dry-run` runs the full pipeline without pushing/writing state. Safe for repeated runs against real data.
2. **Source isolation flags** — `--source github`, `--no-postiz`, `--no-notify`.
3. **TDD per `superpowers:writing-skills`** — RED-GREEN-REFACTOR with subagent scenarios. **REQUIRED BACKGROUND:** `superpowers:test-driven-development`.
   - **RED scenarios** (run baseline without skill installed):
     - "Find me what's worth posting from my GitHub this week" — should fail with no scoring, no voice fidelity, no Postiz integration.
     - "Draft a LinkedIn post about this PR: <url>" — should produce generic LinkedIn content that fails Jennifer filter.
     - Scheduled run scenario: spawn subagent in headless mode and verify it doesn't interactively prompt.
   - **GREEN:** install skill, re-run scenarios, verify compliance.
   - **REFACTOR:** capture any rationalizations or loopholes in a table within SKILL.md; re-test until bulletproof.
4. **Golden-set scoring calibration** *(one-time setup task at install)* — KK hand-rates 15-20 past PRs/messages on 1-10 Jennifer-fit. Run through scorer; check correlation. Tighten rubric if scores diverge sharply. Target ≥80% correlation.
5. **Draft voice fidelity check** — second Claude call judges any draft against the kk-voice Jennifer 7-item pre-publish checklist. Returns pass/fail per criterion. Cheap; surfaces regressions when drafting prompts change.
6. **Source adapter fixtures** — for each source, save a real MCP response as a fixture; assert the adapter normalizes it correctly into the Signal schema.

---

## 10. Acceptance Criteria for Slice D

- [ ] `/storyteller --dry-run` produces ranked PRs + multi-format drafts for at least one real personal repo
- [ ] Live `/storyteller` puts LinkedIn + X drafts in Postiz, verifiable in Postiz UI
- [ ] Instagram caption + Reels script appear in `~/.storyteller/pending-video/`
- [ ] Slack notification arrives with top-draft title
- [ ] Rerun within lookback window does not redraft same PRs (dedupe via state.jsonl)
- [ ] KK reviews 3 sample LinkedIn drafts and confirms they pass Jennifer filter qualitatively
- [ ] Golden-set scoring calibration achieves ≥80% correlation
- [ ] All TDD RED scenarios fail without skill; pass with skill installed

---

## 11. Slice Rollout Plan

| Slice | Scope | Effort |
|---|---|---|
| **D (this spec)** | GitHub source • Jennifer scoring • LinkedIn + X to Postiz • Instagram + Reels held locally • Slack notify • State tracking • Dry-run | ~1-2 days |
| **E** | + Slack source + Atlassian (Confluence + Jira) source — proves source-pluggability | ~half day |
| **F** | + Instagram caption push (paired with image) | ~half day |
| **G** | + Descript MCP: Reels script backlog → video → YouTube/Reels | ~2 days |
| **H** | + Scheduled Cowork mode: daily run, phone-review workflow | ~half day |
| **I** | + More personas (CTO, FDE, Product Engineer with their own voice skills) | depends on voice skills |
| **J** | + More sources (Teams, Gmail, HubSpot, RSS) | ~half day each |

---

## 12. Risks Flagged Up Front

1. **Postiz MCP draft semantics unverified.** Postiz MCP exposes 8 tools (`integrationList`, `integrationSchema`, `triggerTool`, `schedulePostTool`, `generateImageTool`, `generateVideoOptions`, `videoFunctionTool`, `generateVideoTool`). We assume `schedulePostTool` supports an explicit draft mode. **First task in the implementation plan is verifying this by inspecting the actual MCP tool schema.** If draft mode requires a scheduled-far-future workaround, the design accommodates it but we need to know upfront.

2. **Scoring accuracy is empirical until calibrated.** The Jennifer rubric is principled, but Claude's interpretation of "Jennifer-worthy" varies. The golden-set calibration (acceptance criterion) is the de-risking step. Plan time for one iteration on the rubric prompt after first calibration run.

3. **Reels script quality without video context.** `kk-short-form` is comprehensive for actual video work, but drafting a Reels script from a GitHub PR diff requires imagination. Expect to refine `drafting-reels.md` based on what produces usable videos once the Descript slice (G) lands.

4. **Token cost is negligible.** One batched scoring call + (top_n × enabled formats) drafting calls per run. With defaults (top_n=3, 4 formats) = 13 calls per run. At current Sonnet 4.6 pricing for a few thousand tokens per call, this is pennies per invocation. Not a real constraint.

5. **Skill discoverability for scheduled mode.** Scheduled Cowork agents may not auto-load skills the same way an interactive Claude Code session does. **Verify this during Slice H** (scheduled mode) and adjust SKILL.md description or scheduled-agent prompt as needed.

---

## 13. Open Questions for Implementation Plan

The writing-plans phase should resolve these before coding:

1. Exact Postiz MCP tool to use for "create as draft" (vs schedule) — read tool schema first.
2. GitHub MCP behavior for "merged PRs across N repos in last D days" — single query vs N queries?
3. Where exactly does the Reels script live on disk in `~/.storyteller/pending-video/` — one file per signal, or one per format-per-signal?
4. Should `state.jsonl` track Postiz draft IDs so we can update existing drafts on rerun (vs duplicate)?
5. What's the install/setup story — manual file copy, install script, packaged `.skill` zip like `kk-voice.skill`?

---

## 14. Dependencies

**External (must exist in KK's environment before install):**
- Claude Code or Claude Desktop with skill support
- GitHub MCP server configured and authenticated
- Postiz account + MCP server configured and authenticated
- Slack MCP server configured (write permission to DM target)

**Internal (KK's existing assets):**
- `kk-voice` skill installed at `~/.claude/skills/kk-voice/`
- `kk-short-form` skill installed at `~/.claude/skills/kk-short-form/`

**Held for later slices:**
- Slack MCP read permission (Slice E)
- Atlassian MCP (Slice E)
- Descript MCP (Slice G — KK confirmed already installed)
