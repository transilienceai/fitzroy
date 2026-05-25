# State Write

Append one entry per successfully-drafted signal to `~/.storyteller/state.jsonl`. Also prune entries older than `config.state.retention_days`.

## Input

For each signal that was successfully drafted (at least one format pushed OR held):
- `signal_id` (str) — e.g., `"github:kkmookhey/ciso-copilot:pr#18"`
- `drafted_at` (str) — ISO 8601 UTC timestamp of this run
- `postiz_drafts` (list) — one entry per format pushed: `{"platform": "...", "postId": "...", "integration": "..."}`. May be empty if all formats for this signal were held.

## File format

`~/.storyteller/state.jsonl` is append-only — one JSON object per line. Existing lines are NEVER edited. New entries always appended at end.

Example line:
```json
{"signal_id":"github:kkmookhey/ciso-copilot:pr#18","drafted_at":"2026-05-24T08:00:00Z","postiz_drafts":[{"platform":"linkedin","postId":"cmpknxfqj043mma0yw45b6m3j","integration":"<your-linkedin-integration-id>"},{"platform":"x","postId":"cmpkpostid_abc","integration":"<your-x-integration-id>"}]}
```

JSON keys in stable order (signal_id → drafted_at → postiz_drafts). Compact form, no pretty-printing, no trailing whitespace, single line per entry (the `.jsonl` extension is JSON Lines — one object per line).

## Retention pruning (once per run, before step 8 append)

This is the ONE exception to append-only:

1. Read the entire file.
2. Parse each line as JSON.
3. Drop entries where `drafted_at` is older than `config.state.retention_days` days ago (compare against now in UTC).
4. Rewrite the file with the surviving entries (overwrite the whole file, in order).
5. THEN append the new entries from this run.

Implementation note: do steps 1-4 BEFORE the append in step 5 so the file is consistent if the process is interrupted mid-write. Write to `~/.storyteller/state.jsonl.tmp` first then atomically rename to `~/.storyteller/state.jsonl` to avoid partial-write corruption.

## Failure handling

If the file write fails:
- Log to stderr: `state.jsonl write failed: <reason>. Re-runs may redraft already-pushed signals — manually deduplicate in Postiz if needed.`
- Continue (do NOT raise). Better to ship drafts and lose dedupe for one run than to abort the run after pushing to Postiz.

If the file is missing entirely (first run, or KK deleted it):
- Create it (empty file).
- Skip retention pruning (nothing to prune).
- Append new entries.

If a single line in the file is malformed (e.g., corrupted from external editing):
- Skip that line during the retention-prune read step.
- Continue with the surviving lines.
- Log the malformed line to stderr so KK can investigate.

## Output

```json
{"status": "ok", "appended": <N>}
```

Or on failure:
```json
{"status": "failed", "error": "<message>"}
```

## Failure-mode anti-patterns

- Do NOT rewrite the file in place without the `.tmp` + rename pattern (partial-write corruption risk).
- Do NOT pretty-print JSON entries (breaks the JSONL contract).
- Do NOT change the JSON key order between runs (consumers may parse positionally in spot-checks).
- Do NOT silently drop entries on a parse error — log the offending line so KK can recover.
