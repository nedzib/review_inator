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
git clone https://github.com/nedzib/review_inator
cd review_inator
chmod +x pr_watcher.sh install.sh
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

### Opción A — launchd (recomendado)

Corre en background desde el login, sin terminal abierta. Se reinicia automáticamente si el proceso muere.

```bash
# Instalar y arrancar
./install.sh

# Desinstalar
./install.sh uninstall

# Reiniciar (tras cambios en config.sh)
./install.sh restart

# Verificar que está corriendo
launchctl list | grep pr_watcher

# Ver output en vivo
tail -f launchd.out.log

# Ver errores
tail -f launchd.err.log
```

> Si `gh`, `claude` o `tmux` no están en `/opt/homebrew/bin` ni en `/usr/local/bin`,
> ajusta el `PATH` dentro de `com.nedzib.pr_watcher.plist` antes de instalar.

### Opción B — manual

```bash
# Foreground
./pr_watcher.sh

# Background en tmux
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
├── config.sh                      # Configuración (repos, intervalo, prompt)
├── pr_watcher.sh                  # Script principal
├── install.sh                     # Instala/desinstala el launchd agent
├── com.nedzib.pr_watcher.plist    # launchd plist (daemon macOS)
├── pr_watcher.log                 # Estado/historial (generado automáticamente)
├── launchd.out.log                # Stdout del daemon (generado automáticamente)
└── launchd.err.log                # Stderr del daemon (generado automáticamente)
```
