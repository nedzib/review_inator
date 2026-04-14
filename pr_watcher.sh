#!/usr/bin/env bash
# =============================================================================
# PR Watcher — Monitorea PRs asignados y abre Claude en un worktree + tmux
# Config : ~/.review_inator.config
# Log    : ~/.review_inator.log
# Uso    : ./pr_watcher.sh
# =============================================================================

set -euo pipefail

CONFIG_FILE="$HOME/.review_inator.config"
LOG_FILE="$HOME/.review_inator.log"

# -----------------------------------------------------------------------------
# Validaciones iniciales
# -----------------------------------------------------------------------------
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] Config no encontrada: $CONFIG_FILE"
  echo "  Ejecuta ./install.sh para crear una de ejemplo"
  exit 1
fi

for cmd in gh git jq tmux osascript; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[ERROR] Dependencia faltante: $cmd"
    exit 1
  fi
done

# Leer config
POLL_INTERVAL=$(jq -r '.poll_interval // 60' "$CONFIG_FILE")
CLAUDE_PROMPT=$(jq -r '.claude_prompt' "$CONFIG_FILE")

# Login del usuario autenticado en gh (para filtrar asignaciones directas)
GH_LOGIN=$(gh api user --jq .login 2>/dev/null) || {
  echo "[ERROR] No se pudo obtener el usuario de gh (¿está autenticado?)"
  exit 1
}

REPOS=()
while IFS= read -r repo; do
  REPOS+=("$repo")
done < <(jq -r '.repos[]' "$CONFIG_FILE")

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "[ERROR] No hay repos configurados en $CONFIG_FILE"
  exit 1
fi

# -----------------------------------------------------------------------------
# Log (NDJSON — un objeto JSON por línea)
# -----------------------------------------------------------------------------

# Devuelve 0 si el PR ya fue procesado, 1 si es nuevo
is_processed() {
  local repo="$1"
  local pr_number="$2"

  [[ -f "$LOG_FILE" ]] || return 1

  jq -se --arg r "$repo" --argjson n "$pr_number" \
    'any(.[]; .repo == $r and .pr_number == $n)' \
    "$LOG_FILE" 2>/dev/null | grep -q "^true$"
}

log_pr() {
  local repo="$1"
  local pr_number="$2"
  local branch="$3"
  local worktree="$4"
  local session="$5"

  printf '{"repo":"%s","pr_number":%d,"branch":"%s","worktree":"%s","session":"%s","timestamp":"%s"}\n' \
    "$repo" \
    "$pr_number" \
    "$branch" \
    "$worktree" \
    "$session" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG_FILE"
}

# -----------------------------------------------------------------------------
# Worktree + tmux + Claude
# Sigue la misma lógica que la función wt del zshrc:
#   - worktree en ../  relativo al repo
#   - session name = basename del worktree normalizado
# -----------------------------------------------------------------------------
handle_pr() {
  local repo_path="$1"
  local repo="$2"        # owner/repo
  local pr_number="$3"
  local branch="$4"
  local title="$5"
  local author="$6"

  local repo_name
  repo_name="$(basename "$repo_path")"

  # Nombre del directorio del worktree: ../reponame_pr_42
  local dir="${repo_name}_pr_${pr_number}"
  local worktree_path
  worktree_path="$(dirname "$repo_path")/$dir"

  # Nombre de sesión tmux: <autor>_review_<numero>
  local session_name
  session_name="${author}_review_${pr_number}"
  session_name="${session_name//[^[:alnum:]_-]/_}"

  echo "[$(date '+%H:%M:%S')] Nuevo PR #${pr_number} en ${repo}: ${title}"
  echo "  branch   : $branch"
  echo "  worktree : $worktree_path"
  echo "  session  : $session_name"

  # Fetch de la rama remota
  git -C "$repo_path" fetch origin "$branch" --quiet

  # Crear worktree si no existe (rama ya existe en origin → usarla directamente)
  if [[ -d "$worktree_path" ]]; then
    echo "  [SKIP] Worktree ya existe, reutilizando"
  else
    git -C "$repo_path" worktree add \
      -b "review/pr-${pr_number}" \
      "$worktree_path" \
      "origin/${branch}"
  fi

  # Escribir el prompt en el worktree para que claude lo lea
  echo "$CLAUDE_PROMPT" > "$worktree_path/.pr_review_prompt"

  # Crear sesión tmux si no existe
  if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -c "$worktree_path"
  fi

  # Abrir Claude interactivo con el prompt como primer mensaje
  tmux send-keys -t "$session_name" 'claude "$(cat .pr_review_prompt)"' Enter

  # Registrar en el log
  log_pr "$repo" "$pr_number" "$branch" "$worktree_path" "$session_name"

  # Notificación nativa macOS
  osascript -e \
    "display notification \"PR #${pr_number}: ${title}\" with title \"PR Review listo\" subtitle \"${repo}\" sound name \"Glass\""
}

