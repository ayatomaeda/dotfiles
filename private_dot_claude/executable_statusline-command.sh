#!/bin/bash

# Claude Code Statusline
# Line 1: Model │ Context bar │ +added -removed │ Git branch │ Files
# Line 2: 5h rate limit + reset time
# Line 3: 7d rate limit + reset time

INPUT=$(cat)

if ! command -v jq &>/dev/null; then
  echo "jq not found"
  exit 0
fi

# --- Colors ---
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

color_for_pct() {
  local pct=${1:-0}
  if (( pct >= 80 )); then printf '%b' "$RED"
  elif (( pct >= 50 )); then printf '%b' "$YELLOW"
  else printf '%b' "$GREEN"
  fi
}

progress_bar() {
  local pct=${1:-0}
  local filled=$(( pct / 10 ))
  (( filled > 10 )) && filled=10
  local empty=$(( 10 - filled ))
  local bar=""
  for (( i=0; i<filled; i++ )); do bar+="▰"; done
  for (( i=0; i<empty; i++ )); do bar+="▱"; done
  printf '%s' "$bar"
}

convert_to_tokyo() {
  local iso_ts="$1" fmt="$2"
  local clean
  clean=$(echo "$iso_ts" | sed 's/\.[0-9]*//' | sed 's/+\([0-9][0-9]\):\([0-9][0-9]\)$/+\1\2/')
  local epoch
  epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$clean" "+%s" 2>/dev/null)
  if [ -n "$epoch" ]; then
    TZ=Asia/Tokyo date -r "$epoch" "$fmt" 2>/dev/null
  fi
}

SEP=" ${DIM}│${RESET} "

# === Line 1: Session Info ===

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "?"')

CTX_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_PCT=${CTX_PCT:-0}
CTX_COLOR=$(color_for_pct "$CTX_PCT")
CTX_BAR=$(progress_bar "$CTX_PCT")

LINES_ADDED=$(echo "$INPUT" | jq -r '.cost.total_lines_added // 0')
LINES_REMOVED=$(echo "$INPUT" | jq -r '.cost.total_lines_removed // 0')

GIT_ICON=$'\ue0a0'
GIT_PART=""
FILES_PART=""
if git rev-parse --git-dir &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ "${#BRANCH}" -gt 20 ]; then
    BRANCH="${BRANCH:0:20}…"
  fi
  FILE_COUNT=$({ git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null; } | sort -u | grep -c . || true)
  GIT_PART="${SEP}${GIT_ICON} ${BRANCH}"
  FILES_PART="${SEP}󰈮 ${FILE_COUNT}"
fi

printf '%b\n' "󰚩 ${MODEL}${SEP}󰧑 ${CTX_COLOR}${CTX_BAR} ${CTX_PCT}%${RESET}${GIT_PART}${SEP}${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}${FILES_PART}"

# === Lines 2-3: Rate Limits ===

CACHE_FILE="/tmp/claude-statusline-usage-cache.json"
CACHE_TTL=60

get_usage() {
  if [ -f "$CACHE_FILE" ]; then
    local now mtime age
    now=$(date +%s)
    mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    age=$(( now - mtime ))
    if (( age < CACHE_TTL )); then
      cat "$CACHE_FILE"
      return 0
    fi
  fi

  local token
  token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
  if [ -z "$token" ]; then
    [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
    return $?
  fi

  local resp
  resp=$(curl -s --max-time 3 \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

  if echo "$resp" | jq -e '.five_hour' &>/dev/null; then
    echo "$resp" > "$CACHE_FILE"
    echo "$resp"
    return 0
  fi

  [ -f "$CACHE_FILE" ] && cat "$CACHE_FILE"
  return $?
}

USAGE=$(get_usage 2>/dev/null)

if [ -n "$USAGE" ]; then
  FIVE_UTL=$(echo "$USAGE" | jq -r '.five_hour.utilization // empty')
  FIVE_RESET=$(echo "$USAGE" | jq -r '.five_hour.resets_at // empty')

  if [ -n "$FIVE_UTL" ]; then
    FIVE_PCT=$(printf "%.0f" "$FIVE_UTL")
    FIVE_COLOR=$(color_for_pct "$FIVE_PCT")
    FIVE_BAR=$(progress_bar "$FIVE_PCT")
    FIVE_RESET_STR=""
    [ -n "$FIVE_RESET" ] && FIVE_RESET_STR=$(convert_to_tokyo "$FIVE_RESET" "+%H:%M")
    printf '%b\n' "󰥔 ${FIVE_COLOR}${FIVE_BAR} ${FIVE_PCT}%${RESET}  ${DIM}resets at ${FIVE_RESET_STR}${RESET}"
  fi

  SEVEN_UTL=$(echo "$USAGE" | jq -r '.seven_day.utilization // empty')
  SEVEN_RESET=$(echo "$USAGE" | jq -r '.seven_day.resets_at // empty')

  if [ -n "$SEVEN_UTL" ]; then
    SEVEN_PCT=$(printf "%.0f" "$SEVEN_UTL")
    SEVEN_COLOR=$(color_for_pct "$SEVEN_PCT")
    SEVEN_BAR=$(progress_bar "$SEVEN_PCT")
    SEVEN_RESET_STR=""
    [ -n "$SEVEN_RESET" ] && SEVEN_RESET_STR=$(convert_to_tokyo "$SEVEN_RESET" "+%m/%d %H:%M")
    printf '%b\n' "󰃭 ${SEVEN_COLOR}${SEVEN_BAR} ${SEVEN_PCT}%${RESET}  ${DIM}resets at ${SEVEN_RESET_STR}${RESET}"
  fi
fi
