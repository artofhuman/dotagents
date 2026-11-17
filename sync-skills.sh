#!/usr/bin/env bash
# Install skills from skills.txt into skills/ and link all skills into Claude dirs.
# Rerun to update.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
dest_dir="$root/skills"
claude_dirs=("$HOME/.claude" "$HOME/.claude-work")
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

re='^https://github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+)$'

# Line format: <url> [name]
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  read -r url alias _ <<< "$line" || true
  [[ -z "${url:-}" ]] && continue

  if [[ ! "$url" =~ $re ]]; then
    echo "skip: bad url: $url" >&2
    continue
  fi
  owner="${BASH_REMATCH[1]}" repo="${BASH_REMATCH[2]}"
  ref="${BASH_REMATCH[3]}" path="${BASH_REMATCH[4]%/}"
  name="${alias:-$(basename "$path")}"
  src="$tmp/$owner-$repo-$ref"

  # One sparse clone per repo+ref
  if [[ ! -d "$src" ]]; then
    git clone -q --depth 1 --filter=blob:none --sparse --branch "$ref" \
      "https://github.com/$owner/$repo.git" "$src"
  fi
  git -C "$src" sparse-checkout add "$path"

  if [[ ! -f "$src/$path/SKILL.md" ]]; then
    echo "skip: no SKILL.md in $url" >&2
    continue
  fi

  rm -rf "${dest_dir:?}/$name"
  cp -R "$src/$path" "$dest_dir/$name"
  # Keep frontmatter name in sync with dir name
  sed -i.bak "1,/^---\$/s/^name:.*/name: $name/" "$dest_dir/$name/SKILL.md"
  rm "$dest_dir/$name/SKILL.md.bak"
  echo "installed: $name"
done < "$root/skills.txt"

# Link every skill into each Claude config dir
for dir in "${claude_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  mkdir -p "$dir/skills"

  # Drop links to skills that no longer exist
  for link in "$dir/skills"/*; do
    if [[ -L "$link" && ! -e "$link" && "$(readlink "$link")" == "$dest_dir/"* ]]; then
      rm "$link"
    fi
  done

  for skill in "$dest_dir"/*/; do
    skill="${skill%/}"
    [[ -f "$skill/SKILL.md" ]] || continue
    target="$dir/skills/$(basename "$skill")"
    if [[ -e "$target" && ! -L "$target" ]]; then
      echo "skip: $target exists and is not a link" >&2
      continue
    fi
    ln -sfn "$skill" "$target"
  done
  echo "linked: $dir/skills"
done
