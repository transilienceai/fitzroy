# Drafting — Shared Conventions

This file is loaded by ALL StoryTeller drafter prompts (`drafting-linkedin.md`, `drafting-x-thread.md`, `drafting-instagram.md`, `drafting-reels.md`). It defines cross-format conventions so each drafter prompt can stay focused on format-specific structure.

## Voice authority

**REQUIRED:** Load `kk-voice` before drafting. For Instagram captions AND Reels/Shorts scripts, ALSO load `kk-short-form` (Meera/Rohan audience, not Jennifer — the Jennifer pre-publish checklist does NOT apply to these formats).

## Banned phrases (all formats)

These phrases must NOT appear in any drafter output. They flag corporate jargon, AI-slop, or LinkedIn-influencer-bait that KK explicitly avoids. The full list is in `tests/banned-phrases.txt` and the structural validators for each format read from it.

Categories represented:
- **Corporate jargon:** leverage, synergy, alignment, stakeholder buy-in, deep dive, circle back, touch base
- **AI-slop:** "It's important to note", "In today's rapidly evolving landscape", "delve into", "navigate the complexities of"
- **LinkedIn-influencer-bait:** "Here's what I learned", "I've been thinking about", "Hot take:", "Unpopular opinion:", "Here's the thing", "Plot twist:", "Buckle up", "Game changer", "Mind-blowing", "Let me explain", "The truth is"
- **Founder-journey:** "how I scaled to $X ARR", "the journey to product-market fit", "my Series A story"
- **Excited-to-announce:** "excited to announce", "thrilled to share", "delighted to launch"

See `tests/banned-phrases.txt` for the canonical list (one phrase per line, lowercase). When adding a phrase, append there.

## Error envelope (all formats)

ALL drafter prompts return a JSON object with `status` as the first-line discriminator:

```json
{ "status": "ok",    "platform": "<p>", "format": "<f>", "content": ..., "hashtags": [...], "internal_notes": "..." }
{ "status": "error", "platform": "<p>", "format": "<f>", "error": "<short message>" }
```

Consumers (orchestrator, publisher) MUST check `status` first. `status: "ok"` → push to Postiz or hold per format rules. `status: "error"` → log + move draft input to `~/.storyteller/failed-pushes/` for follow-up.

## Routing hints in error messages (orchestrator convention)

When a drafter cannot produce a valid draft because the signal is wrong for THIS format but might work for ANOTHER format, the error message MAY include a routing hint using the suffix `" — recommend <other-format>"`.

Examples:
- `"error": "incompressible for x — recommend linkedin long-post"` (signal too dense for a 3-5 post thread; try long-form)
- `"error": "no visual hook for reels — recommend x thread"` (signal is text-only insight; better as text-first)
- `"error": "no consumer-safety angle for instagram — recommend linkedin long-post"` (signal is too technical for Meera; better for Jennifer)

The orchestrator (Task 12 SKILL.md workflow, future enhancement) reads the suffix and re-routes the signal to the recommended drafter. If the orchestrator doesn't yet implement re-routing, the hint is recorded in the failed-pushes/ log for KK's manual review.

**Convention rules:**
- Suffix is ` — recommend <format>` (em-dash, lowercase, hyphenated format name)
- Recommended format must be one of: `linkedin long-post`, `x thread`, `instagram caption`, `reels script`
- This is OPTIONAL — drafters may emit plain `"error": "<message>"` without a hint when no other format fits.
- Hints are non-binding — the orchestrator may ignore them.

## Output strictness (all formats)

- Strict JSON only. No prose around it. No markdown fence (no ```json ... ```).
- First character of the output must be `{` (or `[` for X thread `content` arrays — see format-specific prompt).
- Last character must be `}` (or `]`).
- Never throw. Never return prose. Never return null. Always return a JSON object/array.

## Transilience placement (all formats)

If Transilience appears in the draft, it may ONLY appear in the closing 1-2 sentences (LinkedIn, Instagram captions) OR closing 1 post (X thread) OR closing 5-10s of script (Reels). The preceding text MUST read as a complete, valuable post even if the Transilience mention were removed. Self-check: delete the closing — does the post still earn its keep? If no, you're pitching, not teaching.

## internal_notes convention (all formats)

The `internal_notes` field is for KK (or the orchestrator's interactive review loop). It is NEVER posted to Postiz. Use format `#<n> <short-name>` when referencing voice-skill checklist items (e.g., `"#3 receipts and #5 makes-her-smarter"`).

## front-load drift (all formats)

A specific failure mode to avoid: the first paragraph (or first post in a thread) is razor-sharp with named receipts, then the back half drifts into generic industry observation. Specificity MUST sustain through the entire piece. If you find yourself reaching for generalization in the middle/end, that signals you're out of receipts and should either tighten the piece or pick a different angle.
