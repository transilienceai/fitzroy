#!/usr/bin/env bash
# Install the storyteller + linkedin-ads skills into ~/.claude/skills/ via symlink
# and bootstrap user data dirs at ~/.storyteller/ and ~/.linkedinads/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_TO_INSTALL=(storyteller kk-voice kk-short-form linkedin-ads linkedin-post-grader)

mkdir -p "${HOME}/.claude/skills"

for skill in "${SKILLS_TO_INSTALL[@]}"; do
  src="${REPO_ROOT}/skill/${skill}"
  dest="${HOME}/.claude/skills/${skill}"
  if [[ ! -d "${src}" ]]; then
    echo "Skill source missing: ${src}" >&2
    exit 1
  fi
  if [[ -e "${dest}" || -L "${dest}" ]]; then
    echo "Removing existing ${dest}"
    rm -rf "${dest}"
  fi
  ln -s "${src}" "${dest}"
  echo "Linked ${dest} -> ${src}"
done

# ~/.storyteller/ — storyteller user data
ST_DATA="${HOME}/.storyteller"
mkdir -p "${ST_DATA}/pending-video" "${ST_DATA}/failed-pushes" "${ST_DATA}/images"
if [[ ! -f "${ST_DATA}/config.yaml" ]]; then
  cp "${REPO_ROOT}/skill/storyteller/sample-config.yaml" "${ST_DATA}/config.yaml"
  echo "Created ${ST_DATA}/config.yaml from sample. Edit it to add your repos."
fi
touch "${ST_DATA}/state.jsonl"

# ~/.linkedinads/ — linkedin-ads user data
LA_DATA="${HOME}/.linkedinads"
mkdir -p "${LA_DATA}/staging" "${LA_DATA}/images" "${LA_DATA}/failed-images"
if [[ ! -f "${LA_DATA}/config.yaml" ]]; then
  cp "${REPO_ROOT}/skill/linkedin-ads/sample-config.yaml" "${LA_DATA}/config.yaml"
  echo "Created ${LA_DATA}/config.yaml from sample. Edit audiences[] and offers[] before first /linkedin-ad run."
fi

cat <<'EOF'

StoryTeller + linkedin-ads installed.

NEXT STEPS:
  1. Edit ~/.storyteller/config.yaml — add at least one repo under sources.github.repos
  2. Edit ~/.linkedinads/config.yaml — review the seeded audiences[] and offers[];
     swap in real Transilience landing-page URLs and customer-exclusion lists.
  3. Ensure POSTIZ_API_KEY is available to your shell. If not yet persistent,
     add this to your ~/.zshrc (replace the path if your key file is elsewhere):

       export POSTIZ_API_KEY="$(tr -d '[:space:]' < "${REPO_ROOT}/Postiz Key.txt")"

     Then either: source ~/.zshrc  OR  open a new terminal so Claude Code inherits it.
  4. In Claude Code:
       /storyteller         — surface ranked post ideas from GitHub/Slack
       /linkedin-ad <topic> — stage a Transilience paid ad (Campaign Manager copy-paste)
       /grade-post <url>    — grade any LinkedIn post against the Jennifer filter (screenshot-shareable)

EOF
