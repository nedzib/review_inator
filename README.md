# review_inator

<img width="500" height="500" alt="Adobe Express - file" src="https://github.com/user-attachments/assets/f398db66-c8a3-4efe-97a8-04767647acbe" />

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
./install.sh
```

`install.sh` crea `~/.review_inator.config` con valores de ejemplo si no existe, genera el plist con los paths reales de tu sistema y lo carga en launchd.

## Configuración

Edita `~/.review_inator.config` (JSON):

```json
{
  "repos": [
    "/Users/tu_usuario/code/mi_repo",
    "/Users/tu_usuario/code/otro_repo"
  ],
  "poll_interval": 60,
  "claude_prompt": "Analiza este PR...\n\n1. Revisa los cambios\n2. Identifica bugs\n3. Evalúa calidad"
}
```

| Campo | Descripción |
|---|---|
| `repos` | Paths absolutos a los repos que quieres observar |
| `poll_interval` | Segundos entre cada chequeo (default 60) |
| `claude_prompt` | Prompt inicial que Claude ejecuta al abrir cada PR. Usa `\n` para saltos de línea |

El daemon corre con `zsh -l` (login shell), por lo que hereda exactamente el mismo `PATH` de tu terminal — no hay nada extra que configurar.

Tras editar la config, reinicia el daemon:

```bash
./install.sh restart
```

## Uso

```bash
./install.sh           # instalar y arrancar
./install.sh uninstall # desinstalar
./install.sh restart   # reiniciar (tras cambios en config)
```

```bash
# Ver estado
launchctl list | grep pr_watcher

# Ver output en vivo
tail -f ~/.review_inator.out.log

# Ver errores
tail -f ~/.review_inator.err.log
```

## Qué hace cuando detecta un PR nuevo

1. Hace `fetch` de la rama del PR
2. Crea un worktree en `../reponame_pr_<number>` (mismo patrón que `wt`)
3. Abre una sesión tmux con nombre `reponame_pr_<number>`
4. Corre `claude` con el prompt configurado
5. Notificación nativa de macOS
6. Registra el PR en `~/.review_inator.log` para no procesarlo dos veces

## Log

`~/.review_inator.log` guarda un objeto JSON por línea (NDJSON):

```json
{"repo":"owner/repo","pr_number":42,"branch":"feature/foo","worktree":"/path/to/wt","session":"myrepo_pr_42","timestamp":"2026-04-14T10:00:00Z"}
```

```bash
# Todos los PRs procesados
jq -s '.' ~/.review_inator.log

# Filtrar por repo
jq -s '.[] | select(.repo == "owner/repo")' ~/.review_inator.log
```

## Archivos

```
# Repo (solo el código)
review_inator/
├── pr_watcher.sh   # Script principal
├── install.sh      # Instalador (genera plist + config de ejemplo)
└── README.md

# Home (datos del usuario, fuera del repo)
~/.review_inator.config    # Configuración (editar esto)
~/.review_inator.log       # Historial de PRs procesados
~/.review_inator.out.log   # Stdout del daemon
~/.review_inator.err.log   # Stderr del daemon
```
