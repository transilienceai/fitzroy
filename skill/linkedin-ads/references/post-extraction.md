# Reference: Post-first trigger — extracting hook + insight + CTA from an organic LinkedIn post

How the skill handles `/linkedin-ad --from-post <url|file>` at step 1 of the workflow.

## Purpose

KK already shipped an organic LinkedIn post that performed well. He wants to paid-amplify it. The skill should NOT rewrite the post — it should extract the post's natural hook + borrowable insight + CTA and seed the 3 ad variants from those.

## Input types

### URL — `--from-post https://www.linkedin.com/posts/...`

LinkedIn doesn't expose post bodies via a clean API for non-owned posts, and even owned posts require auth flows the skill won't manage. Strategy:

1. Attempt WebFetch on the URL. LinkedIn renders the post body in the page HTML AND in OG metadata (`og:description`). Try OG first (cleaner), fall back to scraping the article body.
2. If scraping fails (LinkedIn login wall, rate limit, OG truncated to 200 chars), surface: "couldn't scrape this URL — paste the post body when prompted." Fall through to interactive paste.
3. Interactive paste fallback: prompt KK to paste the post text directly into the chat. Block until paste arrives.

### File — `--from-post /path/to/post.md`

KK supplies a local `.txt` or `.md` file with the post body. Read directly — no scraping. Easiest path; recommended.

### Pasted body (fallback)

Used when URL scraping fails. KK pastes the post body into the chat; the skill treats it the same as the file case.

## Extraction algorithm

Once the post body is in hand, extract three fields:

### 1. Hook
The first 1-2 lines of the post — what renders above the "...see more" fold on LinkedIn mobile. Cap at the first 210 chars OR the first paragraph break, whichever is shorter.

This is the *original* hook. The skill will use it as the seed for the 3 ad variants — each variant rewrites this hook in its own style (problem-led / outcome-led / question-led).

### 2. Core insight
The borrowable lesson the post is actually delivering. Heuristic:
- Look for the sentence with the highest density of specific nouns (named tools, named numbers, named frameworks).
- OR look for the sentence that follows the phrase "The lesson:" / "The thing is:" / "Here's the receipt:" / similar markers.
- OR look for the second-to-last paragraph (KK often lands the borrowable insight there before closing).

Capture as 1-3 sentences. This is what the variants' intros should reference.

### 3. CTA (if any)
The closing sentence of the post, if it carries an explicit ask. Common patterns: "Try it.", "Go build.", "Don't take my word for it.", "We're publishing this because...", a URL.

If no explicit CTA exists (most KK posts don't end on a CTA — they end on the lesson), leave this empty. The ad will use the offer's `default_cta` instead.

## Angle seed format

Output of the extraction step (used in step 6 variant drafting):

```
amplify post: <hook>

Core insight to riff on:
<core_insight>

Original CTA (if any):
<cta>

Original URL (if any):
<url>
```

This block becomes the `brief:` frontmatter field in the staging file AND the substrate for step 6.

## Variant-drafting nuance for post-first

When drafting variants from an extracted post:
- Variant A (problem-led) — rewrite the original hook to lead with the *pain* the post addresses. Often the original hook is already problem-led; if so, tighten it for ad-length.
- Variant B (outcome-led) — rewrite the hook to lead with the borrowable insight. Strip narrative framing.
- Variant C (question-led) — rewrite the hook as a question that opens the same loop the post does.

The intros pull receipts from the core insight, not from KK's brief (because the post IS the receipt).

## Objective-default note

When trigger is post-first, the LinkedIn-conventional objective is **Engagement** (matching organic-amplification intent). Engagement is **out of v1 scope**. So:
- At step 3 (pick objective), surface this note: "Promoting an organic post for lead-gen reframes the content as a top-of-funnel hook. Confirm `lead-gen` or pick `website-conversions`."
- Force KK to deliberate. Do not silently default.

## Failure handling

- **WebFetch fails entirely:** fall through to interactive paste. Log the WebFetch error to stderr but don't block.
- **OG description empty or truncated to <100 chars:** treat as scrape-failed, fall through to paste.
- **Pasted body < 100 chars:** surface "post body looks too short — re-paste or use --from-post with a file?" — block until KK supplies usable text.
- **All three fields empty after extraction:** treat as malformed input; ask KK to confirm the post URL is correct.
