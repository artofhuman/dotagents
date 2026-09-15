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

# Context usage and 5h rate limit (with local reset time) as 10-cell bars. Built in jq: bash 3.2
# (/bin/sh) mangles multibyte literals appended in a loop.
usage=$(printf '%s' "$input" | jq -r '
  def bar($p):
    (($p * 10 / 100) | floor) as $raw
    | (if $p > 0 and $raw < 1 then 1 elif $raw > 10 then 10 else $raw end) as $f
    | (("\u25a0" * $f) // "") + (("\u25a1" * (10 - $f)) // "");
  [ (.context_window.used_percentage // empty | floor | "ctx: \(bar(.)) \(.)%"),
    (.rate_limits.five_hour // empty | select(.used_percentage != null)
     | "5h: \(bar(.used_percentage)) \(.used_percentage | floor)%"
       + (if .resets_at then " until \(.resets_at | strflocaltime("%H:%M"))" else "" end))
  ] | join(" | ")')

out="$model | $dir"
[ -n "$vcs" ] && out="$out | $vcs"
[ -n "$usage" ] && out="$out | $usage"
printf '%s' "$out"
