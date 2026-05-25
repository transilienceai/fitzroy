# Test: source-github adapter

## Given
Fixture at `tests/fixtures/github-prs-sample.json` — array of raw PR objects from gh CLI.

## When
The `skill/storyteller/references/source-github.md` prompt is applied to that fixture.

## Then expect
A JSON array of Signal objects, one per input PR, each with exactly these keys:
- `source` (string, exactly `"github"`)
- `id` (string, format: `github:<owner>/<repo>:pr#<number>`)
- `url` (string, the PR's HTML URL)
- `title` (string, the PR title)
- `summary` (string, 2-4 sentences synthesizing the PR title + body — NOT a verbatim copy of the body)
- `timestamp` (string, ISO 8601, equal to mergedAt)
- `author` (string, the PR author login — unwrap from author.login object)
- `raw` (object, containing at minimum: `number`, `additions`, `deletions`, `body_excerpt` (first 500 chars))

## Fail conditions
- Missing key on any signal
- `id` doesn't match the expected format
- `summary` is a verbatim copy of `body_excerpt`
- Output is not strict JSON
