#!/bin/bash
# install.sh — installs meteo to /usr/local/bin/meteo

set -e

INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run the installer as root (e.g., sudo ./install.sh)"
  exit 1
fi

echo "📦 Installing meteo..."

# Check dependencies
for dep in curl jq python3 bc; do
  if ! command -v "$dep" &>/dev/null; then
    echo "❌ Missing dependency: $dep"
    echo "   Install it with: sudo apt install $dep"
    exit 1
  fi
done

# Install script
cp "$SCRIPT_DIR/meteo.sh" "$INSTALL_DIR/meteo"
chmod +x "$INSTALL_DIR/meteo"

echo ""
echo "✅ meteo installed! Usage:"
echo "   meteo auth [token] # set your API key first"
echo "   meteo [city]       # e.g. meteo Tokyo"
