#!/bin/bash
# iOS idb Device Toolkit v2.0
# Works with simulators and real iOS devices via Meta's idb
# Requires: idb (fb-idb) + idb_companion installed
# Usage: source device_toolkit.sh

# ============ Session State ============
if [ -z "$_DEVICE_TOOLKIT_LOADED" ]; then
  IDB_TARGET=""
  IDB_SHOT_SIZE="750"
  IDB_SCREEN_W=""
  IDB_SCREEN_H=""
fi

# ============ Dependency Check ============

_check_deps() {
  local missing=0
  if ! command -v idb_companion &>/dev/null; then
    echo "idb_companion not found."
    missing=1
  fi
  if ! command -v idb &>/dev/null; then
    echo "idb client not found."
    missing=1
  fi
  if ! command -v python3 &>/dev/null; then
    echo "python3 not found."
    missing=1
  fi
  if [ $missing -eq 1 ]; then
    echo ""
    echo "Run the setup script to install dependencies:"
    echo "  bash scripts/setup.sh"
    return 1
  fi
  return 0
}

# ============ Initialization ============

device_init() {
  _check_deps || return 1

  echo "iOS Targets:"
  echo ""

  local listing
  listing=$(idb list-targets --json 2>/dev/null | python3 << 'PYEOF'
import sys, json

lines = sys.stdin.read().strip().splitlines()
i = 1
for line in lines:
    line = line.strip()
    if not line:
        continue
    try:
        t = json.loads(line)
    except:
        continue
    udid = t.get('udid', '')
    name = t.get('name', 'unknown')
    state = t.get('state', 'unknown')
    ttype = t.get('type', 'unknown')
    os_ver = t.get('os_version', 'unknown')
    if udid:
        print(f'  [{i}] {udid}')
        print(f'      {name} ({ttype}) -- iOS {os_ver}, {state}')
        i += 1
if i == 1:
    sys.exit(1)
PYEOF
  )

  if [ $? -ne 0 ] || [ -z "$listing" ]; then
    local plain
    plain=$(idb list-targets 2>/dev/null)
    if [ -z "$plain" ]; then
      echo "No iOS targets found."
      echo ""
      echo "To start a simulator:"
      echo "  xcrun simctl boot 'iPhone 16'"
      echo ""
      echo "For a real device: connect via USB with Developer Mode enabled."
      return 1
    fi
    echo "$plain"
  else
    echo "$listing"
  fi

  echo ""
  echo "Resolution: [A] 1000px  [B] 750px (recommended)  [C] 500px  [D] 350px"
  echo ""
  echo "Pick target UDID + resolution, e.g. copy the UDID then type resolution letter."
}

device_select() {
  local udid="$1"
  local res="$2"

  if ! idb describe --udid "$udid" >/dev/null 2>&1; then
    echo "ERROR: target '$udid' not found or not booted"
    return 1
  fi
  IDB_TARGET="$udid"

  case "$res" in
    A|a|1000) IDB_SHOT_SIZE=1000 ;;
    B|b|750)  IDB_SHOT_SIZE=750 ;;
    C|c|500)  IDB_SHOT_SIZE=500 ;;
    D|d|350)  IDB_SHOT_SIZE=350 ;;
    [0-9]*)   IDB_SHOT_SIZE="$res" ;;
    *)        IDB_SHOT_SIZE=750 ;;
  esac

  _detect_screen_size

  echo "Target set: $IDB_TARGET @ ${IDB_SHOT_SIZE}px (screen: ${IDB_SCREEN_W}x${IDB_SCREEN_H})"
}

_detect_screen_size() {
  local desc
  desc=$(_idb describe 2>/dev/null)
  local wp hp
  wp=$(echo "$desc" | grep -oE 'width_points=[0-9]+' | head -1 | cut -d= -f2)
  hp=$(echo "$desc" | grep -oE 'height_points=[0-9]+' | head -1 | cut -d= -f2)
  if [ -n "$wp" ] && [ -n "$hp" ]; then
    IDB_SCREEN_W="$wp"
    IDB_SCREEN_H="$hp"
  fi
  IDB_SCREEN_W=${IDB_SCREEN_W:-390}
  IDB_SCREEN_H=${IDB_SCREEN_H:-844}
}

# ============ idb Wrapper ============

