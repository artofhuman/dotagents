#!/bin/sh
# Status line script for Claude Code (settings.json -> statusLine.command).
# Shows: model[effort] | directory | vcs change/branch | context usage | 5h limit.

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  printf 'claude'
  exit 0
fi

model=$(printf '%s' "$input" | jq -r '
  (.model.display_name // .model // "?")
  + (if .effort.level then "[\(.effort.level)]" else "" end)')
cwd=$(printf '%s' "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // "."')
dir=$(basename "$cwd")

vcs=""
if [ -e "$cwd/.jj" ] && command -v jj >/dev/null 2>&1; then
  vcs=$(cd "$cwd" && jj log -r @ --no-graph --ignore-working-copy \
    -T 'change_id.shortest(8)' 2>/dev/null)
  [ -n "$vcs" ] && vcs="jj:$vcs"
fi
if [ -z "$vcs" ]; then
  branch=$(cd "$cwd" 2>/dev/null && git branch --show-current 2>/dev/null)
  [ -n "$branch" ] && vcs="git:$branch"
fi

# Context usage and 5h rate limit (with local reset time). Meters are 4-cell
# bars; the leading cell steps through the shade ramp, so the step is 8% instead
# of 25%. Every glyph fills its whole cell, so the bar has no gaps. Built in jq:
# bash 3.2 (/bin/sh) mangles multibyte literals.
usage=$(printf '%s' "$input" | jq -r '
  def bar($p):
    4 as $n
    | (($p * $n * 3 / 100) | floor)
    | (if $p > 0 and . < 1 then 1 elif . > $n * 3 then $n * 3 else . end) as $t
    | ($t / 3 | floor) as $full
    | (("\u2588" * $full) // "")
      + (if $full >= $n then ""
         else ("\u2591\u2592\u2593" | .[$t - $full * 3 : $t - $full * 3 + 1]) end)
      + (("\u2591" * ($n - $full - 1)) // "");
  [ (.context_window.used_percentage // empty | floor | "ctx: \(bar(.)) \(.)%"),
    (.rate_limits.five_hour // empty | select(.used_percentage != null)
     | "5h: \(bar(.used_percentage)) \(.used_percentage | floor)%"
       + (if .resets_at then " until \(.resets_at | strflocaltime("%H:%M"))" else "" end))
  ] | join(" | ")')

out="$model | $dir"
[ -n "$vcs" ] && out="$out | $vcs"
[ -n "$usage" ] && out="$out | $usage"
printf '%s' "$out"
