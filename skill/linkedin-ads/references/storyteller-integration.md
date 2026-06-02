# Reference: StoryTeller integration (Phase 2 — DEFERRED)

**Status:** Not implemented in v1. Stub kept so the integration point isn't forgotten.

## Intended behavior (when implemented)

After StoryTeller's interactive review loop (step 8 of `storyteller/SKILL.md`), for any picked signal with `score >= 8`, prompt KK:

> "This signal scored {score}. Also draft a paid LinkedIn ad for it?"

If KK says yes:
1. Pipe the signal's `suggested_angle` into `/linkedin-ad` as the topic-first brief.
2. Use the signal's slug (e.g. `slack_C0EXAMPLE06_1779990441_678309`) as the ad slug suffix.
3. Default audience preset: `us-mid-market-ciso` (Jennifer-aligned, matches StoryTeller's scoring rubric).
4. Default offer: depends on signal — manual pick required for v1. Phase 2 may add signal-keyword → offer mapping.
5. Proceed through the standard workflow from step 3 (pick objective).

## Why deferred

KK approved deferral in the brainstorming session: "ship standalone first." v1 needs to be dogfooded on a few real ads before the integration design is sensible. The ad output shape and review loop need to be stable before plugging another caller in.

## When to revisit

When AT LEAST one of these is true:
- KK has staged 5+ real ads via the standalone skill and the workflow is settled.
- KK wants to ad-promote a StoryTeller signal often enough that the manual re-entry is annoying.
- The Postiz-side flow proves out and ad-publishing via API becomes a real possibility (would change what "stage" means).

## Implementation sketch (not built)

Add a hook in `~/.claude/skills/storyteller/SKILL.md` workflow at step 8.5:

```
8.5. **Offer ad-promotion** (interactive, score >= 8 only).
     For each picked signal with score >= 8, prompt: "Also draft a paid ad?"
     On yes: invoke `/linkedin-ad <signal.suggested_angle>` with auto-filled --audience us-mid-market-ciso.
     KK still picks objective + offer interactively.
     The ad's staging file gets frontmatter `source_signal: <signal.id>` for cross-reference.
```

The StoryTeller skill itself wouldn't write the ad — it would dispatch to `/linkedin-ad` and let that skill own the flow. Clean separation of concerns.

## Cross-reference in staging file

When ads originate from StoryTeller, the staging file's frontmatter gets one extra field:

```yaml
source_signal: slack:C0EXAMPLE06:1779990441.678309
```

This lets `/linkedin-ad list` and `/storyteller list` (if it exists) cross-reference each other later.
