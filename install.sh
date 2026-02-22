#!/bin/bash
# install.sh — installs meteo to /usr/local/bin/meteo

set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/meteo"

echo "📦 Installing meteo..."

# Check dependencies
for dep in curl jq python3 bc; do
  if ! command -v "$dep" &>/dev/null; then
    echo "❌ Missing dependency: $dep"
    echo "   Install it with: sudo apt install $dep"
    exit 1
  fi
done

# Setup config
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.sh" ]; then
  read -rp "🔑 Enter your OpenWeatherMap API key: " key
  echo "export API_KEY=\"$key\"" > "$CONFIG_DIR/config.sh"
  echo "✅ API key saved to $CONFIG_DIR/config.sh"
else
  echo "ℹ️  Config already exists at $CONFIG_DIR/config.sh"
fi

# Install script (rewrite config source path to use ~/.config/meteo/config.sh)
sed "s|source \".*config.sh\"|source \"$CONFIG_DIR/config.sh\"|" meteo.sh \
  > "$INSTALL_DIR/meteo"
chmod +x "$INSTALL_DIR/meteo"

echo ""
echo "✅ meteo installed! Usage:"
echo "   meteo [city]       # e.g. meteo Tokyo"