# -----------------------------------------------------------------------------
# Procesar un repo
# -----------------------------------------------------------------------------
process_repo() {
  local repo_path="$1"

  if [[ ! -d "$repo_path" ]]; then
    echo "[WARN] Directorio no encontrado: $repo_path"
    return
  fi

  # Obtener owner/repo desde gh (más fiable que parsear el remote)
  local repo
  repo=$(cd "$repo_path" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || {
    echo "[WARN] No se pudo leer el repo en $repo_path (¿está autenticado gh?)"
    return
  }

  # PRs donde me pidieron review directamente
  local prs
  prs=$(gh pr list \
    --repo "$repo" \
    --search "review-requested:@me is:open" \
    --json number,title,headRefName,author \
    2>/dev/null) || return

  local count
  count=$(echo "$prs" | jq 'length')

  [[ "$count" -eq 0 ]] && return

  while IFS= read -r pr; do
    local pr_number title branch author
    pr_number=$(echo "$pr" | jq -r '.number')
    title=$(echo "$pr" | jq -r '.title')
    branch=$(echo "$pr" | jq -r '.headRefName')
    author=$(echo "$pr" | jq -r '.author.login')

    # Verificar que el usuario está en requested_reviewers (asignación directa, no por team)
    local direct_reviewers
    direct_reviewers=$(gh api "repos/${repo}/pulls/${pr_number}" \
      --jq '[.requested_reviewers[].login]' 2>/dev/null) || direct_reviewers="[]"

    if ! echo "$direct_reviewers" | jq -e --arg u "$GH_LOGIN" 'index($u) != null' &>/dev/null; then
      continue
    fi

    if ! is_processed "$repo" "$pr_number"; then
      handle_pr "$repo_path" "$repo" "$pr_number" "$branch" "$title" "$author"
    fi
  done < <(echo "$prs" | jq -c '.[]')
}

# -----------------------------------------------------------------------------
# Seed: marca los PRs abiertos actuales como ya procesados sin lanzar nada
# -----------------------------------------------------------------------------
seed_existing_prs() {
  echo "Marcando PRs existentes en el log (no se procesarán)..."
  local seeded=0

  for repo_path in "${REPOS[@]}"; do
    if [[ ! -d "$repo_path" ]]; then
      echo "  [SKIP] Directorio no encontrado: $repo_path"
      continue
    fi

    local repo
    repo=$(cd "$repo_path" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || {
      echo "  [SKIP] No se pudo leer el repo en $repo_path"
      continue
    }

    local prs
    prs=$(gh pr list \
      --repo "$repo" \
      --search "review-requested:@me is:open" \
      --json number,title,headRefName \
      2>/dev/null) || continue

    while IFS= read -r pr; do
      local pr_number branch
      pr_number=$(echo "$pr" | jq -r '.number')
      branch=$(echo "$pr" | jq -r '.headRefName')

      local direct_reviewers
      direct_reviewers=$(gh api "repos/${repo}/pulls/${pr_number}" \
        --jq '[.requested_reviewers[].login]' 2>/dev/null) || direct_reviewers="[]"

      if ! echo "$direct_reviewers" | jq -e --arg u "$GH_LOGIN" 'index($u) != null' &>/dev/null; then
        continue
      fi

      if ! is_processed "$repo" "$pr_number"; then
        log_pr "$repo" "$pr_number" "$branch" "seeded" "seeded"
        echo "  Marcado: $repo #${pr_number} ($branch)"
        (( seeded++ )) || true
      fi
    done < <(echo "$prs" | jq -c '.[]')
  done

  echo "Seed completo — $seeded PRs marcados. Solo los nuevos serán procesados."
}

# -----------------------------------------------------------------------------
# Loop principal
# -----------------------------------------------------------------------------
if [[ "${1:-}" == "--seed" ]]; then
  seed_existing_prs
  exit 0
fi

echo "=================================================="
echo " PR Watcher iniciado"
echo " Config  : $CONFIG_FILE"
echo " Repos   : ${#REPOS[@]}"
echo " Polling : cada ${POLL_INTERVAL}s"
echo " Log     : $LOG_FILE"
echo "=================================================="

while true; do
  for repo_path in "${REPOS[@]}"; do
    process_repo "$repo_path"
  done
  sleep "$POLL_INTERVAL"
done
