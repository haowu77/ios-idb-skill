# ios-idb-skill

An [Agent Skill](https://agentskills.io) for autonomous E2E testing on iOS devices (simulators and iPhones) via Meta's [idb](https://github.com/facebook/idb).

Works with **any** AI coding agent that supports the [Agent Skills](https://agentskills.io) standard:
Claude Code, Cursor, GitHub Copilot, Gemini CLI, VS Code, Roo Code, OpenAI Codex, OpenHands, and more.

## What it does

Provides a shell toolkit and testing workflow for AI agents to interact with any iOS app:

- **Target selection** -- auto-discovers simulators and connected iPhones, remembers choice for session
- **Screenshot + AI analysis** -- 4 compression levels to balance detail vs token cost
- **Smart element finding** -- uses idb accessibility tree (`describe-all`) to locate elements by text, never guesses coordinates
- **Intelligent waiting** -- polls for UI changes instead of `sleep`, no wasted time
- **One-step actions** -- `device_tap "Button"` finds and taps in one call
- **Log analysis** -- markers + filtered search for debugging
- **App management** -- install, launch, terminate, uninstall apps

Works with any iOS app -- native Swift/SwiftUI, UIKit, Flutter, React Native, etc.

## Prerequisites

### Quick setup (recommended)

The skill includes an automatic installer that handles all dependencies:

```bash
bash scripts/setup.sh
```

This will install Homebrew (if needed), `idb_companion`, and `fb-idb`. It also verifies the installation.

If dependencies are missing when you run `device_init`, the skill will detect this and prompt you to run setup.

### Manual install

```bash
# Install idb_companion (macOS only)
brew tap facebook/fb
brew install idb-companion

# Install idb client (Python)
pip3 install fb-idb
```

### Verify installation

```bash
idb list-targets    # should show available simulators/devices
```

For real devices: enable Developer Mode in Settings > Privacy & Security, and trust the computer when prompted.

## Install the skill

Clone this repo into your agent's skills directory.

### Claude Code

```bash
# Personal (all projects)
git clone https://github.com/haowu77/ios-idb-skill ~/.claude/skills/ios-idb-skill

# Project-level (this repo only)
git clone https://github.com/haowu77/ios-idb-skill .claude/skills/ios-idb-skill
```

### OpenAI Codex

```bash
git clone https://github.com/haowu77/ios-idb-skill ~/.codex/skills/ios-idb-skill
```

### Cursor

```bash
git clone https://github.com/haowu77/ios-idb-skill .cursor/skills/ios-idb-skill
```

### VS Code / GitHub Copilot

```bash
git clone https://github.com/haowu77/ios-idb-skill .github/skills/ios-idb-skill
```

### Roo Code

```bash
git clone https://github.com/haowu77/ios-idb-skill .roo/skills/ios-idb-skill
```

### Gemini CLI

```bash
git clone https://github.com/haowu77/ios-idb-skill .gemini/skills/ios-idb-skill
```

### Other agents

Copy this repo into wherever your agent reads skills from. The only requirement is a directory named `ios-idb-skill` containing `SKILL.md`.

## Usage

Invoke with `/ios-idb-skill` or let the agent auto-detect based on context.

On first use, the skill runs `device_init` to list available iOS targets and let you pick one + a screenshot resolution.

## Toolkit Commands

| Command | Description |
|---------|-------------|
| `device_init` | List targets + resolution options |
| `device_select <udid> <res>` | Set target + resolution for session |
| `device_shot` | Screenshot (compressed for AI) |
| `device_find "text"` | Find element -> returns x y |
| `device_tap "text"` | Find + tap element |
| `device_wait "text"` | Poll until element appears |
| `device_wait_gone "text"` | Poll until element disappears |
| `device_tap_wait "tap" "wait"` | Tap -> wait for next element |
| `device_step "tap" "wait"` | Tap -> wait -> auto screenshot |
| `device_list` | Show all interactive elements |
| `device_swipe left\|right\|up\|down` | Swipe gesture |
| `device_type "field" "text"` | Tap field + type text |
| `device_input "text"` | Type text directly |
| `device_back` | iOS back gesture (swipe from left edge) |
| `device_home` | Home button |
| `device_lock` | Lock button |
| `device_mark` / `device_logs` | Log markers + filtered search |
| `device_log_stream` | Start streaming device logs |
| `device_app_list` | List installed apps |
| `device_app_launch` | Launch app by bundle ID |
| `device_app_terminate` | Terminate app by bundle ID |
| `device_app_install` | Install .app or .ipa |
| `device_app_uninstall` | Uninstall app |
| `device_info` | Show target details |

## Requirements

- macOS (idb_companion is macOS only)
- `idb` and `idb_companion` installed
- iOS Simulator booted or real device connected
- `sips` (ships with macOS) for image compression

## Skill Structure

```
ios-idb-skill/
├── SKILL.md                          # Skill instructions (Agent Skills standard)
├── README.md                         # This file
├── scripts/
│   ├── device_toolkit.sh             # Shell function library
│   └── setup.sh                      # Dependency installer
└── references/
    └── device-commands.md            # idb commands reference
```

Follows the [Agent Skills specification](https://agentskills.io/specification).

## License

MIT
