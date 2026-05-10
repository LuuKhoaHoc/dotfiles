#!/bin/bash
BACKUP_DIR="$HOME/.config/hypr-backup-caelestia-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup các config quan trọng
cp -r ~/.config/hypr "$BACKUP_DIR/"
cp -r ~/.config/waybar "$BACKUP_DIR/"
cp -r ~/.config/ags "$BACKUP_DIR/" 2>/dev/null

echo "Backup saved to: $BACKUP_DIR"
