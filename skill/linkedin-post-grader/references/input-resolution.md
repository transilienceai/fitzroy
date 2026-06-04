# Reference: input resolution

How `/grade-post <input>` parses its argument at step 2 of the workflow.

## Three input types

The skill auto-detects which kind of input it received. Order of checks:

1. **LinkedIn URL** — input matches `^https?://(www\.)?linkedin\.com/.+`
2. **File path** — input is an existing readable file on disk
3. **Pasted text** — input is > 100 chars and matches neither URL nor existing-file patterns

If none of the three match (e.g. empty input, < 100 chars of non-URL text), prompt: `"Paste a LinkedIn URL or post body (>100 chars)."`

## URL handling

### Strip tracking params

Before WebFetch, strip these query params if present (they're tracking noise that LinkedIn doesn't need to render the page):

- `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term`
- `rcm`
- `trk`, `trkInfo`
- `originalSubdomain`

Keep the rest of the URL intact — LinkedIn uses the post ID in the path, not in query params.

### Validate it's a POST URL

LinkedIn URLs come in many shapes. The grader handles posts only. Validate the URL path contains ONE of these segments:

- `ugcPost-<id>` (most common share format)
- `activity-<id>` (older share format, also valid)
- `share-<id>` (rare, valid)

Reject with this message if validation fails:

```
This looks like a LinkedIn profile / article / company page URL, not a post.
/grade-post needs a post URL — try one ending in `…-ugcPost-<id>` or `…-activity-<id>`.
```

### WebFetch extraction prompt

Once URL is validated, call WebFetch with this exact prompt:

```
Extract the full post body text. Include the author name (if visible), the post title or
headline if there is one, and the complete body of the post. If the page requires
authentication or returns a login wall, say so explicitly. If the post body is in OG
metadata (og:description or similar meta tags), use that. Quote the body text verbatim
— do not summarize. Also include the visible reaction count and comment count if shown.
```

Empirically validated 2026-06-03 against `linkedin.com/posts/.../ugcPost-7384334578162941953-...` — pulled full body from OG metadata, author name, reaction count (58), and a comment text. No login wall on public ugcPost URLs.

### Parse WebFetch response

WebFetch returns a model-summarized markdown response. Parse it for:

| Field | How to extract |
|---|---|
| Body | The longest verbatim quote block in the response. If WebFetch wrapped the body in quotes, strip the outer quotes. |
| Author | Look for `Author:` label or `By <name>` pattern. Optional — grade still works without. |
| Reaction count | Integer following "reactions" / "likes" / "👍". Optional. |
| Comment count | Integer following "comments". Optional. |
| Login-wall detection | If response contains "login", "authentication required", "must be logged in", "join to view" → treat as login-wall failure. |

## File handling

If input is a readable file path:
- Read the file with the Read tool.
- Strip any frontmatter (lines between `---` markers) — users may save posts with metadata.
- Treat the remaining content as the post body verbatim.
- Author / reactions / comments are unknown for this path.

## Pasted text handling

If input is > 100 chars and not a URL/file:
- Treat verbatim as the post body.
- Strip leading/trailing whitespace.
- Strip surrounding quote characters (`"`, `'`, `` ` ``) if present.
- Author / reactions / comments unknown.

## Failure modes

| Symptom | Detection | Output |
|---|---|---|
| Login wall | WebFetch response mentions login / join / authentication | `Couldn't read this post — LinkedIn returned a login wall (post may be private or require sign-in). Paste the body directly: `/grade-post "<paste here>"`.` |
| Truncated body | WebFetch returns < 100 chars OR ends with "…see more" | `LinkedIn truncated the post preview to <N> chars. Paste the full body directly: `/grade-post "<paste here>"`.` |
| Non-post URL | URL path lacks `ugcPost` / `activity` / `share` | `This looks like a LinkedIn profile / article / company page URL, not a post. /grade-post needs a post URL — try one ending in `…-ugcPost-<id>` or `…-activity-<id>`.` |
| Non-LinkedIn URL | URL host is not linkedin.com | `/grade-post is for LinkedIn posts. If you want to grade arbitrary text, paste it directly: `/grade-post "<your text>"`.` |
| Empty input | No argument | `Paste a LinkedIn URL or post body (>100 chars).` |
| File not found | File path that doesn't exist | `Couldn't read `<path>` — file not found.` |
| WebFetch network error | WebFetch returns error or times out | `Couldn't reach LinkedIn (network or timeout). Try again, or paste the body directly: `/grade-post "<paste here>"`.` |

All failure messages MUST be share-worthy — written for a human who hit the wall, never as a stack trace. The user trying the grader for the first time should be able to read the error, understand what to do next, and try again without consulting docs.

## Output of this step

A normalized `PostInput` shape passed to step 3:

```json
{
  "source": "url" | "file" | "text",
  "url": "<stripped URL or null>",
  "author": "<author name or null>",
  "body": "<post body verbatim, leading/trailing whitespace stripped>",
  "reaction_count": <integer or null>,
  "comment_count": <integer or null>
}
```

`body` is the only required non-null field. The rest are metadata that improves the rendered output but doesn't gate scoring.
