# Reference: Ad image styles (override Quiet-Paper)

`gen_image.sh` ships with the Quiet-Paper aesthetic baked in for StoryTeller organic posts. For paid ads we want stopping power — different visual language entirely.

The skill overrides Quiet-Paper by exporting `IMAGE_STYLE=<block>` before invoking `gen_image.sh`. Three pre-tuned styles below.

## How the skill picks (audience → style mapping)

The default style for an ad is **NOT chosen by the user** — it's derived from the picked audience preset's `preferred_image_styles[0]` field in config. This is based on LinkedIn ad-creative research:

| Audience type | Default style | Why |
|---|---|---|
| Executives (CISO, board-adjacent) | `photo` | Face-led ads outperform abstract ones for senior-level buyers; humanizes the brand |
| SOC managers / detection-eng directors | `infographic` | Numbers + comparisons at the business-tech edge; borrowable for QBR slides |
| AI security buyers (governance heads) | `infographic` | Framework crosswalks + AI compliance data dominates their world |
| Technical practitioners (engineers, SREs, SOC analysts) | `ascii-diagram` | Terminal/diagram aesthetic stops the scroll for engineers; signals "by practitioners, for practitioners" |

Per LinkedIn's published B2B benchmarks (2024-2026): for technical audiences, data visualizations + architecture diagrams + terminal screenshots outperform people-shots by 2-3x. For executive audiences, faces beat abstract by ~30% CTR.

**Override:** `--image-style <photo|infographic|ascii-diagram|custom>` on `/linkedin-ad` skips the auto-pick and uses the named style instead.

## Default — `photo` (bold editorial photography)

Use when: the brief is about a product launch, a category position, a category truth, or anything where you want maximum scroll-stopping power. **The default for v1.**

```
Style: Bold editorial photography for a paid LinkedIn ad. Cinematic real-world scene with a single security-tech subject — close-up of hands on a keyboard, dramatic monitor glow on a face, a magnifying glass over code, a server-rack at a low angle, a clean desk with one focal screen. High contrast, deep shadows, single saturated accent color (deep teal, electric blue, or warm amber — pick one and commit). 1200x627 landscape with strong asymmetric negative space on the LEFT so the headline copy can overlay cleanly. Photoreal — not AI-glossy plastic, not stock-photo cheesy. No text on the image. No logos. Reads as a Wired or Bloomberg full-page editorial photograph.
```

## Alternative — `infographic`

Use when: the brief is fundamentally about a number, a comparison, a flow, or a labeled diagram. The visual carries the receipt.

```
Style: Editorial infographic for a paid LinkedIn ad. ONE clear visual idea — a comparison chart, a flow diagram, a labeled system diagram, a single big number. Bold typography for the ONE headline number or label; supporting structure in muted secondary tones. Single saturated accent (deep teal). 1200x627 landscape with generous whitespace. Reads as a sharp Economist or FT infographic — not a PowerPoint chart, not an icon collection. Sparse and legible at thumbnail size. No logos.
```

## Alternative — `ascii-diagram`

Use when: the audience is deeply technical (security engineers, SREs, infra folks) and the brief is about a system, a pipeline, a flow. Practitioner-coded. Strong for the `us-midmkt-healthfin-security-practitioners` audience.

```
Style: Monospace ASCII / terminal-diagram aesthetic for a paid LinkedIn ad targeting technical practitioners. Clean ASCII art — boxes, arrows, pipes — showing a system or flow. Monospaced font (JetBrains Mono, Fira Code, or similar). Dark terminal background with a single bright-color accent (terminal green, electric cyan, or amber). 1200x627 landscape. Reads as a real terminal screenshot of a sharp architecture diagram — operator-coded, practitioner-recognizable, never marketing-polished. No logos, no marketing copy.
```

## How the skill picks (resolution order at step 7)

1. If `--image-style <name>` flag is set: use the named style (explicit override).
2. Else: use `audience.preferred_image_styles[0]` from config (auto-pick from audience).
3. Else (audience has no `preferred_image_styles` field): fall back to `photo`.
4. If resolved style is `custom`: prompt KK for a one-line aesthetic descriptor; build a custom STYLE block from it.

The picked STYLE block is exported as `IMAGE_STYLE` before invoking `gen_image.sh`:

```bash
export IMAGE_STYLE="<resolved style block>"
bash ~/.claude/skills/storyteller/scripts/gen_image.sh "<subject>" "<output>"
```

`gen_image.sh` reads `IMAGE_STYLE` and uses it in place of the Quiet-Paper default. The variable is local to the subprocess — does not leak into StoryTeller's organic-post image-gen.

## Regen with a different style

`/linkedin-ad regen-image <slug> --image-style <name>` reads the staging file, swaps the style, re-runs gen_image.sh, rewrites `## 5. Image`. Useful when the first pick (e.g. `photo`) didn't land and you want to try `infographic` or `ascii-diagram` for the same ad.
