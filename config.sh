# =============================================================================
# PR Watcher — Configuración
# =============================================================================

# Repos a observar (paths absolutos)
REPOS=(
  # "/Users/tu_usuario/code/mi_repo"
  # "/Users/tu_usuario/code/otro_repo"
)

# Segundos entre cada chequeo
POLL_INTERVAL=60

# Prompt inicial que Claude ejecutará al abrir cada PR
CLAUDE_PROMPT=$(cat <<'EOF'
Acabas de recibir un PR para revisar. Por favor:

1. Analiza los cambios del diff con `git diff origin/HEAD...HEAD`
2. Identifica posibles bugs, problemas de seguridad o edge cases
3. Evalúa la calidad del código y si sigue las convenciones del proyecto
4. Genera un resumen estructurado con severidad: crítico / mayor / menor

Empieza leyendo los archivos modificados.
EOF
)
