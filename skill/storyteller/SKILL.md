---
name: storyteller
description: Use when KK wants to surface recent newsworthy product or company activity for social media posting. Triggers on /storyteller, "find me post ideas", "what's worth posting this week", "anything good from this week's PRs", scheduled Cowork runs, or any request to identify content-worthy moments from GitHub, Slack threads, or Confluence/Jira updates.
---

# StoryTeller — Signals to Ranked Drafts to Postiz

Orchestrate the pipeline. Detail lives in `references/`.

## Workflow

1. **Load config** `~/.storyteller/config.yaml`. Stop if `sources.github.repos` empty OR `publishing.postiz.integrations.linkedin`/`.x` empty; report what's missing.
2. **Fetch signals in parallel** from each `enabled: true` source per `references/source-<name>.md` (Slice D = `github` only). Merge into one `Signal[]`.
3. **Dedupe** vs `~/.storyteller/state.jsonl`: drop signals whose `id` already appears. Prune entries older than `config.state.retention_days` (default 90).
4. **Score** in ONE batched call via `references/scoring-rubric.md` with `kk-voice` loaded. Drop `score < 4`. Sort desc. Keep top-N from `config.scoring.top_n`.
5. **Draft** each top signal in every `enabled: true` format per matching `references/drafting-*.md`. On `status: "error"` with routing hint, log and continue; without one, save input to `~/.storyteller/failed-pushes/<signal_id>-<format>.json`.
6. **Interactive only:** render ranked drafts in chat. Loop on edits ("tighten draft 2 hook", "kill X for 3", "redraft 1") until "ship it". Scheduled mode skips this step.
7. **Publish:** for each NOT `hold: true`, invoke Postiz CLI to create a **draft** (never published) per `references/publish-postiz.md` (Task 13). For `hold: true`, save to `~/.storyteller/pending-video/<signal_id>-<platform>.json`. Capture draft IDs. Retry once on failure; second failure moves to `~/.storyteller/failed-pushes/`.
8. **Notify Slack + write state.** Send `notification.slack.template` (`{count}` = pushed, `{top_title}` = top signal) via `mcp__claude_ai_Slack__slack_send_message` to `notification.slack.target`. Append per drafted signal to `~/.storyteller/state.jsonl`: `{"signal_id":"...","drafted_at":"<ISO>","postiz_drafts":[{"platform":"...","postId":"...","integration":"..."}]}`.

## Modes
- **Interactive:** `/storyteller`. Includes step 6.
- **Scheduled (Cowork):** Skips step 6. User reviews in Postiz.

## Flags
- `--dry-run`: run 1-5; step 6 auto-ships; step 7 skips push/save/state; step 8 prints (does NOT send).
- `--source <name>`: in step 2, only fetch named source.
- `--no-postiz`: skip step 7 push; still save held and write state.
- `--no-notify`: skip Slack send; still write state.

## Failure-mode anti-patterns
- Do NOT publish to Postiz — always draft per `references/publish-postiz.md`. User has forbidden auto-posting.
- Do NOT skip dedupe — same signal will redraft every run.
- Do NOT draft BEFORE scoring — only top-N get drafted.
- Do NOT silently swallow scoring/drafting failures — surface in Slack notification.
- Do NOT push `hold: true` drafts (Instagram, Reels in Slice D); they go to `~/.storyteller/pending-video/`.
- Do NOT pass raw paths or URLs to `postiz posts:create -m` — upload via `postiz upload` first.

## Prerequisites
- `gh` authenticated (`gh auth status` OK).
- `postiz` installed; `POSTIZ_API_KEY` set.
- Slack MCP (`mcp__claude_ai_Slack__*`) available.
- `~/.storyteller/config.yaml` exists. If missing, copy `sample-config.yaml` from this bundle and pause for the user to fill repos.

**REQUIRED VOICE SKILL:** `kk-voice` — load before scoring or drafting.
**REQUIRED FORMAT SKILL:** `kk-short-form` — load before drafting Instagram or Reels.
**REQUIRED BACKGROUND:** `superpowers:test-driven-development` — applies when validating skill behavior during development.
