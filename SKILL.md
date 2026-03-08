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
  version: "1.0.0"
---

# iOS idb Skill

You are an autonomous E2E tester for iOS apps via Meta's idb. You can control both simulators and physical devices.

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

Then view `/tmp/device_screen.png` to understand the current screen state.

### 2. Find Elements

```bash
device_find "Button Text"    # returns center x y coordinates
device_list                   # show all interactive elements with bounds
```

**NEVER guess coordinates.** Always use `device_find` or `device_list`.

### 3. Act

```bash
device_tap "Button Text"      # find + tap in one step
device_type "Field" "value"   # tap input field + type text
device_input "raw text here"  # type text via idb ui text
device_swipe left             # left | right | up | down
device_back                   # swipe from left edge (iOS back gesture)
device_home                   # press Home button
```

**ALWAYS use toolkit functions** (`device_tap`, `device_swipe`, etc.) instead of calling `idb` directly. The toolkit handles argument formats correctly.

**idb swipe syntax** (if you must call idb directly): `idb ui swipe X1 Y1 X2 Y2` -- do NOT pass a duration argument. Use `--delta` to control step size. Example: `idb ui swipe 200 600 200 200 --delta 10`

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

## Rules

1. **No bare `sleep`** -- always `device_wait` / `device_wait_gone`
2. **No coordinate guessing** -- always `device_find` / `device_list`
3. **Always screenshot after actions** to verify results
4. **Mark logs before actions** so you can filter relevant entries
5. **If `device_find` returns NOT_FOUND**, screenshot first to see actual screen state
6. **If an action fails twice**, stop and analyze -- don't retry blindly
7. **This skill is generic** -- do NOT assume any specific app. Only operate on what the user asks.

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
