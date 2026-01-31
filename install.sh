#!/bin/bash

SCRIPT_NAME="bandit.sh"
INSTALL_DIR="$HOME/.local/bin"
TARGET="$INSTALL_DIR/bandit"

echo "[+] Installing $SCRIPT_NAME..."

chmod +x "$SCRIPT_NAME"

mkdir -p "$INSTALL_DIR"

ln -sf "$(pwd)/$SCRIPT_NAME" "$TARGET"

echo "[+] Successfully installed to $TARGET"