# Reference: rewrite rules

How the grader drafts the rewrite at step 6 of the workflow.

## When to draft

- ✅ Always when total score < 7 AND no hard-zero fired.
- ✅ When `--rewrite-anyway` flag is set (even for hard-zero posts).
- ❌ Skip when total score >= 7 — output a short "this post is solid, here's why" line instead.
- ❌ Skip when `--no-rewrite` flag is set.
- ❌ Skip when post body is > 50% non-Latin script (kk-voice is English-only).
- ❌ Skip when hard-zero fired AND `--rewrite-anyway` is NOT set.

## Voice authority

**REQUIRED:** kk-voice is loaded (per SKILL.md step 3). Apply the voice DNA (tone, register, signature moves, banned phrases) from that skill. The rewrite is in KK's voice — that's part of the brand. Users who want a different voice fork kk-voice.

## Hard rules for the rewrite

1. **Preserve verifiable facts.** Numbers, dates, named tools, named frameworks, named regulations, named companies in the original post MUST appear in the rewrite (or the rewrite must explicitly drop them with reason). NEVER invent new numbers or named tools the original post didn't contain.

2. **Address the lead failure first.** The first 1-2 sentences of the rewrite must visibly fix the lead-failure diagnosis from step 5. If the lead failure was "receipts deferred to an eBook," the rewrite's first sentence must contain a receipt. If it was "vendor voice," the first sentence must be in operator voice.

3. **Hit 7+ on the same rubric, self-checked.** Before emitting the rewrite, score it against the same 5-criterion rubric. If the self-score is < 7, revise. The rewrite is offered to the user as "a version that scores 7+" — if it doesn't, the grader is lying.

4. **150-280 word target.** Same as the storyteller LinkedIn drafter contract. Ship at 140-149 or 281-300 only with a note in `internal_notes` explaining why.

5. **No banned phrases.** Apply the kk-voice + drafting-shared banned-phrases list. Specifically watch for "excited to announce," "thrilled to share," "leverage," "deep dive," "navigate the complexities of," etc.

6. **No Transilience plug.** Unless the original post is about a Transilience product (rare for grader input), the rewrite must NOT mention Transilience. The grader's value is the diagnosis + rewrite, not vendor placement.

7. **No invented receipts.** When the original post lacks specifics, the rewrite should ASK FOR the missing receipts using `[placeholder — verify before posting]` markers. Example: `We audited [N] mid-size defense MSPs [placeholder — your real number]…`. NEVER invent the number and present it as fact.

## Soft preferences

- **Lead with a stake.** If the original opens with "Did you know…?" or "AI is changing X…", rewrite to open with what's actually at stake for the reader.
- **One borrowable insight.** The rewrite should carry ONE line Jennifer would screenshot or paraphrase. Mark it mentally — it's the post's reason to exist.
- **Close on a teachable line, not a CTA.** The original may end with "DM me" or "Click here." The rewrite ends on a sentence the reader takes away. (If the original WAS about a specific offer, the close can mention it once, after the lesson lands.)

## Output of this step

The rewrite as a plain-text string. Renders into the `## Rewrite that scores 7+` block of the output (see `output-format.md`). The skill's internal_notes (not posted) records:
- The self-score against the rubric
- Word count + whether deviation was needed
- Any `[placeholder]` markers used (so the user knows to fill them in)

## What to do when the original is already 7+

Skip the rewrite. Render this block instead:

```markdown
## This post is solid — what's working

<one-line per criterion that scored 2/2 explaining why it works>

<one-line meta observation about what most people would learn from this post>
```

This handles the case where the grader is pointed at, e.g., one of KK's own well-performing posts. The output is still share-worthy — "the AI says my post is solid, here's why" is also a great screenshot.

## What to do when a hard-zero fired AND `--rewrite-anyway` is set

Draft the rewrite normally, BUT lead with this caveat line inside the rewrite block:

```markdown
> _Note: original triggered a hard-zero rule (<rule name>). This rewrite is an exercise in_
> _what the post COULD have been — not an endorsement of the underlying angle._
```

Then proceed with the rewrite. This preserves the grader's honesty (the hard-zero call wasn't a mistake) while still offering the constructive output the user asked for.

## Voice notes specific to grader rewrites

The grader's rewrites should sound like KK reviewing a peer's draft, not KK rewriting from scratch. Subtle but real difference:

- Inherit the post's TOPIC verbatim. Don't reframe to a different topic.
- Inherit the post's TONE register (formal vs casual) within the kk-voice envelope. A formal compliance post stays formal; a casual story stays casual.
- Inherit the post's INTENT (announce vs teach vs ask vs share). The rewrite shouldn't turn an "ask" post into a "teach" post just because teach posts score better — that violates the contract with the original author.

When in doubt, the rewrite preserves the author's choice and fixes the execution.
