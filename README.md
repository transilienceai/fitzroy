# StoryTeller

**From the team at [Transilience AI](https://www.transilience.ai).** Open-source (MIT), local-first, and built for operators who'd rather ship than schedule meetings about shipping.

Turn the work you're already shipping — GitHub PRs, Slack threads with traction, paid-ad ideas — into ranked, voice-correct social-media drafts across LinkedIn, X, Instagram, and Reels. Local-first. Never auto-publishes. You stay in control.

This is a set of Claude Code skills, not a SaaS. It runs on your machine, uses your API keys, and writes drafts you review before anything goes live.

---

## What's inside

Five skills, each does one thing well:

- **`storyteller`** — surfaces post-worthy moments from your last 7 days of GitHub merges + Slack threads, scores them against your audience filter, lets you pick, drafts all 4 formats in parallel, generates an image, pushes drafts to Postiz.
- **`linkedin-ads`** — stages a full LinkedIn Campaign Manager setup (3 hook variants + audience + offer + image + UTM'd URL) as one markdown file per ad. Manual copy-paste — no LinkedIn API.
- **`linkedin-post-grader`** — `/grade-post <url-or-text>` returns a 0–10 score against the Jennifer filter + a rewrite that would score 7+. Works on your posts, competitor posts, or any viral thread. Screenshot-shareable by design.
- **`kk-voice`** — the voice + audience filter. This is where the magic isn't: a 7-item pre-publish checklist against a real audience persona (mine is "Jennifer Chen, Deputy CISO at a US mid-market enterprise"). **Fork this file first.** This is what stops the output from sounding like generic LLM slop.
- **`kk-short-form`** — Reels/Shorts structural rules (4-part hook/setup/payoff/close, 60/30/10 audience ratio, 10-item pre-publish checklist for vertical video).

---

## The storyteller workflow

```
GitHub PRs (last 7d) ─┐
                      ├─→ dedupe ─→ score ─→ ranked menu ─→ KK picks ─→ draft 4 formats ─→ generate image ─→ review loop ─→ Postiz (drafts)
Slack threads (last 7d)┘
```

1. **Fetch signals** from each enabled source (GitHub merged PRs via `gh`, Slack channel messages via Slack MCP with reactions + reply-count filters).
2. **Dedupe** against `~/.storyteller/state.jsonl` — every drafted signal is recorded, never redrafted.
3. **Score in one batched call** against the audience filter (the 7-item Jennifer pre-publish checklist in `kk-voice`). Anything scoring `<4` drops out.
4. **Present a ranked menu** of top-10 candidates with title, score, source, why-postworthy, suggested angle.
5. **You pick** which to actually draft. Thin weeks get a short menu — no padding.
6. **Draft each picked signal** in 4 formats: LinkedIn long-post, X thread, Instagram caption, Reels script. Each format honors its own structural rules.
7. **Generate one image** per signal (1080×1080 Quiet-Paper illustration via Gemini Nano Banana Pro). Shared across LinkedIn + X.
8. **Interactive review loop** — edit any draft, regen the image, swap angles, until you say "ship it."
9. **Push to Postiz as DRAFTS** (LinkedIn + X). Hold Instagram + Reels in `~/.storyteller/pending-video/` for when you shoot the B-roll. Slack-DM yourself when drafts are queued.

The whole loop takes 3–5 minutes interactive, fully unattended in scheduled mode (Cowork).

---

## The linkedin-ads workflow

For paid ads specifically — separate skill because the workflow is different (objective + targeting + budget matters; image spec is 1200×627 not 1080×1080; output is a copy-pasteable markdown file, not a Postiz draft).

```
Topic (or organic-post URL) ─→ pick objective ─→ pick audience preset ─→ pick offer ─→ draft 3 hook variants ─→ generate image ─→ review ─→ staged markdown file
```

Two triggers:
- `/linkedin-ad <topic>` — topic-first ("promote the free CISO assessment")
- `/linkedin-ad --from-post <url|file>` — post-first (amplify an organic post that performed well)

Output: `~/.linkedinads/staging/<YYYY-MM-DD>-<slug>.md` with every Campaign Manager field filled in. You paste into CM yourself — no LinkedIn API call.

---

## The voice filter — the part that matters

Most AI-generated content fails because the model writes for "everyone." The voice filter writes for **one person.**

`kk-voice` defines:
- Who that person is (in my case: Deputy CISO at a US mid-market enterprise, 14 direct reports, 16 years in, presenting an AI risk roadmap to the board in 6 weeks with no template).
- What she stops scrolling for (specific operational substance + borrowable insights).
- What makes her unfollow (corporate jargon, founder-journey content, "excited to announce" anything).
- A 7-item pre-publish checklist every draft must clear.

Without this file, the output is generic. With it, it sounds like you (assuming you write the file).

**The first thing you should fork is `skill/kk-voice/SKILL.md`.** Replace my Jennifer Chen with your audience. The rest of the system flows from there.

---

## Install

Requirements:
- macOS or Linux
- [Claude Code](https://claude.ai/code) (CLI or VS Code extension)
- `gh` CLI (authenticated for the GitHub repos you want to mine)
- Slack MCP (the official Anthropic Slack connector)
- [Postiz](https://postiz.com) account + API key (free tier works for testing)
- Google AI Studio API key (Gemini Nano Banana Pro for image-gen — ~$0.05/image)

```bash
git clone https://github.com/kkmookhey/StoryTeller
cd StoryTeller
bash scripts/install.sh
```

The install script:
- Symlinks the 4 skills into `~/.claude/skills/`.
- Bootstraps `~/.storyteller/` and `~/.linkedinads/` user data dirs.
- Copies sample-config.yaml into both, ready for your edits.

---

## Before your first run — customize three files

| File | Why |
|---|---|
| `skill/kk-voice/SKILL.md` | Replace "Jennifer Chen" with your audience persona. **Do this first.** |
| `~/.storyteller/config.yaml` | Add your GitHub repos under `sources.github.repos[]` and your Slack channel IDs under `sources.slack.channels[]`. |
| `~/.linkedinads/config.yaml` | Replace seeded Transilience audiences[] and offers[] with your own. |

Also export `POSTIZ_API_KEY` and `GEMINI_API_KEY` in your shell (or drop `Gemini Key.txt` / `Postiz Key.txt` in the repo root — the install script's bootstrap helps).

---

## Usage

In any Claude Code session (CLI, VS Code, or web):

```
/storyteller            — surface this week's ranked post ideas, draft picks, push to Postiz
/linkedin-ad <topic>    — stage a paid LinkedIn ad for Campaign Manager
/grade-post <url>       — grade any LinkedIn post (yours / a competitor's / a viral thread); screenshot-shareable
```

Flags:
```
/storyteller --dry-run     — score + draft without pushing anything
/storyteller --no-images   — skip Gemini image-gen (text-only drafts)
/storyteller --source <github|slack>  — only fetch the named source

/linkedin-ad --from-post <url|file>   — amplify an organic post
/linkedin-ad --no-image               — skip image generation
/linkedin-ad --image-style <photo|infographic|ascii-diagram|custom>  — override auto-picked image style
/linkedin-ad regen-image <slug>       — regenerate an image for a staged ad

/grade-post --save                 — also archive the rendered grade to ~/.linkedinads/graded/
/grade-post --rewrite-anyway       — force the rewrite section even for hard-zero posts
/grade-post --no-rewrite           — grade-only output (skip the rewrite section)
```

---

## What it does NOT do

Deliberate — these are the lines I won't cross:

- **Does not auto-publish.** Every draft sits in Postiz for your review. Every ad sits in `~/.linkedinads/staging/` for your copy-paste.
- **Does not call the LinkedIn API directly.** Paid ads are staged-only. Organic posts route through Postiz (which is API-driven but draft-only).
- **Does not generate generic content.** If you don't customize the voice filter, the output will sound like me, not you.
- **Does not cross-post to TikTok / Threads / Bluesky / Mastodon natively.** Postiz handles 28+ channels — wire them in via Postiz, not here.
- **Does not replace you.** It surfaces what's post-worthy and drafts it. You still pick, edit, and ship.

---

## Architecture

```
~/.claude/skills/                  # Claude Code loads skills from here
├── storyteller          → repo/skill/storyteller    (symlink)
├── linkedin-ads         → repo/skill/linkedin-ads   (symlink)
├── kk-voice             → repo/skill/kk-voice       (symlink)
└── kk-short-form        → repo/skill/kk-short-form  (symlink)

~/.storyteller/                    # storyteller user data
├── config.yaml                    # repos, channels, scoring weights
├── state.jsonl                    # dedupe ledger — every drafted signal
├── images/                        # generated illustrations
├── pending-video/                 # held Instagram + Reels drafts
└── failed-pushes/                 # Postiz/draft failures for manual follow-up

~/.linkedinads/                    # linkedin-ads user data
├── config.yaml                    # audience presets + offers + brand
├── staging/                       # one markdown file per staged ad
├── images/                        # generated ad creatives
└── failed-images/                 # image-gen failures
```

The skills are intentionally thin — `SKILL.md` is the workflow, `references/` holds detail (drafting rules, source adapters, scoring rubric, Postiz CLI semantics). The detail moves; the workflow stays the same.

---

## Why this exists

I was spending an hour per LinkedIn post and skipping X entirely because I couldn't afford the context-switch. The signals were already in my GitHub and Slack — I just wasn't reading them through a "would this make Jennifer stop scrolling" filter. So I built the filter. The drafting fell out of it.

If you ship product, you're sitting on more publishable content than you realize. This makes the gap between "thing shipped" and "post drafted" small enough that you actually do it.

---

## Status

Working in production for me (KK) since May 2026. Slices A through F are live; Slice G (Descript Reels video generation) is next. The `linkedin-ads` skill is v1 — Transilience-only and single-image-only by design; future versions add Document/Video/Carousel formats and Brand Awareness/Engagement objectives.

Honest about state: this is solo-built infrastructure for one operator's workflow. The skills are well-tested; the install path is well-trodden by one person on one Mac. Your mileage will vary. If you fork it and something breaks, open an issue or DM me — I'd rather know.

---

## Try it and tell me what breaks

Repo: https://github.com/transilienceai/StoryTeller (also at https://github.com/kkmookhey/StoryTeller)

Honest feedback only. We'd rather rip out a feature than carry one that doesn't earn its keep.

— The team at [Transilience AI](https://www.transilience.ai)
