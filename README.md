# review_inator

Daemon en bash que monitorea PRs de GitHub asignados a ti, crea un worktree por PR, abre una sesión tmux y lanza Claude con un prompt de revisión configurable.

## Requisitos

- [`gh`](https://cli.github.com/) — autenticado con `gh auth login`
- `git`
- `tmux`
- `jq`
- `claude` (Claude Code CLI)
- macOS (usa `osascript` para notificaciones)

## Instalación

```bash
git clone <repo> review_inator
cd review_inator
chmod +x pr_watcher.sh
```

## Configuración

Edita `config.sh`:

```bash
# Repos a observar
REPOS=(
  "/Users/tu_usuario/code/mi_repo"
  "/Users/tu_usuario/code/otro_repo"
)

# Segundos entre cada chequeo
POLL_INTERVAL=60

# Prompt inicial para Claude
CLAUDE_PROMPT=$(cat <<'EOF'
Analiza este PR...
EOF
)
```

## Uso

```bash
# Correr en foreground
./pr_watcher.sh

# Correr en background dentro de tmux
tmux new-session -d -s pr-watcher -c "$(pwd)"
tmux send-keys -t pr-watcher "./pr_watcher.sh" Enter

# Ver los logs
tail -f pr_watcher.log | jq .
```

## Qué hace cuando detecta un PR nuevo

1. Hace `fetch` de la rama del PR
2. Crea un worktree en `../reponame_pr_<number>` (mismo patrón que `wt`)
3. Abre una sesión tmux con nombre `reponame_pr_<number>`
4. Corre `claude` con el prompt configurado
5. Notificación nativa de macOS
6. Registra el PR en `pr_watcher.log` para no procesarlo dos veces

## Log

`pr_watcher.log` guarda un objeto JSON por línea (NDJSON):

```json
{"repo":"owner/repo","pr_number":42,"branch":"feature/foo","worktree":"/path/to/wt","session":"myrepo_pr_42","timestamp":"2026-04-14T10:00:00Z"}
```

Para consultar el historial:

```bash
# Todos los PRs procesados
jq -s '.' pr_watcher.log

# Filtrar por repo
jq -s '.[] | select(.repo == "owner/repo")' pr_watcher.log
```

## Estructura

```
review_inator/
├── config.sh          # Configuración (repos, intervalo, prompt)
├── pr_watcher.sh      # Script principal
└── pr_watcher.log     # Estado/historial (generado automáticamente)
```
