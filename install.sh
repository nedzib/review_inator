#!/usr/bin/env bash
# Instala o desinstala el launchd agent
set -euo pipefail

PLIST_NAME="com.nedzib.pr_watcher.plist"
PLIST_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$PLIST_NAME"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME"

case "${1:-install}" in
  install)
    cp "$PLIST_SRC" "$PLIST_DST"
    launchctl load "$PLIST_DST"
    echo "Instalado y arrancado: $PLIST_NAME"
    echo "Para ver el estado: launchctl list | grep pr_watcher"
    ;;
  uninstall)
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    rm -f "$PLIST_DST"
    echo "Desinstalado: $PLIST_NAME"
    ;;
  restart)
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    cp "$PLIST_SRC" "$PLIST_DST"
    launchctl load "$PLIST_DST"
    echo "Reiniciado: $PLIST_NAME"
    ;;
  *)
    echo "Uso: $0 [install|uninstall|restart]"
    exit 1
    ;;
esac