_idb() {
  if [ -z "$IDB_TARGET" ]; then
    idb "$@"
    return
  fi

  local subcmd_count=1
  case "$1" in
    ui|file|crash|xctest|record) subcmd_count=2 ;;
  esac

  local cmd=(idb)
  local count=0
  for arg in "$@"; do
    if [ $count -lt $subcmd_count ]; then
      cmd+=("$arg")
    else
      break
    fi
    count=$((count + 1))
  done
  cmd+=(--udid "$IDB_TARGET")
  count=0
  for arg in "$@"; do
    if [ $count -ge $subcmd_count ]; then
      cmd+=("$arg")
    fi
    count=$((count + 1))
  done

  "${cmd[@]}"
}

# ============ Screenshot (with retry + validation) ============

device_shot() {
  local size=${1:-$IDB_SHOT_SIZE}
  local max_retries=3
  local attempt=0

  while [ $attempt -lt $max_retries ]; do
    attempt=$((attempt + 1))
    rm -f /tmp/device_raw.png

    local shot_err
    shot_err=$(_idb screenshot /tmp/device_raw.png 2>&1)

    # Check file exists and has content
    if [ ! -s /tmp/device_raw.png ]; then
      if [ $attempt -lt $max_retries ]; then
        sleep 0.5
        continue
      fi
      echo "ERROR: screenshot failed after $max_retries attempts: $shot_err" >&2
      return 1
    fi

    # Validate it's actually a PNG (first 4 bytes: 89 50 4E 47)
    local magic
    magic=$(xxd -l 4 -p /tmp/device_raw.png 2>/dev/null)
    if [ "$magic" != "89504e47" ]; then
      if [ $attempt -lt $max_retries ]; then
        sleep 0.5
        continue
      fi
      echo "ERROR: screenshot file is not a valid PNG (magic: $magic)" >&2
      return 1
    fi

    # Compress to JPEG
    if sips -Z "$size" /tmp/device_raw.png --out /tmp/device_screen.jpg \
        -s format jpeg -s formatOptions 85 >/dev/null 2>&1; then
      echo "/tmp/device_screen.jpg"
      return 0
    fi

    if [ $attempt -lt $max_retries ]; then
      sleep 0.5
      continue
    fi
    echo "ERROR: image compression failed (sips)" >&2
    return 1
  done
}

# ============ UI Tree (Accessibility) ============

device_dump() {
  local output
  output=$(_idb ui describe-all 2>/dev/null)
  if [ -z "$output" ]; then
    echo "ERROR: describe-all returned empty output. Is the target booted?" >&2
    return 1
  fi
  echo "$output" | python3 -c "
import sys
raw = sys.stdin.buffer.read()
text = raw.decode('utf-8', errors='replace')
lines = text.splitlines()
joined = ' '.join(lines)
sys.stdout.write(joined)
" > /tmp/ios_ui_tree.json 2>/dev/null
}

device_list() {
  local max_items=${1:-80}
  device_dump || return 1
  IDB_LIST_MAX="$max_items" python3 << 'PYEOF'
import json, sys, os

max_items = int(os.environ.get('IDB_LIST_MAX', '80'))

def parse_elements(data, results, depth=0):
    if isinstance(data, list):
        for item in data:
            parse_elements(item, results, depth)
        return
    if not isinstance(data, dict):
        return
    frame = data.get('frame', data.get('AXFrame', {})) or {}
    label = data.get('AXLabel', data.get('label', None))
    value = data.get('AXValue', data.get('value', None))
    role = data.get('role', data.get('AXRole', '')) or ''
    label = str(label) if label is not None else ''
    value = str(value) if value is not None else ''
    x = frame.get('x', 0) or 0
    y = frame.get('y', 0) or 0
    w = frame.get('width', 0) or 0
    h = frame.get('height', 0) or 0

    # Skip invisible or tiny elements
    if w < 5 or h < 5:
        for child in data.get('children', data.get('AXChildren', [])):
            parse_elements(child, results, depth + 1)
        return

    display = label or value or ''
    if display:
        cx = int(x + w / 2)
        cy = int(y + h / 2)
        results.append(f'{role:20s} "{display}"  [{int(x)},{int(y)}][{int(x+w)},{int(y+h)}]  center=({cx},{cy})')
    for child in data.get('children', data.get('AXChildren', [])):
        parse_elements(child, results, depth + 1)

try:
    with open('/tmp/ios_ui_tree.json') as f:
        tree = json.load(f)
    results = []
    parse_elements(tree, results)
    for r in results[:max_items]:
        print(r)
    if len(results) > max_items:
        print(f'... and {len(results) - max_items} more elements')
    if not results:
        print('(no interactive elements found)')
except json.JSONDecodeError:
    print('ERROR: UI tree is not valid JSON')
    with open('/tmp/ios_ui_tree.json') as f:
        print(f.read()[:2000])
except Exception as e:
    print(f'ERROR: {e}')
PYEOF
}

