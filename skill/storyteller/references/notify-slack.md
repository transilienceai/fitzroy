# Notify — Slack

Send one-line summary via Slack MCP after a run completes.

**REQUIRED:** Slack MCP available (`mcp__claude_ai_Slack__slack_send_message`).

## Input

- `count` (int) — number of drafts successfully pushed to Postiz this run
- `top_title` (str) — title of the highest-scored signal that produced a draft
- `failures` (list) — items that failed during the run, each `{signal_id, platform, error}`. May be empty.
- `target` (str) — Slack user ID or channel ID from `config.notification.slack.target` (`U...` = DM, `C...` = channel)
- `template` (str) — message template from `config.notification.slack.template`

## Message construction

1. Substitute `{count}` and `{top_title}` into `template`. (Standard Python-style substitution. If `count == 0`, the substituted message may read awkwardly — that's fine; the failure tail explains.)
2. If `failures` is non-empty, append a second block:
   ```
   :warning: {N} draft(s) failed to push. Saved to ~/.storyteller/failed-pushes/.
   ```
   Where `N == len(failures)`. The leading newline before `:warning:` is intentional — Slack renders it as a blank-line separator.

## Sending

Call `mcp__claude_ai_Slack__slack_send_message` with:
- `channel_id`: `target` (works for both `U...` user IDs and `C...` channel IDs per Slack MCP tool semantics)
- `message`: the constructed message string

## Output

```json
{"status": "ok"}
```

On failure (MCP error, target invalid):
```json
{"status": "failed", "error": "<message>"}
```

State.jsonl is still written even if Slack fails — better to lose the notification than lose dedupe. The orchestrator must log the Slack failure to stderr so KK sees it on the next interactive run.

## Failure-mode anti-patterns

- Do NOT raise/throw on Slack send failure — degrade gracefully.
- Do NOT skip state.jsonl write because Slack failed.
- Do NOT include the `~/.storyteller/failed-pushes/<filename>.json` path in the message; just say "saved to ~/.storyteller/failed-pushes/" — naming individual files in a Slack notification is noisy.
