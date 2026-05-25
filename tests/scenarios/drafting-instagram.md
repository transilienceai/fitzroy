# Test: drafting-instagram

## Given
A single ScoredSignal (Signal + score + why_postworthy + suggested_angle) chosen from the scoring output with score >= 7.

## When
The `skill/storyteller/references/drafting-instagram.md` prompt is applied with `kk-voice`, `kk-short-form`, and `skill/storyteller/references/_drafting-shared.md` loaded.

## Then expect (structural)
A single JSON object with these top-level keys:
- `status` == "ok"
- `platform` == "instagram"
- `format` == "caption"
- `content` (string, <= 2200 chars total, INCLUDING the trailing hashtag block)
- `hashtags` (array of strings, 3-7 items, each starts with "#") — used by the validator; the actual hashtag block is also embedded in `content` at the end
- `hold` == true (this draft is NOT pushed to Postiz in Slice D; the orchestrator saves it to `~/.storyteller/pending-video/<signal_id>-instagram.json`)
- `audience` (string, one of `"meera"`, `"rohan"`, `"story"`) — classifies which Reels/Shorts audience this caption targets
- `internal_notes` (string)

## Then expect (qualitative — second Claude call)
Apply the kk-short-form Pre-Publish Checklist (10 items, listed in `skill/kk-short-form/SKILL.md`) to the caption text in `content`. The caption MUST pass items 1, 2, 3, 5, 6, 7, 8. Items 4, 9, 10 are video-specific and may be marked "deferred to Reels script" without failing the caption — the judge step records them as `passes: true` with reason `"deferred to Reels (video item)"`.

## Fail conditions
- `status` is missing or not `"ok"`
- `platform` or `format` mismatched
- `content` length > 2200 chars
- `hold` != `true`
- Hashtag block missing from the end of `content` (separator `\n.\n.\n.\n` before the first `#tag` is required)
- Hashtag count outside 3-7
- Any hashtag missing the `#` prefix
- `audience` not in `["meera", "rohan", "story"]`
- `content` contains any phrase from `tests/banned-phrases.txt` (case-insensitive)
- Caption fails any of the 7 applicable kk-short-form checklist items (1, 2, 3, 5, 6, 7, 8)

## Structural validator (bash)

```bash
python3 -c '
import json, pathlib, re
d = json.load(open("/tmp/instagram-caption.json"))
assert d.get("status") == "ok", f"status not ok: {d.get(\"status\")}"
assert d["platform"] == "instagram" and d["format"] == "caption"
assert d["hold"] is True, "hold must be true (Slice D — caption is held for Reels pairing)"
assert d["audience"] in ("meera", "rohan", "story"), f"audience invalid: {d[\"audience\"]}"
c = d["content"]
assert len(c) <= 2200, f"content {len(c)} chars > 2200"
# Hashtag separator convention — three single-period lines before the hashtag block
assert re.search(r"\n\.\n\.\n\.\n#", c), "missing Instagram hashtag separator: \\n.\\n.\\n.\\n#"
tags = d["hashtags"]
assert isinstance(tags, list) and 3 <= len(tags) <= 7, f"hashtags count {len(tags)} outside 3-7"
for t in tags: assert t.startswith("#"), f"hashtag missing #: {t}"
banned = [l.strip() for l in pathlib.Path("tests/banned-phrases.txt").read_text().splitlines() if l.strip()]
lower = c.lower()
hits = [b for b in banned if b in lower]
assert not hits, f"banned phrases: {hits}"
print(f"PASS: {len(c)} chars, {len(tags)} hashtags, audience={d[\"audience\"]}, no banned phrases")
'
```

## Voice-judge validator (kk-short-form 10-item checklist)

A second Claude call reads `/tmp/instagram-caption.json`'s `content`, applies the 10 items from kk-short-form's Pre-Publish Checklist, and writes per-item JSON to `/tmp/short-form-judgment-instagram.json` as an array:

```json
[{"item": 1, "name": "<short>", "passes": true|false, "reason": "<one sentence>"}, ...]
```

Items 4 (mute test), 9 (text overlay cadence), 10 (length fits type) are video-specific. For a caption-only artifact they pass with `reason: "deferred to Reels (video item)"`.

```bash
python3 -c '
import json
items = json.load(open("/tmp/short-form-judgment-instagram.json"))
assert len(items) == 10, f"expected 10 items, got {len(items)}"
failed = [i for i in items if not i["passes"]]
if failed:
    print("FAILED items:")
    for f in failed:
        print(f"  - #{f[\"item\"]} {f[\"name\"]}: {f[\"reason\"]}")
    raise SystemExit(1)
print("PASS: all 10 kk-short-form checks (4/9/10 deferred to Reels script)")
'
```
