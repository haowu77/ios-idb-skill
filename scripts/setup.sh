#!/bin/bash
# ios-idb-skill dependency installer
# Installs idb_companion and fb-idb client
# Usage: bash scripts/setup.sh

set -e

echo "=== ios-idb-skill Setup ==="
echo ""

# ---- Check OS ----
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: idb requires macOS. Detected: $(uname)"
  exit 1
fi

# ---- Check Homebrew ----
if ! command -v brew &>/dev/null; then
  echo "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  echo "[ok] Homebrew"
fi

# ---- Check Python 3 ----
if ! command -v python3 &>/dev/null; then
  echo "Python 3 not found. Installing..."
  brew install python3
else
  echo "[ok] Python 3 ($(python3 --version 2>&1))"
fi

# ---- Check pip3 ----
if ! command -v pip3 &>/dev/null; then
  echo "pip3 not found. Installing..."
  python3 -m ensurepip --upgrade 2>/dev/null || brew install python3
else
  echo "[ok] pip3"
fi

# ---- Check idb_companion ----
if ! command -v idb_companion &>/dev/null; then
  echo ""
  echo "Installing idb_companion..."
  brew tap facebook/fb 2>/dev/null || true
  brew install idb-companion
else
  echo "[ok] idb_companion"
fi

# ---- Check idb client ----
if ! command -v idb &>/dev/null; then
  echo ""
  echo "Installing fb-idb (Python client)..."
  pip3 install fb-idb
else
  echo "[ok] idb client"
fi

# ---- Verify ----
echo ""
echo "=== Verification ==="

if command -v idb &>/dev/null && command -v idb_companion &>/dev/null; then
  echo "[ok] All dependencies installed"
  echo ""
  echo "Testing target discovery..."
  idb list-targets 2>/dev/null || echo "(no targets found -- boot a simulator or connect a device)"
  echo ""
  echo "Setup complete! You can now use the ios-idb-skill."
else
  echo "ERROR: Something went wrong. Please check the output above."
  exit 1
fi