# ============ Find Elements ============

device_find() {
  local keyword="$1"
  local role_filter="${2:-}"  # Optional: "button", "textfield", "statictext", etc.
  if [ -z "$keyword" ]; then
    echo "Usage: device_find \"element text\" [role]" >&2
    return 1
  fi
  device_dump || return 1
  IDB_FIND_KEYWORD="$keyword" IDB_FIND_ROLE="$role_filter" python3 << 'PYEOF'
import json, sys, re, os

keyword = os.environ.get('IDB_FIND_KEYWORD', '')
role_filter = os.environ.get('IDB_FIND_ROLE', '').lower()

def find_all(data, results):
    if isinstance(data, list):
        for item in data:
            find_all(item, results)
        return
    if not isinstance(data, dict):
        return

    label = data.get('AXLabel', data.get('label', None))
    value = data.get('AXValue', data.get('value', None))
    title = data.get('AXTitle', data.get('title', None))
    role = data.get('role', data.get('AXRole', '')) or ''
    label = str(label) if label is not None else ''
    value = str(value) if value is not None else ''
    title = str(title) if title is not None else ''
    frame = data.get('frame', data.get('AXFrame', {})) or {}

    x = frame.get('x', 0) or 0
    y = frame.get('y', 0) or 0
    w = frame.get('width', 0) or 0
    h = frame.get('height', 0) or 0

    if w < 5 or h < 5:
        for child in data.get('children', data.get('AXChildren', [])):
            find_all(child, results)
        return

    # Role filter
    if role_filter and role_filter not in role.lower():
        for child in data.get('children', data.get('AXChildren', [])):
            find_all(child, results)
        return

    cx = int(x + w / 2)
    cy = int(y + h / 2)
    area = w * h
    pat = re.escape(keyword)

    for text in [label, title, value]:
        if text and re.search(pat, text, re.IGNORECASE):
            # Score: exact match > prefix > contains; larger area = more likely target
            score = 0
            if text.lower() == keyword.lower():
                score = 1000  # exact match
            elif text.lower().startswith(keyword.lower()):
                score = 500   # prefix match
            else:
                score = 100   # contains match
            # Prefer buttons and tappable elements
            if 'button' in role.lower():
                score += 50
            results.append((score, cx, cy, role, text, int(w), int(h)))
            break

    for child in data.get('children', data.get('AXChildren', [])):
        find_all(child, results)

try:
    with open('/tmp/ios_ui_tree.json') as f:
        tree = json.load(f)
    results = []
    find_all(tree, results)
    if results:
        # Sort by score descending, pick best match
        results.sort(key=lambda r: -r[0])
        best = results[0]
        print(f'{best[1]} {best[2]}')
    else:
        print(f"NOT_FOUND: '{keyword}'")
        sys.exit(1)
except json.JSONDecodeError:
    print(f"NOT_FOUND: '{keyword}' (invalid JSON from describe-all)")
    sys.exit(1)
except Exception as e:
    print(f"NOT_FOUND: '{keyword}' (error: {e})")
    sys.exit(1)
PYEOF
}

