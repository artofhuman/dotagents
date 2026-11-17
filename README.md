# Setup

1. git clone https://github.com/artofhuman/dotagents ~/.config/agents

# Pi agent

1. ln -s ~/.config/agents/pi/settings.json ~/.pi/agent/settings.json

# Claude

1. ln -s ~/.config/agents/claude/settings.json ~/.claude/settings.json
2. ln -s ~/.config/agents/claude/settings.json ~/.claude-work/settings.json

# Skills

Own skills live in `skills/` and are tracked in git. Third-party skills are listed in `skills.txt` (GitHub tree URLs) and are not tracked.

Run `./sync-skills.sh` to install or update third-party skills and link all skills into `~/.claude/skills` and `~/.claude-work/skills`.
Pi loads `skills/` directly via the `skills` path in `pi/settings.json`.

For an own skill, add `!skills/<name>/` to `.gitignore`.
