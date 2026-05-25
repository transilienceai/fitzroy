#!/usr/bin/env bash
# Remove the storyteller skill symlink. Does NOT touch ~/.storyteller/
# (your config and state are preserved).
set -euo pipefail
SKILL_DEST="${HOME}/.claude/skills/storyteller"
if [[ -L "${SKILL_DEST}" ]]; then
  rm "${SKILL_DEST}"
  echo "Removed symlink ${SKILL_DEST}"
elif [[ -e "${SKILL_DEST}" ]]; then
  echo "Refusing to remove ${SKILL_DEST}: it is a directory, not a symlink." >&2
  echo "Remove it manually if you intended to." >&2
  exit 1
else
  echo "Nothing to remove at ${SKILL_DEST}"
fi
echo "Note: ~/.storyteller/ is preserved (config + state). Delete manually if you want a full reset."
