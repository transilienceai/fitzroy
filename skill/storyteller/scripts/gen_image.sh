#!/usr/bin/env bash
# gen_image.sh — Generate one image via Gemini API for a StoryTeller draft.
#
# Usage:
#   gen_image.sh "<image-prompt>" "<absolute-output-path>"
#
# Behavior:
#   - Reads GEMINI_API_KEY from env, falling back to "Gemini Key.txt" in
#     $HOME/Projects/StoryTeller/ (mirrors the Postiz Key.txt pattern).
#   - Prepends the Quiet Paper style block to every prompt (single source of truth
#     for KK's brand aesthetic — edit this block, not the caller).
#   - Defaults to gemini-3-pro-image-preview (Nano Banana Pro). Override via
#     STORYTELLER_IMAGE_MODEL env var.
#   - Writes the decoded PNG to <output-path>, validates magic bytes, prints the
#     absolute path on stdout. Exit 0 = success; exit non-zero = stderr explains.
#
# Error handling: never silently produces a bad image. If the API returns no
# inline image, or the bytes are not a valid PNG/JPEG, exit 1.

set -euo pipefail

PROMPT="${1:?usage: gen_image.sh <prompt> <output.png>}"
OUTPUT="${2:?usage: gen_image.sh <prompt> <output.png>}"
MODEL="${STORYTELLER_IMAGE_MODEL:-gemini-3-pro-image-preview}"
KEY_FILE="$HOME/Projects/StoryTeller/Gemini Key.txt"

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  if [[ -f "$KEY_FILE" ]]; then
    GEMINI_API_KEY=$(tr -d '[:space:]' < "$KEY_FILE")
  else
    echo "gen_image: GEMINI_API_KEY not set and $KEY_FILE not found" >&2
    exit 1
  fi
fi

DEFAULT_STYLE='Style: Quiet Paper editorial illustration. Warm off-white background, ink-dark text, a single muted accent color (deep teal, rust, or olive — pick one and commit). Hand-drawn or vector-clean lines, generous whitespace, minimal composition. No neon, no AI-glossy gradients, no stock-photo realism, no busy backgrounds. If text appears, it is sparse, large, and editorial — never crammed. Square 1080x1080. Read as a thoughtful operator brief, not a marketing banner.'

# Style override: callers (e.g. linkedin-ads) can supply their own STYLE block via
# the IMAGE_STYLE env var. If unset, fall back to the Quiet-Paper default above
# (storyteller's brand aesthetic for organic posts).
STYLE="${IMAGE_STYLE:-$DEFAULT_STYLE}"

FULL_PROMPT="$STYLE

Subject: $PROMPT"

BODY=$(jq -nc --arg p "$FULL_PROMPT" '{contents:[{parts:[{text:$p}]}]}')

RESPONSE=$(curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY")

IMG_B64=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[]? | select(.inlineData?) | .inlineData.data' | head -1)

if [[ -z "$IMG_B64" || "$IMG_B64" == "null" ]]; then
  echo "gen_image: no inline image in response for model $MODEL" >&2
  echo "$RESPONSE" | jq '.error // .promptFeedback // .' >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
echo "$IMG_B64" | base64 -d > "$OUTPUT"

# Gemini may return JPEG even when the caller wrote .png — detect actual format
# from magic bytes and rename the file to match. Echo the final path so callers
# always get a truthful extension.
ACTUAL=""
if file "$OUTPUT" | grep -q 'PNG image'; then
  ACTUAL="png"
elif file "$OUTPUT" | grep -q 'JPEG image'; then
  ACTUAL="jpg"
else
  echo "gen_image: decoded output is not a valid PNG/JPEG: $(file "$OUTPUT")" >&2
  exit 1
fi

CORRECT_PATH="${OUTPUT%.*}.${ACTUAL}"
if [[ "$OUTPUT" != "$CORRECT_PATH" ]]; then
  mv "$OUTPUT" "$CORRECT_PATH"
fi

echo "$CORRECT_PATH"
