# Reference: scoring + lead-failure picker

How the grader scores a post at step 4 + identifies the lead failure at step 5.

## Source of truth — DO NOT duplicate

The scoring rubric lives at `~/.claude/skills/storyteller/references/scoring-rubric.md`. Read it; do not re-implement. If storyteller's rubric changes (e.g. adds a 6th criterion), this skill picks it up automatically by re-reading on each run.

The rubric defines:
- 5 criteria × 0/1/2 points = 0-10 total
- Hard-zero check (precedence: hard-zero fires first, skip rubric)
- Criterion 5 conditional logic (Transilience-style branded product presence)

## Grader-specific adaptations

Two narrow adaptations of the storyteller rubric for the grader use-case:

### 1. Criterion 5 default

The rubric says criterion 5 (problem-before-product) defaults to 2 if Transilience does not appear. Adapt for the grader:

- If the post body mentions ANY company / product / SaaS brand AND has a CTA / "DM me" / link to a landing page → apply criterion 5 normally.
- If the post is pure observation / lesson / story with NO product mention → criterion 5 defaults to 2 (not applicable, no penalty).

This catches third-party vendor pitches the same way storyteller catches Transilience-pitchy posts.

### 2. Hard-zero detection — additional grader rules

In addition to the storyteller hard-zeros (excited-to-announce, pure dependency bumps, India/ME-only regional, etc.), the grader treats these as hard-zeros:

- **Pure-CTA posts** with no substance: "Read our latest blog post" / "Sign up for our webinar" / "Join my newsletter" with zero original content — link-bait only.
- **Pure-emoji posts** that are < 30 chars or are mostly emoji.
- **AI-generated thirstposting** patterns: "I asked ChatGPT what the future of <X> looks like and here's what it said…" → hard-zero. (The grader is allowed to be honest about this.)

Hard-zero output skips the rewrite by default. Override with `--rewrite-anyway`.

## Lead-failure picker

After scoring, pick the SINGLE biggest reason the post didn't score higher. This is the diagnostic sentence in the output.

### Picking rules

1. **If a hard-zero fired:** lead failure = the hard-zero rule, phrased as a sentence. Example: `Pure announcement — the post tells me a thing exists but doesn't teach anything about it.`

2. **Else: pick the LOWEST-scoring criterion.** If multiple criteria tied at the bottom, break ties in this order:
   - Criterion 3 (receipts) — Jennifer notices missing evidence first
   - Criterion 4 (operator voice) — then notices vendor / founder pitching
   - Criterion 1 (specific operational substance) — then notices abstraction
   - Criterion 5 (problem-before-product) — then notices the pitch landing too early
   - Criterion 2 (borrowable insight) — last because borrowability is harder to feel acutely

The order roughly tracks "what makes Jennifer scroll past first."

### Phrasing rules

The lead failure is ONE sentence. It must:
- Be diagnostic, not labelling. Bad: "Failed criterion 3 (receipts)." Good: "Receipts are deferred to a gated eBook instead of delivered in the post itself."
- Name the SPECIFIC thing the post does (or fails to do), not the abstract category. Bad: "Lacks specificity." Good: "Says 'help your clients' without naming a single tool, control, or failure pattern."
- Avoid finger-wagging. The grader is constructive, not snarky. Bad: "Lazy vendor marketing." Good: "Reads as vendor copy because every concrete claim is gated behind 'this eBook explains…'."

Look at the post body to derive the specifics for the lead-failure sentence — don't write generic diagnostic prose.

## Worked examples

### Example A — Todyl CMMC post (2026-06-03 test)

Body: "The DoD will require CMMC in all defense contracts by October 2026. If you or your clients handle Federal Contract Information (FCI) or Controlled Unclassified Information (CUI), you're on the clock. 👉 This eBook shows you exactly what's required at each level — and how to simplify your path to certification."

Scores:
- C1 (substance): 1/2 — names CMMC, FCI, CUI, October 2026; no numbers, no tools, no failure modes.
- C2 (borrowable): 1/2 — the deadline is borrowable; the framework is well-known.
- C3 (receipts): 0/2 — receipts are entirely deferred to the eBook; the post itself proves nothing.
- C4 (voice): 0/2 — pure vendor copy ("If you or your clients…").
- C5 (problem-first): 1/2 — problem first, but lands in the eBook by sentence 3.

Total: 3/10.

Lead failure: `Receipts are entirely deferred to the eBook — the post itself proves nothing about the audit pattern or the common failure modes that would make a CISO stop scrolling.`

### Example B — hypothetical hard-zero

Body: "Excited to announce that I've been named to the Forbes 30 under 30! 🎉 Thanks to my amazing team."

Hard-zero rule fired: "Excited-to-announce" material with no extractable lesson.

Score: 0/10.

Lead failure: `Pure announcement — the post celebrates a milestone but offers nothing the reader can borrow, apply, or push back on.`

Rewrite section: skipped (default). Set `--rewrite-anyway` to force a rewrite that turns the milestone into a borrowable lesson.

## Output of this step

A scored verdict passed to step 6 (rewrite) and step 7 (rendering):

```json
{
  "total_score": <0-10>,
  "criteria": [
    {"n": 1, "name": "Specific operational substance", "score": <0|1|2>, "why": "<one short sentence>"},
    {"n": 2, "name": "Borrowable insight",             "score": <0|1|2>, "why": "<one short sentence>"},
    {"n": 3, "name": "Receipts vs generalities",       "score": <0|1|2>, "why": "<one short sentence>"},
    {"n": 4, "name": "Operator voice",                 "score": <0|1|2>, "why": "<one short sentence>"},
    {"n": 5, "name": "Problem-before-product",         "score": <0|1|2>, "why": "<one short sentence or 'N/A — no product mentioned'>"}
  ],
  "hard_zero_rule": "<rule name or null>",
  "lead_failure": "<one-sentence diagnosis>",
  "verdict_phrase": "<≤8-word punchy header — what this post IS, not what it failed at>"
}
```

The `verdict_phrase` is the share-worthy quote. Examples: `"Vendor pitch with a deadline glued to it"`, `"Founder-journey post with no operator voice"`, `"Pure announcement, no borrowable lesson"`, `"Strong receipts, weak hook"`, `"Solid 9/10 — Jennifer would screenshot this."`. The grader can be honest about good posts too.
