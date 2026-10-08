#!/usr/bin/env bash
# Claude Code status line, one line:
#   model | ctx bar cache   ...   cwd branch | 5h usage bar | weekly usage bar
# Bars carry percent on the right. On the left, the ctx bar carries context
# tokens and usage bars carry the time until reset.
# "cache" counts down the minutes until the prompt cache goes cold.
# Left and right groups are justified to the row width.
# The weekly bar is the model-scoped window (e.g. Fable) when the /usage cache
# has one for the current model, otherwise the all-models 7d window.
set -u
input=$(cat)
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
now=$(date +%s)

RST=$'\033[0m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; MAG=$'\033[35m'; CYN=$'\033[36m'
SEP="${DIM} | ${RST}"

# Bar colors as "r;g;b". Solid LOW below WARN_AT, then a gradient from
# HI_START at WARN_AT to HI_END at 100.
BAR_WIDTH=10
WARN_AT=80
USAGE_LOW="80;160;255"
USAGE_HI_START="80;160;255"
USAGE_HI_END="255;0;0"
CTX_LOW="144;238;144"
CTX_HI_START="255;255;0"
CTX_HI_END="255;0;0"
# Cache countdown: WARM at a fresh cache, MID at half the TTL, COLD at zero.
CACHE_WARM="0;200;0"
CACHE_MID="255;255;0"
CACHE_COLD="255;0;0"
FRAME=4               # Claude Code draws the status line 2 cells in from each edge
RIGHT_MARGIN=0        # extra cells kept free at the right edge

# Model tier colors, best to worst, keyed by the first word of the model name.
MODEL_COLOR_fable="0;200;0"
MODEL_COLOR_opus="170;220;0"
MODEL_COLOR_sonnet="255;160;0"
MODEL_COLOR_haiku="255;0;0"

# lerp_rgb FROM TO T SPAN -> "r;g;b" at T/SPAN of the way from FROM to TO
lerp_rgb() {
  local -a a b; IFS=';' read -ra a <<<"$1"; IFS=';' read -ra b <<<"$2"
  local t=$3 span=$4
  printf '%d;%d;%d' $(( a[0] + (b[0]-a[0]) * t / span )) \
    $(( a[1] + (b[1]-a[1]) * t / span )) $(( a[2] + (b[2]-a[2]) * t / span ))
}

# draw_bar PCT LOW HI_START HI_END [LABEL] [RIGHT] -> colored "[1m█▍   34%]"
# LABEL is written into the first cells and RIGHT (default: the percent)
# into the last. A letter on a filled cell is drawn in reverse video. Empty
# cells show the letter in the bar color. A letter on the partially filled
# cell rounds up to a filled cell, so text is never clipped. A blank one
# shows the fractional block.
draw_bar() {
  local pct=${1%.*} low=$2 hs=$3 he=$4 label=${5:-} num=${6-${1%.*}%}
  (( pct < 0 )) && pct=0; (( pct > 100 )) && pct=100
  local eighths=$(( (pct * BAR_WIDTH * 8 + 50) / 100 ))
  local full=$(( eighths / 8 )) part=$(( eighths % 8 ))
  local partials=("" "▏" "▎" "▍" "▌" "▋" "▊" "▉")
  local rgb
  if (( pct < WARN_AT )); then rgb=$low
  else rgb=$(lerp_rgb "$hs" "$he" $(( pct - WARN_AT )) $(( 100 - WARN_AT ))); fi
  # Filled letter cells use reverse video with the same fg color as the
  # blocks, so both cells carry one color value through tmux and Ink.
  local fg=$'\033[38;2;'"${rgb}m" onbar=$'\033[7;38;2;'"${rgb}m"
  local text; text=$(printf '%-*s' "$BAR_WIDTH" "$label")
  text="${text:0:BAR_WIDTH-${#num}}${num}"
  local out="" i ch
  for ((i=0; i<BAR_WIDTH; i++)); do
    ch=${text:i:1}; [[ "$ch" == " " ]] && ch=""
    if (( i < full || (i == full && part > 0) )) && [[ -n "$ch" ]]; then out+="${onbar}${ch}${RST}"
    elif (( i < full )); then out+="${fg}█${RST}"
    elif (( i == full && part > 0 )); then out+="${fg}${partials[$part]}${RST}"
    elif [[ -n "$ch" ]]; then out+="${fg}${ch}${RST}"
    else out+=" "; fi
  done
  printf '[%s]' "$out"
}

# to_epoch "1759777200" | "2026-10-06T19:00:00.148480+00:00" -> seconds
to_epoch() {
  local v=$1
  [[ -z "$v" ]] && return
  if [[ "$v" == *T* ]]; then
    v=${v%%[.+Z]*}; date -j -u -f '%Y-%m-%dT%H:%M:%S' "$v" +%s 2>/dev/null
  else printf '%s' "${v%.*}"; fi
}

# reset_text RESETS_AT -> "32m" | "3h" | "4d", or "" when unknown
reset_text() {
  local at; at=$(to_epoch "$1")
  [[ -z "$at" ]] && return
  local s=$(( at - now ))
  if   (( s >= 86400 )); then printf '%dd' $(( s / 86400 ))
  elif (( s >= 3600 ));  then printf '%dh' $(( s / 3600 ))
  else                        printf '%dm' $(( s > 60 ? s / 60 : 1 )); fi
}

# One jq pass over stdin, unit-separated. Tabs would collapse on empty fields.
IFS=$'\x1f' read -r model_name model_id fast cwd transcript ctx_pct ctx_used ctx_size fh_used fh_reset sd_used sd_reset < <(
  jq -r '[.model.display_name, .model.id, .fast_mode, (.workspace.current_dir // .cwd), .transcript_path,
          .context_window.used_percentage, .context_window.total_input_tokens, .context_window.context_window_size,
          .rate_limits.five_hour.used_percentage, .rate_limits.five_hour.resets_at,
          .rate_limits.seven_day.used_percentage, .rate_limits.seven_day.resets_at]
         | map(if . == null then "" else tostring end) | join("\u001f")' <<<"$input" 2>/dev/null)

# /usage cache that Claude Code persists in .claude.json: fallback for the
# 5h and 7d windows and the only source of the model-scoped weekly window.
c_fh_used=""; c_fh_reset=""; c_sd_used=""; c_sd_reset=""; sc_used=""; sc_reset=""
cache="$cfg/.claude.json"
if [[ -r "$cache" ]]; then
  IFS=$'\x1f' read -r c_fh_used c_fh_reset c_sd_used c_sd_reset sc_used sc_reset < <(
    jq -r --arg m "${model_name:-}" '
      .cachedUsageUtilization.utilization as $u
      | ($u.limits // [] | map(select(.kind == "weekly_scoped"
            and (.scope.model.display_name // "") != ""
            and ((.scope.model.display_name | ascii_downcase) as $n | $m | ascii_downcase | startswith($n))))
         | first) as $s
      | [$u.five_hour.utilization, $u.five_hour.resets_at,
         $u.seven_day.utilization, $u.seven_day.resets_at,
         $s.percent, $s.resets_at]
      | map(if . == null then "" else tostring end) | join("\u001f")' "$cache" 2>/dev/null)
fi

# --- model: "Fable 5.1" -> "F 5.1" --------------------------------------
model=${model_name:-$model_id}
read -r first rest <<<"$model"
tier="MODEL_COLOR_$(tr "[:upper:]" "[:lower:]" <<<"$first")"
model_col=$'\033[1m'; [[ -n "${!tier:-}" ]] && model_col=$'\033[1;38;2;'"${!tier}m"
[[ -n "${rest:-}" ]] && model="${first:0:1} ${rest}"
[[ "$fast" == "true" ]] && model+=" ⚡"

# --- usage bars ----------------------------------------------------------
d_used=${fh_used:-$c_fh_used}; d_reset=${fh_reset:-$c_fh_reset}
if [[ -n "$sc_used" ]]; then w_used=$sc_used; w_reset=$sc_reset
else w_used=${sd_used:-$c_sd_used}; w_reset=${sd_reset:-$c_sd_reset}; fi
daily=$(draw_bar "${d_used:-0}" "$USAGE_LOW" "$USAGE_HI_START" "$USAGE_HI_END" "$(reset_text "$d_reset")")
weekly=$(draw_bar "${w_used:-0}" "$USAGE_LOW" "$USAGE_HI_START" "$USAGE_HI_END" "$(reset_text "$w_reset")")

# --- cwd + branch --------------------------------------------------------
tilde="~"; loc="${CYN}${cwd/#$HOME/$tilde}${RST}"
if [[ -n "$cwd" ]]; then
  br=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null \
    || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  [[ -n "$br" ]] && loc+=" ${MAG} ${br}${RST}"
fi

# --- context bar ---------------------------------------------------------
if [[ -z "$ctx_pct" ]]; then
  if [[ -n "$ctx_used" && -n "$ctx_size" && "${ctx_size%.*}" != 0 ]]; then
    ctx_pct=$(( ${ctx_used%.*} * 100 / ${ctx_size%.*} )); else ctx_pct=0; fi
fi
tok=""; [[ -n "$ctx_used" ]] && tok="$(( (${ctx_used%.*} + 500) / 1000 ))k"
ctx=$(draw_bar "$ctx_pct" "$CTX_LOW" "$CTX_HI_START" "$CTX_HI_END" "$tok")

# --- prompt cache countdown ----------------------------------------------
# The cache goes cold TTL seconds after the last request that used it. The
# request was sent at the transcript entry just before the first block of the
# last assistant message. Block timestamps mark when each block finished, which
# can be minutes after the send. TTL is 1h or 5m, read from the newest cache
# write. A request still in flight is not counted yet, so the number runs low.
if [[ -r "${transcript:-}" ]]; then
  IFS=$'\x1f' read -r sent ttl < <(tail -n 300 "$transcript" | jq -Rrs '
    [split("\n")[] | fromjson? | select(.timestamp != null and (.isSidechain | not))] as $e
    | [range($e | length) | select($e[.].type == "assistant" and $e[.].message.usage != null)] as $ai
    | select($ai | length > 0)
    | $e[$ai[-1]].message.id as $id
    | ([$ai[] | select($e[.].message.id == $id)] | min) as $first
    | [$ai[] | $e[.].message.usage.cache_creation // {}
       | if (.ephemeral_1h_input_tokens // 0) > 0 then 3600
         elif (.ephemeral_5m_input_tokens // 0) > 0 then 300 else empty end] as $ttls
    | [($e[[$first - 1, 0] | max].timestamp | sub("\\.[0-9]+"; "") | fromdateiso8601),
       ($ttls | last // 3600)]
    | map(tostring) | join("\u001f")' 2>/dev/null)
  if [[ -n "${sent:-}" ]]; then
    remain=$(( sent + ttl - now )) half=$(( ttl / 2 ))
    if (( remain <= 0 )); then ctx+=$' \033[38;2;'"${CACHE_COLD}mcold${RST}"
    else
      if (( remain > half )); then rgb=$(lerp_rgb "$CACHE_MID" "$CACHE_WARM" $(( remain - half )) "$half")
      else rgb=$(lerp_rgb "$CACHE_COLD" "$CACHE_MID" "$remain" "$half"); fi
      ctx+=$' \033[38;2;'"${rgb}m$(( (remain + 59) / 60 ))m${RST}"
    fi
  fi
fi

# --- layout -----------------------------------------------------------------
# left:  model | ctx bar          right: cwd branch | 5h bar | weekly bar
# Right group is right-justified. When the row is too narrow, shrink in this
# order: cwd to its basename, drop weekly, drop cwd, drop 5h, drop model.
# The context bar is always shown.

# Live width. COLUMNS from Claude Code is the width at startup and goes stale
# after a resize, so read the parent's tty (or tmux) first.
cols=0
ptty=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')
[[ -n "$ptty" && "$ptty" != "??" ]] && cols=$(stty size <"/dev/$ptty" 2>/dev/null | awk '{print $2}')
(( ${cols:-0} > 0 )) || { [[ -n "${TMUX:-}" ]] && cols=$(tmux display -p -t "${TMUX_PANE:-}" '#{pane_width}' 2>/dev/null); }
(( ${cols:-0} > 0 )) || cols=${COLUMNS:-0}
(( ${cols:-0} > 0 )) || cols=120
cols=$(( cols - FRAME - RIGHT_MARGIN ))

# Display width: strip ANSI, count chars in UTF-8, then add one per emoji
# that renders two cells wide.
vlen() {
  local plain; plain=$(LC_ALL=en_US.UTF-8 sed $'s/\033\\[[0-9;]*m//g' <<<"$1")
  local n; n=$(LC_ALL=en_US.UTF-8 bash -c 'printf %s "${#1}"' _ "$plain")
  local nobolt; nobolt=$(LC_ALL=en_US.UTF-8 bash -c 'x=${1//⚡/}; printf %s "${#x}"' _ "$plain")
  printf '%d' $(( n + (n - nobolt) ))
}
join() { local out="" p; for p in "$@"; do [[ -n "$p" ]] && out+="${out:+$SEP}$p"; done; printf '%s' "$out"; }

f_model="${model_col}${model}${RST}"
f_weekly=$weekly; f_loc=$loc; f_daily=$daily
for step in none basename weekly loc daily model; do
  case $step in
    basename) f_loc="${CYN}${cwd##*/}${RST}${br:+ ${MAG} ${br}${RST}}" ;;
    weekly)   f_weekly="" ;;
    loc)      f_loc="" ;;
    daily)    f_daily="" ;;
    model)    f_model="" ;;
  esac
  left=$(join "$f_model" "$ctx"); right=$(join "$f_loc" "$f_daily" "$f_weekly")
  if [[ -n "$right" ]]; then need=$(( $(vlen "$left") + 1 + $(vlen "$right") ))
  else need=$(vlen "$left"); fi
  (( need <= cols )) && break
done
if [[ -n "$right" ]]; then
  gap=$(( cols - $(vlen "$left") - $(vlen "$right") )); (( gap < 1 )) && gap=1
  printf '%s%*s%s\n' "$left" "$gap" "" "$right"
else
  printf '%s\n' "$left"
fi
