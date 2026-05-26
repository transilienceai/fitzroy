# Test: idea-menu (SKILL.md step 5)

## Given
A `ScoredSignal[]` sorted descending by score, length = `config.scoring.menu_size` (default 10) or fewer (thin weeks). Mixed sources (GitHub + Slack).

## When
SKILL.md step 5 renders the menu in chat AND writes the JSON sidecar.

## Then expect (markdown rendering in chat)

A markdown table with exactly these columns: `#`, `Score`, `Source`, `Title`, `Why post-worthy`, `Suggested angle`.

- Row count == `min(menu_size, len(input))` — thin weeks render shorter menus, NOT padded.
- `#` is 1-indexed (rows numbered 1-N).
- `Title` truncated to ~60 chars with ellipsis (`…`) if longer (keep table scannable).
- `Why post-worthy` and `Suggested angle` are single-sentence strings (collapse newlines to spaces).
- Source values: `github` or `slack` (lowercase).
- Preceded by a one-line header: `## Ideas — week of YYYY-MM-DD` (date = today UTC).
- Followed by a one-line instruction:
  > Pick 2-3 to draft. Reply with indices (e.g., `1 5 8`) or `none` to skip.

## Then expect (JSON sidecar)

`~/.storyteller/last-ideas.json` exists after step 5 runs. Schema:

```json
{
  "generated_at": "<ISO 8601 UTC of this run>",
  "ideas": [
    {
      "index": 1,
      "signal_id": "<canonical id matching input>",
      "score": <integer>,
      "why_postworthy": "<FULL why_postworthy, NOT truncated>",
      "suggested_angle": "<FULL suggested_angle, NOT truncated>",
      "source": "github" | "slack",
      "title": "<FULL title, NOT truncated>",
      "url": "<full URL>"
    },
    ...
  ]
}
```

The JSON contains the FULL data (not truncated like the markdown for display). The picker step (workflow step 6) reads this to resolve `index → signal_id` deterministically.

## Fail conditions

- Markdown table missing any required column.
- Row count exceeds `menu_size`.
- JSON sidecar not written.
- JSON `index` doesn't match the row position in the markdown.
- JSON `ideas[].signal_id` doesn't match an input signal_id.
- Markdown `Title` not truncated when source title >60 chars.
- Source values capitalized inconsistently (`GitHub` vs `github`).

## Validator script (sidecar shape check)

```bash
python3 -c '
import json
data = json.load(open("$HOME/.storyteller/last-ideas.json"))
assert "generated_at" in data, "missing generated_at"
assert "ideas" in data and isinstance(data["ideas"], list), "missing or non-list ideas"
ideas = data["ideas"]
assert len(ideas) <= 10, f"too many ideas: {len(ideas)}"
for i, idea in enumerate(ideas):
    assert idea["index"] == i + 1, f"idea {i} index off: {idea[\"index\"]}"
    for k in ("signal_id","score","why_postworthy","suggested_angle","source","title","url"):
        assert k in idea, f"idea {i} missing {k}"
    assert idea["source"] in ("github", "slack"), f"idea {i} source: {idea[\"source\"]}"
    assert isinstance(idea["score"], int) and 0 <= idea["score"] <= 10
print(f"PASS: sidecar has {len(ideas)} ideas, indices contiguous 1..N")
'
```

## Validation approach (end-to-end)

Run via Task 9 (end-to-end dry-run). The manual eyeball check is:

1. Open `~/.storyteller/last-ideas.json` after a run.
2. Confirm 10 entries (or fewer if thin week).
3. Confirm indices match the chat-rendered table row order.
4. Spot-check: pick a Slack-sourced idea — does its URL render correctly (workspace + channel + p<ts_no_dot>)?
