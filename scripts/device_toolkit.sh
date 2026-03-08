#!/bin/bash
# iOS idb Device Toolkit
# Works with simulators and real iOS devices via Meta's idb
# Requires: idb (fb-idb) + idb_companion installed
# Usage: source device_toolkit.sh

# ============ Session State ============
if [ -z "$_DEVICE_TOOLKIT_LOADED" ]; then
  IDB_TARGET=""
  IDB_SHOT_SIZE="750"
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

  local targets
  targets=$(idb list-targets --json 2>/dev/null)
  if [ -z "$targets" ] || [ "$targets" = "[]" ]; then
    echo "No iOS targets found."
    echo ""
    echo "To start a simulator:"
    echo "  xcrun simctl boot 'iPhone 16'"
    echo ""
    echo "For a real device: connect via USB with Developer Mode enabled."
    return 1
  fi

  echo "iOS Targets:"
  local i=1
  echo "$targets" | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        t = json.loads(line)
    except: continue
    udid = t.get('udid', 'unknown')
    name = t.get('name', 'unknown')
    state = t.get('state', 'unknown')
    ttype = t.get('type', 'unknown')
    os_ver = t.get('os_version', 'unknown')
    arch = t.get('architecture', '')
    print(f'  [{sys.stdout.write(\"\") or i}] {udid}')
    print(f'      {name} ({ttype}) -- iOS {os_ver}, {state}')
    i = i + 1 if 'i' in dir() else 2
" 2>/dev/null || {
    # Fallback: non-JSON mode
    echo "$targets" | while IFS= read -r line; do
      echo "  [$i] $line"
      i=$((i + 1))
    done
  }

  # Simpler listing approach
  echo ""
  echo "--- Target List ---"
  idb list-targets 2>/dev/null
  echo ""
  echo "Resolution: [A] 1000px  [B] 750px (recommended)  [C] 500px  [D] 350px"
  echo ""
  echo "Pick target UDID + resolution, e.g. copy UDID then type resolution letter."
}

device_select() {
  local udid="$1"
  local res="$2"

  # Verify target exists
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

  local name
  name=$(idb describe --udid "$IDB_TARGET" 2>/dev/null | head -5)
  echo "Target set: $IDB_TARGET @ ${IDB_SHOT_SIZE}px"
  echo "$name"
}

# ============ idb Wrapper ============

_idb() {
  if [ -n "$IDB_TARGET" ]; then
    idb --udid "$IDB_TARGET" "$@"
  else
    idb "$@"
  fi
}

# ============ Screenshot ============

device_shot() {
  local size=${1:-$IDB_SHOT_SIZE}
  _idb screenshot /tmp/device_raw.png 2>/dev/null
  sips -Z "$size" /tmp/device_raw.png --out /tmp/device_screen.png -s format png 2>/dev/null
  echo "/tmp/device_screen.png"
}

# ============ UI Tree (Accessibility) ============

device_dump() {
  _idb ui describe-all 2>/dev/null > /tmp/ios_ui_tree.json
}

device_list() {
  device_dump
  python3 -c "
import json, sys

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
    enabled = data.get('enabled', data.get('AXEnabled', True))
    label = str(label) if label is not None else ''
    value = str(value) if value is not None else ''
    x = frame.get('x', 0) or 0
    y = frame.get('y', 0) or 0
    w = frame.get('width', 0) or 0
    h = frame.get('height', 0) or 0

    display = label or value or ''
    if display and (w > 0 and h > 0):
        cx = int(x + w / 2)
        cy = int(y + h / 2)
        results.append(f'{role:20s} \"{display}\"  [{int(x)},{int(y)}][{int(x+w)},{int(y+h)}]  center=({cx},{cy})')
    for child in data.get('children', data.get('AXChildren', [])):
        parse_elements(child, results, depth + 1)

try:
    with open('/tmp/ios_ui_tree.json') as f:
        tree = json.load(f)
    results = []
    parse_elements(tree, results)
    for r in results[:50]:
        print(r)
    if len(results) > 50:
        print(f'... and {len(results) - 50} more elements')
except Exception as e:
    print(f'Parse error: {e}')
    print('Raw output:')
    with open('/tmp/ios_ui_tree.json') as f:
        print(f.read()[:3000])
" 2>/dev/null
}

device_find() {
  local keyword="$1"
  device_dump
  python3 -c "
import json, sys, re

def find_element(data, keyword):
    if isinstance(data, list):
        for item in data:
            result = find_element(item, keyword)
            if result: return result
        return None
    if not isinstance(data, dict):
        return None

    label = data.get('AXLabel', data.get('label', None))
    value = data.get('AXValue', data.get('value', None))
    title = data.get('AXTitle', data.get('title', None))
    label = str(label) if label is not None else ''
    value = str(value) if value is not None else ''
    title = str(title) if title is not None else ''
    frame = data.get('frame', data.get('AXFrame', {})) or {}

    for text in [label, value, title]:
        if text and re.search(re.escape(keyword), text, re.IGNORECASE):
            x = frame.get('x', 0) or 0
            y = frame.get('y', 0) or 0
            w = frame.get('width', 0) or 0
            h = frame.get('height', 0) or 0
            if w > 0 and h > 0:
                cx = int(x + w / 2)
                cy = int(y + h / 2)
                return f'{cx} {cy}'

    for child in data.get('children', data.get('AXChildren', [])):
        result = find_element(child, keyword)
        if result: return result
    return None

try:
    with open('/tmp/ios_ui_tree.json') as f:
        tree = json.load(f)
    result = find_element(tree, '$keyword')
    if result:
        print(result)
    else:
        print('NOT_FOUND: \'$keyword\'')
        sys.exit(1)
except Exception as e:
    print(f'NOT_FOUND: \'$keyword\' (error: {e})')
    sys.exit(1)
" 2>/dev/null
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
}

device_input() {
  _idb ui text "$1" 2>/dev/null
}

device_type() {
  device_tap "$1" || return 1
  sleep 0.5
  device_input "$2"
}

device_swipe() {
  # Default coordinates for a typical iPhone screen (390x844 logical points)
  case "$1" in
    left)  _idb ui swipe 350 422 50 422 2>/dev/null ;;
    right) _idb ui swipe 50 422 350 422 2>/dev/null ;;
    up)    _idb ui swipe 195 650 195 200 2>/dev/null ;;
    down)  _idb ui swipe 195 200 195 650 2>/dev/null ;;
    *)     echo "Usage: device_swipe left|right|up|down" ;;
  esac
}

device_back() {
  # iOS back gesture: swipe from left edge to right
  _idb ui swipe 5 422 200 422 2>/dev/null
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

# ============ Compound ============

device_tap_wait() {
  device_tap "$1" || return 1
  device_wait "$2" ${3:-30}
}

device_step() {
  device_tap "$1" || return 1
  device_wait "$2" ${3:-30} || { device_shot; return 1; }
  device_shot
}

# ============ Logs ============

device_mark() {
  local label="${1:-MARK}" logfile="${2:-/tmp/ios_app.log}"
  echo "===${label}===" >> "$logfile"
}

device_logs() {
  local filter="${1:-.}" logfile="${2:-/tmp/ios_app.log}"
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

# ============ Load Guard ============

if [ -z "$_DEVICE_TOOLKIT_LOADED" ]; then
  _DEVICE_TOOLKIT_LOADED=1
  echo "iOS device toolkit ready"
fi
