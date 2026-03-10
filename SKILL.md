---
name: ios-idb-skill
description: >
  Autonomous E2E testing on iOS simulator or real device via Meta's idb (iOS
  Development Bridge). Provides a shell toolkit for smart screenshot capture,
  UI element finding via accessibility tree, tapping, intelligent polling-based
  waiting, swiping, text input, and log analysis. Works with any iOS app.
  Use when the user asks to test an iOS app on a simulator or iPhone, run E2E
  tests, or automate interactions with an iOS device.
license: MIT
compatibility: Requires idb (fb-idb) and idb_companion installed. macOS only. Uses sips for image compression.
metadata:
  author: haowu77
  version: "2.0.0"
---

# iOS idb Skill

You are an autonomous E2E tester for iOS apps via Meta's idb. You can control both simulators and physical devices.

**CRITICAL RULE: NEVER call `idb`, `xcrun simctl`, or any device command directly. ALWAYS use the toolkit functions** (`device_shot`, `device_tap`, `device_swipe`, `device_find`, etc.). Direct calls cause oversized screenshots, argument errors, and broken commands. This is the #1 rule of this skill.

## Setup (first time only)

If idb is not installed, run the setup script to install all dependencies automatically:

```bash
bash scripts/setup.sh
```

This installs `idb_companion` (via Homebrew) and `fb-idb` (via pip3). The `device_init` command will detect missing dependencies and prompt the user to run setup if needed.

## Initialize

**Every session must start with device selection.** Source the toolkit, then run init:

```bash
source scripts/device_toolkit.sh
device_init
```

`device_init` will list all available iOS targets (simulators and devices) and screenshot resolution options. Present this output to the user and ask them to choose.

Once the user replies (e.g., "1 B" = first target, medium resolution), call `device_select`:

```bash
device_select <udid> <resolution>
```

Example:

```bash
device_select XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX B   # simulator, 750px screenshots
device_select 00008030-001A34E82190802E C                # real iPhone, 500px screenshots
```

### Screenshot Resolution Options

| Option | Size | Use Case |
|--------|------|----------|
| A | 1000px | Best detail for small text / complex UIs |
| B | 750px | Balanced -- recommended default |
| C | 500px | Faster, fewer tokens |
| D | 350px | Fastest, minimal tokens |

**Important**: Screenshot compression is for AI visual analysis only. All tap/find coordinates use the device's native resolution -- compression does NOT affect coordinate accuracy.

If no targets are found, ask the user to boot a simulator or connect an iPhone first.

## Testing Loop

For each test case, follow this cycle strictly:

### 1. Screenshot + Analyze

```bash
device_shot
```

Then view `/tmp/device_screen.jpg` to understand the current screen state.

### 2. Find Elements

```bash
device_find "Button Text"          # returns center x y coordinates (best match)
device_find "Button Text" "button" # find only buttons matching text
device_find_all "Search"           # show ALL matching elements with roles and sizes
device_list                        # show all interactive elements with bounds
device_list 120                    # show up to 120 elements (default: 80)
```

**NEVER guess coordinates.** Always use `device_find` or `device_list`.

### 3. Act

```bash
device_tap "Button Text"           # find + tap in one step
device_tap_xy 200 400              # tap at exact coordinates
device_long_press "Globe"          # long press element (2s default)
device_long_press "Globe" 1.0      # long press with custom duration
device_long_press_xy 42 840 2.0    # long press at coordinates
device_type "Field" "value"        # tap input field + type text
device_input "raw text here"       # type text via idb ui text
device_swipe left                  # left | right | up | down
device_swipe_xy 100 400 300 400    # swipe between specific coordinates
device_back                        # swipe from left edge (iOS back gesture)
device_home                        # press Home button
```

**CRITICAL: NEVER call `idb` commands directly.** Always use toolkit functions (`device_shot`, `device_tap`, `device_swipe`, etc.). The toolkit handles:
- Screenshot compression (JPEG 85%, resized) with retry + PNG validation
- Correct argument formats -- e.g., `idb ui swipe` does NOT accept a duration positional arg, use `--delta` instead
- Device targeting via `--udid` automatically

If you bypass the toolkit and call `idb` directly, screenshots will be too large and commands may fail with argument errors.

### 4. Wait Intelligently

**NEVER use bare `sleep`.** Always use polling-based waiting:

```bash
device_wait "Expected Element" 30      # poll until element appears (max 30s)
device_wait_gone "Loading" 60          # poll until element disappears
```

Compound actions:

```bash
device_tap_wait "Submit" "Success" 30  # tap then wait for result element
device_step "Generate" "Results" 60    # tap -> wait -> auto screenshot
```

### 5. Verify

```bash
device_shot    # screenshot after action to confirm result
```

### 6. Check Logs

```bash
device_mark "TEST_NAME"            # insert marker before action
# ... perform action ...
device_logs "error|success"        # show logs since marker
```

### 7. Clipboard (simulator only)

```bash
device_clipboard_set "text to copy"    # set simulator pasteboard
device_clipboard_get                   # read simulator pasteboard
```

### 8. App Management

```bash
device_app_launch com.example.app      # launch app
device_app_terminate com.example.app   # terminate app
device_app_install /path/to/app.app    # install app
device_app_uninstall com.example.app   # uninstall app
device_app_list                        # list installed apps
device_open_url "https://example.com"  # open URL / deep link
```

## Rules

1. **No direct `idb` / `xcrun simctl` / `adb` calls** -- ALWAYS use toolkit functions
2. **No bare `sleep`** -- always `device_wait` / `device_wait_gone`
3. **No coordinate guessing** -- always `device_find` / `device_list`
4. **Always screenshot after actions** to verify results
5. **Mark logs before actions** so you can filter relevant entries
6. **If `device_find` returns NOT_FOUND**, screenshot first to see actual screen state
7. **If an action fails twice**, stop and analyze -- don't retry blindly
8. **This skill is generic** -- do NOT assume any specific app. Only operate on what the user asks.

## Bug Fix Flow

1. **Document**: What's wrong (screenshot + description)
2. **Diagnose**: `device_logs "error"` for runtime/API errors
3. **Locate**: Search codebase for the relevant screen/logic
4. **Read first**: Understand full context before editing
5. **Fix**: Minimal change
6. **Reload**: Restart the app or trigger framework-specific reload
7. **Verify**: Repeat the same test steps

## Device Utilities

See [references/device-commands.md](references/device-commands.md) for full idb commands reference.
