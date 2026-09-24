# Setup

1. git clone https://github.com/artofhuman/dotagents ~/.config/agents

# Pi agent

1. ln -s ~/.config/agents/pi/settings.json ~/.pi/agent/settings.json

# Claude

1. ln -s ~/.config/agents/claude/settings.json ~/.claude/settings.json
2. ln -s ~/.config/agents/claude/settings.json ~/.claude-work/settings.json

# Skills

Skills live in `skills/`. Add a new skill as a folder there, no extra links needed.

1. Claude: ln -s ~/.config/agents/skills ~/.claude/skills
2. Pi: loads `skills/` via the `skills` path in `pi/settings.json`
