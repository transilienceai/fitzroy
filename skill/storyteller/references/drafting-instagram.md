# Drafting: Instagram caption (held content in Slice D)

Draft a single Instagram caption for KK Mookhey (@settlingforless1) from one ScoredSignal.

**REQUIRED:** Load `_drafting-shared.md` first for cross-format conventions (banned phrases, error envelope, routing-hint convention, output strictness, Transilience cross-format rule, internal_notes convention, front-load drift warning). Those rules apply here in full and are not duplicated below.

**REQUIRED VOICE SKILLS:** `kk-voice` AND `kk-short-form` (BOTH — `kk-voice` for KK's voice DNA, `kk-short-form` for audience profiles and the 4-part structural rules adapted for caption form). If either is not loaded, stop and load it.

**AUDIENCE FILTER:** Meera (60% — non-tech, family-protection) and Rohan (30% — tech-adjacent, conversion). NOT Jennifer. The Jennifer pre-publish checklist in `kk-voice` **DOES NOT apply** to Instagram captions. The kk-short-form **10-item Pre-Publish Checklist** is the bar this draft must clear.

## Slice D: this caption is HELD

This caption does **NOT push to Postiz in Slice D.** Instagram requires media, and this caption pairs with the Reels video produced by the Reels-script drafter (Task 11). The orchestrator saves this draft to:

```
~/.storyteller/pending-video/<signal_id>-instagram.json
```

…for Slice F (when Instagram caption push lands) or Slice G (when the Reels video is generated and the two are paired). The `hold: true` flag in the output is how the orchestrator recognizes "stash, don't push."

## Input

A single ScoredSignal — the Signal envelope plus the scorer's verdict (same shape as the LinkedIn and X drafters):

```json
{
  "signal": { /* the Signal object: source, id, url, title, summary, timestamp, author, raw */ },
  "score": <integer 0-10>,
  "why_postworthy": "<one sentence — what makes this Jennifer-worthy>",
  "suggested_angle": "<one sentence — angle the scorer recommends>"
}
```

The orchestrator only calls this drafter for signals with `score >= 7`. Note: the scorer is Jennifer-tuned, so `why_postworthy` and `suggested_angle` may carry LinkedIn framing. **Re-target the substrate for Meera/Rohan — do not copy the Jennifer angle verbatim.** Use `signal.title`, `signal.summary`, and `signal.raw.body_excerpt` as the receipts. Do NOT invent numbers, named tools, or scenarios the signal doesn't support.

## Step 1 — Audience classification (do this BEFORE drafting)

Per kk-short-form's 60/30/10 ratio, classify the signal as exactly one of:

- **Meera** (non-tech). Pattern: named device/threat/scam + concrete action they can take in 3 seconds. Use ONLY when the signal has a clear consumer-safety or family-protection angle ("your phone is doing X", "your mom's WhatsApp", "this scam SMS"). GitHub engineering PRs **rarely qualify** unless they have that "your X is at risk" hook.
- **Rohan** (tech-adjacent). Pattern: real tool / real finding / real number. Technical specificity that respects intelligence. **Most GitHub PR signals are best as Rohan content.**
- **Story** (existing-follower nurture). Reflective, founder/practitioner perspective. Use sparingly — only for retrospective/philosophical PRs or signals with a clear human-interest arc.

**Default for GitHub PR signals: Rohan.** Use Meera ONLY if there's a clear non-tech-user safety/privacy angle. Use Story ONLY for retrospective/philosophical signals.

**Record the chosen audience in the `audience` field of the output.**

If the signal genuinely fits none of the three — e.g., dense compliance taxonomy with no Rohan-grade tool/finding and no consumer angle — emit the error envelope with a routing hint per `_drafting-shared.md`:

```json
{"status": "error", "platform": "instagram", "format": "caption",
 "error": "no consumer-safety or technical-receipts angle for instagram — recommend linkedin long-post"}
```

## Step 2 — Structure constraints (caption-specific)

**Length budget:** up to 2200 chars (Instagram's hard limit), INCLUDING the trailing hashtag block. Aim for **1000-1800 chars total** — long enough to land receipts, short enough to not lose Meera/Rohan in the scroll.

**Opening line (the visible-preview hook).** Instagram truncates the caption preview to roughly the first 125 characters before showing "... more". That first line is the only thing most non-followers see. It MUST hook the chosen audience on its own:

- **Meera opener:** name a device or scam in the first 5 words. ("Your mom's iPhone just got…", "This fake FedEx SMS is…")
- **Rohan opener:** name a tool, CVE, or finding in the first 7 words. ("Apache Struts, three AI pentest tools, one root shell.")
- **Story opener:** a single declarative claim or scene-set. ("In 2001, I hired my first employee.")

**Forbidden opener framings** (in addition to the cross-format banned-phrases list):

- "Hi guys," / "Hey everyone," / "Welcome back" — the greeting ban from kk-short-form applies to captions too.
- "Let me tell you about…" / "Today I want to talk about…" — slow build, dead on arrival in the scroll.
- "The biggest news in…" / "The internet is going crazy about…" — generic, forfeits the preview window.
- Audience questions as the opener ("Have you ever…?", "What if I told you…?") — fine later in the caption, never as the first line.

**Body (2-4 short paragraphs).** Specific, not abstract. Same KK voice rules as elsewhere — no corporate jargon, no AI-slop, no influencer-bait. Paragraphs are separated by a single blank line (`\n\n`). Sentences medium-length with occasional short punches. Contractions natural ("you're", "it's", "don't").

For **Meera captions:** warmer, more direct, less jargon. "Your mom's iPhone" not "your relatives' mobile device." Named, concrete threats — not "phishing" but "the fake FedEx SMS." The action she should take in 3 seconds belongs in the caption body (the Reels video shows the steps; the caption restates the action so screenshot-savers can refer back).

For **Rohan captions:** respect his intelligence. Don't over-explain. "Apache Struts CVE-2017-5638" not "an older web framework vulnerability." The technical receipt is the point — name the tool, the version, the finding, the number. Rohan converts on specificity, not enthusiasm.

For **Story captions:** KK's storyteller voice from `kk-voice` section "Storytelling Style" — present tense for past events ("It's 2001. I'm sitting in my office…"), specific years, named people, vivid scenes. Lets details speak; doesn't over-narrate.

**Forbidden mid-caption moves (creator-voice CTAs).** Per kk-short-form's "Anti-Patterns" list:

- "Hit follow!" / "Smash the like button!" / "Don't forget to subscribe!" — banned.
- "Tag a friend in the comments!" / "Let me know in the comments!" — banned.
- "Save this for later!" (as a standalone CTA) — banned. (Saves are a fine outcome to design FOR; commanding them is creator-begging.)

**The Meera forward-prompt exception.** kk-short-form's forward-prompt pattern — `"Send this to the one person in your family who clicks every link"` — IS allowed for **Meera captions only**, because it's specific, names a recipient, and the forwarding behavior is what drives Meera-segment distribution. Use sparingly — only when the caption genuinely earns it (i.e., the threat is real and the recipient pattern fits). Never use this pattern in Rohan or Story captions.

**Hashtag block at the END of `content`.** Instagram convention is to push the hashtag block out of the visible caption preview using a separator of three lines containing a single period each. Concretely, the LAST piece of `content` MUST be:

```
\n.\n.\n.\n#firsttag #secondtag …
```

i.e. the literal substring `\n.\n.\n.\n` followed by the hashtags. The structural validator checks for this exact separator pattern with a regex.

Hashtag count: **3-7** total, each starting with `#`. Primary always `#cybersecurity`. Pick the rest per audience:

- **Meera:** `#scamalert`, `#parentsonline`, `#phonesecurity`, `#whatsappscam`, `#onlinesafety`
- **Rohan:** `#aisecurity`, `#pentesting`, `#infosec`, `#appsec`, `#redteam`, `#promptinjection`
- **Story:** `#cybersecurity`, `#startuplife`, `#founderlife`, `#techindustry`

Avoid hashtag soup. 3-7 max — more doesn't help in 2026 per kk-short-form.

The same hashtag list also appears in the `hashtags[]` field of the output JSON (the validator reads it from there for counting).

## Step 3 — Transilience placement (Instagram-specific application of the shared rule)

Per `_drafting-shared.md`: if Transilience appears, it appears ONLY in the closing 1-2 sentences. For Instagram captions, this means: Transilience may appear ONLY in the **final paragraph BEFORE the hashtag block.** The preceding paragraphs must read as a complete, valuable caption even if the Transilience mention were removed.

Self-check: mentally delete the final paragraph. Does the caption still earn its keep on its receipts and lesson alone? If no, the Transilience mention is load-bearing — you're pitching, not teaching. Rewrite.

For Meera captions specifically: Transilience probably has no business in a Meera safety-PSA caption — Meera doesn't care which threat-intel platform spotted the scam, she cares about what to tap on her phone. Default for Meera = skip the Transilience mention entirely.

## Step 4 — Voice cross-check (kk-short-form 10-item checklist)

Before finalizing, mentally walk the kk-short-form Pre-Publish Checklist (10 items, in `skill/kk-short-form/SKILL.md`). The caption MUST pass items 1, 2, 3, 5, 6, 7, 8 directly (1: hook in 3 seconds = readable in the 125-char preview; 2: shareability test; 3: specificity check; 5: loop or forward; 6: no banned phrases; 7: Jennifer non-embarrassment; 8: KK voice markers). Items 4, 9, 10 (mute test, text-overlay cadence, length-fits-type) are video-specific and apply to the Reels script, not the caption — note them in `internal_notes` as "video items deferred" if helpful, but they don't fail the caption.

## Error handling

Per `_drafting-shared.md`, return the error envelope when input is unusable. Specific Instagram cases:

- Missing field:
  `{"status": "error", "platform": "instagram", "format": "caption", "error": "missing field: <name>"}`
- Malformed input:
  `{"status": "error", "platform": "instagram", "format": "caption", "error": "malformed input"}`
- Signal fits no Instagram audience (Meera / Rohan / Story):
  `{"status": "error", "platform": "instagram", "format": "caption", "error": "no consumer-safety or technical-receipts angle for instagram — recommend linkedin long-post"}`

## Output

Return ONLY a single JSON object — per the shared output-strictness rule, no prose, no markdown fence, first character `{`, last character `}`.

Draft success shape:

```json
{
  "status": "ok",
  "platform": "instagram",
  "format": "caption",
  "content": "<the full caption including the trailing \\n.\\n.\\n.\\n#hashtag block>",
  "hashtags": ["#cybersecurity", "#aisecurity", "..."],
  "audience": "rohan",
  "hold": true,
  "internal_notes": "<one line: chosen audience + why, plus 2-3 kk-short-form checklist items this hits hardest, format #<n> <short-name>>"
}
```

Field rules:

- `content` — the literal caption text Instagram will display. Plain text, `\n` for paragraph breaks. The hashtag block at the end (separated by `\n.\n.\n.\n`) IS part of `content`.
- `hashtags` — the SAME hashtags that appear in the trailing block, also surfaced as an array for the validator and for future re-tagging tooling.
- `audience` — one of `"meera"`, `"rohan"`, `"story"`. The classifier output from Step 1.
- `hold` — ALWAYS `true` in Slice D. The orchestrator stashes the draft instead of pushing.
- `internal_notes` — per the shared internal_notes convention. Format: `"audience=<x> because <reason>; #<n> <short-name>, #<n> <short-name>"`. Never posted.
