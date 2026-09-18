#!/bin/bash

# Claude Code Statusline
# Line 1: Model │ Context bar │ Git branch │ +added -removed │ Files
# Line 2: 5h rate limit + reset time
# Line 3: 7d rate limit + reset time
#
# 入力は Claude Code が stdin に渡す JSON。フィールド定義:
#   https://code.claude.com/docs/en/statusline
# rate_limits は Claude.ai Pro/Max のみ、かつセッション最初の API 応答以降にのみ
# 存在するため、すべて `// empty` で不在を許容する。

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

# resets_at は Unix epoch 秒。ローカルタイムゾーンで整形する。
fmt_reset() {
  local epoch="$1" fmt="$2"
  [ -n "$epoch" ] || return 0
  date -r "$epoch" "$fmt" 2>/dev/null
}

# rate_limits の 1 ウィンドウを 1 行として描画する。
render_window() {
  local icon="$1" pct_raw="$2" reset_epoch="$3" reset_fmt="$4"
  [ -n "$pct_raw" ] || return 0
  local pct color bar reset_str
  pct=$(printf "%.0f" "$pct_raw")
  color=$(color_for_pct "$pct")
  bar=$(progress_bar "$pct")
  reset_str=$(fmt_reset "$reset_epoch" "$reset_fmt")
  local suffix=""
  [ -n "$reset_str" ] && suffix="  ${DIM}resets at ${reset_str}${RESET}"
  printf '%b\n' "${icon} ${color}${bar} $(printf "%3d" "$pct")%${RESET}${suffix}"
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

GIT_PART=""
FILES_PART=""
if git rev-parse --git-dir &>/dev/null; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ "${#BRANCH}" -gt 20 ]; then
    BRANCH="${BRANCH:0:20}…"
  fi
  FILE_COUNT=$({ git diff --name-only 2>/dev/null; git diff --cached --name-only 2>/dev/null; } | sort -u | grep -c . || true)
  GIT_PART="${SEP}󰘬 ${BRANCH}"
  FILES_PART="${SEP}󰈮 ${FILE_COUNT}"
fi

CTX_PCT_FMT=$(printf "%3d" "$CTX_PCT")
printf '%b\n' "󰚩 ${MODEL}${SEP}󰧑 ${CTX_COLOR}${CTX_BAR} ${CTX_PCT_FMT}%${RESET}${GIT_PART}${SEP}${GREEN}+${LINES_ADDED}${RESET} ${RED}-${LINES_REMOVED}${RESET}${FILES_PART}"

# === Lines 2-3: Rate Limits ===
# Claude Code が stdin で渡す .rate_limits をそのまま使う。
# (旧実装はキーチェーンから OAuth トークンを取り出して未公開 API を叩いていたが、
#  同じ値が公式に stdin へ来るようになったため撤去した)

render_window "󰥔" \
  "$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')" \
  "$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty')" \
  "+%-H:%M"

render_window "󰃭" \
  "$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty')" \
  "$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty')" \
  "+%-m/%-d %-H:%M"