# Find all matching elements (returns multiple results)
device_find_all() {
  local keyword="$1"
  if [ -z "$keyword" ]; then
    echo "Usage: device_find_all \"element text\"" >&2
    return 1
  fi
  device_dump || return 1
  IDB_FIND_KEYWORD="$keyword" python3 << 'PYEOF'
import json, sys, re, os

keyword = os.environ.get('IDB_FIND_KEYWORD', '')

def find_all(data, results):
    if isinstance(data, list):
        for item in data:
            find_all(item, results)
        return
    if not isinstance(data, dict):
        return

    label = data.get('AXLabel', data.get('label', None))
    value = data.get('AXValue', data.get('value', None))
    title = data.get('AXTitle', data.get('title', None))
    role = data.get('role', data.get('AXRole', '')) or ''
    label = str(label) if label is not None else ''
    value = str(value) if value is not None else ''
    title = str(title) if title is not None else ''
    frame = data.get('frame', data.get('AXFrame', {})) or {}

    x = frame.get('x', 0) or 0
    y = frame.get('y', 0) or 0
    w = frame.get('width', 0) or 0
    h = frame.get('height', 0) or 0

    if w < 5 or h < 5:
        for child in data.get('children', data.get('AXChildren', [])):
            find_all(child, results)
        return

    pat = re.escape(keyword)
    for text in [label, title, value]:
        if text and re.search(pat, text, re.IGNORECASE):
            cx = int(x + w / 2)
            cy = int(y + h / 2)
            results.append(f'{role:20s} "{text}"  center=({cx},{cy})  [{int(w)}x{int(h)}]')
            break

    for child in data.get('children', data.get('AXChildren', [])):
        find_all(child, results)

try:
    with open('/tmp/ios_ui_tree.json') as f:
        tree = json.load(f)
    results = []
    find_all(tree, results)
    if results:
        for r in results:
            print(r)
    else:
        print(f"NOT_FOUND: '{keyword}'")
        sys.exit(1)
except Exception as e:
    print(f"NOT_FOUND: '{keyword}' (error: {e})")
    sys.exit(1)
PYEOF
}

# ============ Wait ============

device_wait() {
  local keyword="$1" timeout=${2:-30} elapsed=0
  while [ $elapsed -lt $timeout ]; do
    local result=$(device_find "$keyword" 2>/dev/null)
    if [[ "$result" != NOT_FOUND* ]] && [ -n "$result" ]; then
      echo "$result"; return 0
    fi
    sleep 2; elapsed=$((elapsed + 2))
  done
  echo "TIMEOUT: '$keyword' not found after ${timeout}s"; return 1
}

device_wait_gone() {
  local keyword="$1" timeout=${2:-60} elapsed=0
  while [ $elapsed -lt $timeout ]; do
    local result=$(device_find "$keyword" 2>/dev/null)
    if [[ "$result" == NOT_FOUND* ]] || [ -z "$result" ]; then return 0; fi
    sleep 2; elapsed=$((elapsed + 2))
  done
  echo "TIMEOUT: '$keyword' still visible after ${timeout}s"; return 1
}

# ============ Actions ============

device_tap() {
  local coords=$(device_find "$1")
  if [[ "$coords" == NOT_FOUND* ]]; then echo "NOT_FOUND: '$1'" >&2; return 1; fi
  local x=$(echo $coords | cut -d' ' -f1)
  local y=$(echo $coords | cut -d' ' -f2)
  _idb ui tap "$x" "$y" 2>/dev/null
  echo "Tapped '$1' at ($x, $y)"
}

device_tap_xy() {
  _idb ui tap "$1" "$2" 2>/dev/null
  echo "Tapped at ($1, $2)"
}

# Long press an element by text (default 2 seconds)
device_long_press() {
  local keyword="$1"
  local duration="${2:-2.0}"
  local coords=$(device_find "$keyword")
  if [[ "$coords" == NOT_FOUND* ]]; then echo "NOT_FOUND: '$keyword'" >&2; return 1; fi
  local x=$(echo $coords | cut -d' ' -f1)
  local y=$(echo $coords | cut -d' ' -f2)
  _idb ui tap "$x" "$y" --duration "$duration" 2>/dev/null
  echo "Long-pressed '$keyword' at ($x, $y) for ${duration}s"
}

# Long press at specific coordinates
device_long_press_xy() {
  local x="$1" y="$2" duration="${3:-2.0}"
  _idb ui tap "$x" "$y" --duration "$duration" 2>/dev/null
  echo "Long-pressed at ($x, $y) for ${duration}s"
}

device_input() {
  _idb ui text "$1" 2>/dev/null
}

device_type() {
  device_tap "$1" || return 1
  sleep 0.6
  device_input "$2"
}

