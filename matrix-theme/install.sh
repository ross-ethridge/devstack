#!/usr/bin/env bash
#
# install.sh - copy the matrix theme into your oh-my-bash custom themes dir.
#
# Usage: ./install.sh
#
set -euo pipefail

OSH="${OSH:-$HOME/.oh-my-bash}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/matrix.theme.sh"
DEST_DIR="$OSH/custom/themes/matrix"

if [[ ! -d "$OSH" ]]; then
  echo "oh-my-bash not found at: $OSH" >&2
  echo "Install it first: https://github.com/ohmybash/oh-my-bash" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
cp "$SRC" "$DEST_DIR/matrix.theme.sh"
echo "Installed: $DEST_DIR/matrix.theme.sh"

echo
echo "Next steps:"
echo "  1. Set the theme in ~/.bashrc:   OSH_THEME=\"matrix\""
echo "  2. Reload:                       source ~/.bashrc"
echo "  3. (optional) install eza for colored listings"
