#!/usr/bin/env bash
# =============================================================================
# PR Watcher — Instalador
# Uso: ./install.sh [install|uninstall|restart]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/pr_watcher.sh"

PLIST_NAME="com.nedzib.pr_watcher.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$PLIST_NAME"

CONFIG_FILE="$HOME/.review_inator.config"

# -----------------------------------------------------------------------------
# Crea la config de ejemplo si no existe
# -----------------------------------------------------------------------------
create_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "  Config ya existe: $CONFIG_FILE (no se sobreescribe)"
    return
  fi

  cat > "$CONFIG_FILE" <<EOF
{
  "repos": [
    "/ruta/a/tu/repo"
  ],
  "poll_interval": 60,
  "claude_prompt": "Acabas de recibir un PR para revisar. Por favor:\n\n1. Analiza los cambios con git diff origin/HEAD...HEAD\n2. Identifica posibles bugs, problemas de seguridad o edge cases\n3. Evalúa si el código sigue las convenciones del proyecto\n4. Genera un resumen estructurado con severidad: crítico / mayor / menor\n\nEmpieza leyendo los archivos modificados."
}
EOF

  echo "  Config creada: $CONFIG_FILE"
  echo "  Edítala antes de continuar — agrega tus repos y ajusta el prompt."
}

# -----------------------------------------------------------------------------
# Genera el plist con los paths reales del sistema
# -----------------------------------------------------------------------------
generate_plist() {
  cat > "$PLIST_DST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

  <key>Label</key>
  <string>com.nedzib.pr_watcher</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-l</string>
    <string>-c</string>
    <string>${SCRIPT_PATH}</string>
  </array>

  <key>KeepAlive</key>
  <true/>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>${HOME}/.review_inator.out.log</string>

  <key>StandardErrorPath</key>
  <string>${HOME}/.review_inator.err.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>HOME</key>
    <string>${HOME}</string>
  </dict>

</dict>
</plist>
EOF
}

# -----------------------------------------------------------------------------
# Comandos
# -----------------------------------------------------------------------------
case "${1:-install}" in
  install)
    echo "Instalando PR Watcher..."
    create_config
    generate_plist
    launchctl load "$PLIST_DST"
    echo ""
    echo "Instalado y arrancado."
    echo "  Estado : launchctl list | grep pr_watcher"
    echo "  Logs   : tail -f ~/.review_inator.out.log"
    echo "  Errores: tail -f ~/.review_inator.err.log"
    ;;

  uninstall)
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    rm -f "$PLIST_DST"
    echo "Desinstalado."
    echo "  Config y logs en ~ se mantienen."
    echo "  Para borrarlos: rm ~/.review_inator.*"
    ;;

  restart)
    echo "Reiniciando PR Watcher..."
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    generate_plist
    launchctl load "$PLIST_DST"
    echo "Reiniciado."
    ;;

  *)
    echo "Uso: $0 [install|uninstall|restart]"
    exit 1
    ;;
esac