device_swipe() {
  local w=${IDB_SCREEN_W:-390}
  local h=${IDB_SCREEN_H:-844}
  local mid_x=$((w / 2))
  local mid_y=$((h / 2))
  local margin=$((w / 10))

  case "$1" in
    left)  _idb ui swipe $((w - margin)) $mid_y $margin $mid_y 2>/dev/null ;;
    right) _idb ui swipe $margin $mid_y $((w - margin)) $mid_y 2>/dev/null ;;
    up)    _idb ui swipe $mid_x $((h * 3 / 4)) $mid_x $((h / 4)) 2>/dev/null ;;
    down)  _idb ui swipe $mid_x $((h / 4)) $mid_x $((h * 3 / 4)) 2>/dev/null ;;
    *)     echo "Usage: device_swipe left|right|up|down" ;;
  esac
}

# Swipe between specific coordinates
device_swipe_xy() {
  _idb ui swipe "$1" "$2" "$3" "$4" 2>/dev/null
}

device_back() {
  local h=${IDB_SCREEN_H:-844}
  local mid_y=$((h / 2))
  _idb ui swipe 5 $mid_y 200 $mid_y 2>/dev/null
  echo "Back gesture (swipe from left edge)"
}

device_home() {
  _idb ui button HOME 2>/dev/null
}

device_lock() {
  _idb ui button LOCK 2>/dev/null
}

device_siri() {
  _idb ui button SIRI 2>/dev/null
}

# ============ Clipboard ============

# Copy text to device pasteboard (simulator only)
device_clipboard_set() {
  if [ -z "$1" ]; then
    echo "Usage: device_clipboard_set \"text to copy\"" >&2
    return 1
  fi
  xcrun simctl pbcopy "$IDB_TARGET" <<< "$1" 2>/dev/null
  echo "Clipboard set: '${1:0:50}...'"
}

# Read device pasteboard (simulator only)
device_clipboard_get() {
  xcrun simctl pbpaste "$IDB_TARGET" 2>/dev/null
}

# ============ Compound ============

device_tap_wait() {
  device_tap "$1" || return 1
  device_wait "$2" ${3:-30}
}

device_step() {
  device_tap "$1" || { echo "FAILED: could not tap '$1'" >&2; device_shot; return 1; }
  device_wait "$2" ${3:-30} || { echo "FAILED: '$2' did not appear" >&2; device_shot; return 1; }
  device_shot
}

# ============ Logs ============

device_mark() {
  local label="${1:-MARK}" logfile="${2:-/tmp/ios_app.log}"
  echo "===${label}===" >> "$logfile"
}

device_logs() {
  local filter="${1:-.}" logfile="${2:-/tmp/ios_app.log}"
  if [ ! -f "$logfile" ]; then
    echo "No log file found. Start logging with: device_log_stream"
    return 1
  fi
  local mark=$(grep -n "^===" "$logfile" 2>/dev/null | tail -1 | cut -d: -f1)
  if [ -n "$mark" ]; then
    tail -n +$mark "$logfile" | grep -i "$filter"
  else
    tail -100 "$logfile" | grep -i "$filter"
  fi
}

device_log_stream() {
  local predicate="${1:-}"
  if [ -n "$predicate" ]; then
    _idb log -- --predicate "$predicate" 2>/dev/null | tee -a /tmp/ios_app.log &
  else
    _idb log 2>/dev/null | tee -a /tmp/ios_app.log &
  fi
  echo "Log streaming started (PID: $!). Logs saved to /tmp/ios_app.log"
}

# ============ App Management ============

device_app_list() {
  _idb list-apps 2>/dev/null
}

device_app_launch() {
  _idb launch "$1" 2>/dev/null
  echo "Launched $1"
}

device_app_terminate() {
  _idb terminate "$1" 2>/dev/null
  echo "Terminated $1"
}

device_app_install() {
  _idb install "$1" 2>/dev/null
}

device_app_uninstall() {
  _idb uninstall "$1" 2>/dev/null
}

# ============ Device Info ============

device_info() {
  _idb describe 2>/dev/null
}

# ============ URL / Deep Links ============

device_open_url() {
  _idb open "$1" 2>/dev/null
  echo "Opened: $1"
}

# ============ Load Guard ============

if [ -z "$_DEVICE_TOOLKIT_LOADED" ]; then
  _DEVICE_TOOLKIT_LOADED=1
  echo "iOS device toolkit ready"
fi
