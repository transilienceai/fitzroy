# Reference: Creative variant rules

How the skill drafts 3 distinct headline/intro/CTA variants per ad at step 6 of the workflow.

**REQUIRED:** Load `kk-voice` BEFORE drafting. The Jennifer Chen audience profile and the 7-item pre-publish checklist in `kk-voice` are the bar every variant must clear. Treat this reference as the structural contract; voice rules live in `kk-voice` and are not duplicated here.

## What changes vs. what stays

Across the 3 variants:
- **Changes:** the hook (headline) AND the framing of the intro.
- **Stays the same:** audience preset, offer (URL, CTA, UTM base), image.

LinkedIn's optimization engine compares variants under identical audience + visual to pick the highest-CTR hook. Changing more than the hook contaminates the test.

## The 3 hook styles

### Style A — problem-led
**Frame:** name the operational pain Jennifer is wrestling with at 8:15 AM Tuesday. Stake first, offer second.

**Hook shapes:**
- "Your AI risk roadmap is due in 6 weeks. You don't have one."
- "Every Deputy CISO I've spoken to in the last quarter has the same 2026 problem."
- "Your scanner is reporting AI findings to a framework that doesn't exist yet."

**Intro pattern:** acknowledge the pain (1 sentence), name the specific shape of the problem (1 sentence), introduce the offer as a remedy (final clause).

### Style B — outcome-led
**Frame:** lead with the borrowable insight Jennifer will use in her next meeting. The offer is the way to access it.

**Hook shapes:**
- "A 3-slide AI security roadmap your CISO can present Monday."
- "The scoring framework 60 US mid-market enterprises use to benchmark AI risk."
- "Here's the AI-SPM mental model the top-quartile programs ship in 2026."

**Intro pattern:** describe the deliverable (1 sentence), give one specific number or named tool (1 sentence), gate it on the offer (final clause).

### Style C — question-led
**Frame:** open a loop Jennifer feels compelled to close. Honest question, not rhetorical bait.

**Hook shapes:**
- "When did you last benchmark your AI risk against your peers?"
- "How would you brief your board on AI security tomorrow morning?"
- "Could you defend your current AI compliance taxonomy in an auditor's office?"

**Intro pattern:** restate the question's stakes (1 sentence), establish credibility / receipts (1 sentence), offer is the answer (final clause).

## Char limits (LinkedIn enforced)

| Field | Soft limit | Hard limit | What happens at limits |
|---|---|---|---|
| Headline | 70 | 70 | LinkedIn truncates with `…` past 70. Stay ≤ 70 strict. |
| Intro text | 150 (above-the-fold on mobile) | 600 | Soft: text past 150 hides behind "...see more". Hard: LinkedIn rejects past 600. Stay ≤ 150 unless the receipt is load-bearing past it. |
| CTA | N/A (picked from allowlist) | N/A | See `offer-library.md > CTA allowlist`. |

Flag any draft variant that breaches a limit in the staging file's per-variant char-count line (see `ad-template.md` §4). Force tighten in the review loop.

## Banned phrases (carried over from kk-voice + drafting-shared)

These must NOT appear in any variant headline or intro:

- **Corporate jargon:** leverage, synergy, alignment, stakeholder buy-in, deep dive, circle back, touch base
- **AI-slop:** "It's important to note", "In today's rapidly evolving landscape", "delve into", "navigate the complexities of"
- **Influencer-bait:** "Here's what I learned", "I've been thinking about", "Hot take", "Unpopular opinion", "Here's the thing", "Plot twist", "Buckle up", "Game changer", "Mind-blowing", "Let me explain"
- **Excited-to-announce:** "excited to announce", "thrilled to share", "delighted to launch"
- **Founder-journey:** "how I scaled to $X ARR", "the journey to product-market fit"
- **CTA bait:** "Tag someone who needs to see this", "Comment below", "Drop a 🚀"

If a draft variant would otherwise contain one of these, rewrite. Do not ship the ad.

## The Jennifer filter — applies per variant

Every variant must clear the 7 items of the Jennifer pre-publish checklist in `kk-voice`. The orchestrator surfaces failures in the review loop. KK can override on a per-variant basis but the default is: fail the checklist → tighten or drop the variant.

The most common failures on ad copy specifically:
1. **#1 stop-scrolling** — headline doesn't name a stake Jennifer is wrestling with.
2. **#3 receipts** — intro is claims without numbers/tools/scenarios.
5. **#5 makes-her-smarter** — intro doesn't carry a borrowable insight; reads as a pitch.

If 2 of 3 variants fail the same item, the ad's angle is probably wrong — go back to step 1 with a different topic-first brief.

## Output shape (internal to step 6 → step 8)

For the review loop, the skill renders each variant as the §4 block in `ad-template.md`. No separate JSON envelope — variants live inline in the staging file from the moment they're drafted.

## Transilience placement

Per the cross-format rule in `_drafting-shared.md`: Transilience as a brand name may appear in the intro ONLY in the final clause. The hook and the first 80% of the intro must read as a complete, valuable observation Jennifer would respect even if "Transilience" were absent. If you can delete the offer reference and the intro still earns its keep, the variant is solid. If not, you're pitching — rewrite.

For LinkedIn paid ads specifically, this is more relaxed than for organic posts (Jennifer expects a paid post to have an offer), but the principle holds: the pain or the insight leads; the brand follows.
