# ─── AI CLI ──────────────────────────────────────────────────────────────────
# Unified AI provider launcher with interactive fzf picker
# Usage: ai [command] [args...]
#        ai              interactive picker
#        ai last         re-run last provider
#        ai help         show help

# ─── Colors ──────────────────────────────────────────────────────────────────

typeset -gA _AI=(
  [r]='\033[0m'
  [b]='\033[1m'
  [d]='\033[2m'
  [cyan]='\033[36m'
  [green]='\033[32m'
  [yellow]='\033[33m'
  [red]='\033[31m'
  [mag]='\033[35m'
  [blue]='\033[34m'
  [bcyan]='\033[1;36m'
  [bgreen]='\033[1;32m'
  [byel]='\033[1;33m'
  [bred]='\033[1;31m'
  [bmag]='\033[1;35m'
)

# Ship prompt for git assistance
_AI_SHIP_PROMPT='You are a git assistant. Help me commit changes, push to the current branch, and create a PR if the PR needs to be created.

Use these tools available to you:
- git commands via shell
- gh CLI for PR creation

Workflow:
1. Check git status and suggest what to stage
2. Craft a good commit message based on the diff
3. Commit and push to current branch
4. Create a PR with gh pr create

Be concise but thorough. Ask me questions if anything is unclear.'

# ─── Provider registry ──────────────────────────────────────────────────────
# Anthropic-compatible providers: env_var|base_url|model|haiku|sonnet|opus|color|label|model_flag
#   model_flag: 1 = supports --model override + passes --model to claude, 0 = fixed model

typeset -gA _AI_PROVIDERS=(
  [glm]="GLM_API_KEY|https://api.z.ai/api/anthropic|glm-4.7|glm-4.5-Air|glm-4.7|glm-4.7|byel|GLM|0"
  [kimi]="KIMI_API_KEY|https://api.kimi.com/coding/|kimi-k2.5|kimi-k2.5|kimi-k2.5|kimi-k2.5|mag|Kimi|0"
  [mini]="MINIMAX_API_KEY|https://api.minimax.io/anthropic|MiniMax-M2.1|MiniMax-M2.1|MiniMax-M2.1|MiniMax-M2.1|bmag|MiniMax|0"
  [or]="OPENROUTER_API_KEY|https://openrouter.ai/api|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|bgreen|OpenRouter|1"
  [ol]="_OLLAMA|http://localhost:11434|glm-5:cloud|glm-5:cloud|glm-5:cloud|glm-5:cloud|blue|Ollama|1"
)

# ─── Internal helpers ────────────────────────────────────────────────────────

_ai_has_env() {
  [[ -n "${(P)1}" ]]
}

_ai_has_cmd() {
  command -v "$1" &>/dev/null
}

_ai_has_ollama() {
  _ai_has_cmd ollama && curl -sf --connect-timeout 1 http://localhost:11434/api/tags >/dev/null 2>&1
}

_ai_require_cmd() {
  _ai_has_cmd "$1" || {
    printf "${_AI[red]}✗ %s not found${_AI[r]}\n" "$1"
    return 1
  }
}

_ai_check() {
  if _ai_has_env "$1"; then
    printf "${_AI[green]}●${_AI[r]}"
  else
    printf "${_AI[red]}○${_AI[r]}"
  fi
}

_ai_check_cmd() {
  if _ai_has_cmd "$1"; then
    printf "${_AI[green]}●${_AI[r]}"
  else
    printf "${_AI[red]}○${_AI[r]}"
  fi
}

_ai_check_ollama() {
  if _ai_has_ollama; then
    printf "${_AI[green]}●${_AI[r]}"
  else
    printf "${_AI[red]}○${_AI[r]}"
  fi
}

_ai_save_last() {
  printf '%s' "$1" > "${TMPDIR:-/tmp}/.ai_last_provider"
}

_ai_cmd_available() {
  local cmd="$1"
  local last_file="${TMPDIR:-/tmp}/.ai_last_provider"
  case "$cmd" in
    sonnet|haiku|opus|custom) _ai_has_cmd claude ;;
    glm)                      _ai_has_cmd claude && _ai_has_env GLM_API_KEY ;;
    kimi|k)                   _ai_has_cmd claude && _ai_has_env KIMI_API_KEY ;;
    mini|m)                   _ai_has_cmd claude && _ai_has_env MINIMAX_API_KEY ;;
    or|openrouter)            _ai_has_cmd claude && _ai_has_env OPENROUTER_API_KEY ;;
    ol|ollama)                _ai_has_cmd claude && _ai_has_ollama ;;
    codex|c)                  _ai_has_cmd codex && _ai_has_env OPENAI_API_KEY ;;
    gemini|ge)                _ai_has_cmd gemini && _ai_has_env GEMINI_API_KEY ;;
    copilot|cp)               _ai_has_cmd copilot ;;
    oc|opencode)              _ai_has_cmd opencode ;;
    last|l)                   [[ -f "$last_file" ]] ;;
    help|--help|-h)           return 0 ;;
    *)                        return 1 ;;
  esac
}

_ai_help_cmd_row() {
  local cmd="$1" alias="$2" desc="$3"
  printf "    ${_AI[cyan]}%-10s${_AI[r]} ${_AI[d]}%-3s${_AI[r]}  %s\n" "$cmd" "$alias" "$desc"
}

_ai_help_status_row() {
  local lcheck="$1" llabel="$2" rcheck="$3" rlabel="$4"
  printf "    %s %-24s %s %s\n" "$lcheck" "$llabel" "$rcheck" "$rlabel"
}

# ─── Generic provider runner ────────────────────────────────────────────────

_ai_run_provider() {
  local key="$1"; shift
  local cfg="${_AI_PROVIDERS[$key]}"
  [[ -z "$cfg" ]] && { printf "${_AI[red]}✗ Unknown provider: %s${_AI[r]}\n" "$key"; return 1; }

  _ai_require_cmd claude || return 1

  local parts=("${(@s:|:)cfg}")
  local env_var="$parts[1]"   base_url="$parts[2]"  default_model="$parts[3]"
  local haiku="$parts[4]"     sonnet="$parts[5]"    opus="$parts[6]"
  local color="$parts[7]"     label="$parts[8]"     model_flag="$parts[9]"

  # Resolve auth token
  local token
  if [[ "$env_var" == "_OLLAMA" ]]; then
    _ai_has_ollama || {
      printf "${_AI[red]}✗ Ollama unavailable (install ollama and run server at localhost:11434)${_AI[r]}\n"
      return 1
    }
    token="ollama"
  else
    token="${(P)env_var}"
    [[ -z "$token" ]] && { printf "${_AI[red]}✗ %s not set${_AI[r]}\n" "$env_var"; return 1; }
  fi

  # Extract --model override if supported
  local model="$default_model"
  if [[ "$model_flag" == "1" ]]; then
    local args=()
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--model" && -n "$2" ]]; then
        model="$2"; shift 2
      else
        args+=("$1"); shift
      fi
    done
    set -- "${args[@]}"
  fi

  printf "${_AI[$color]}▶${_AI[r]} %s ${_AI[b]}%s${_AI[r]}\n" "$label" "$model"
  _ai_save_last "$key"

  local cmd_args=(--dangerously-skip-permissions)
  [[ "$model_flag" == "1" ]] && cmd_args+=(--model "$model")

  ANTHROPIC_AUTH_TOKEN="$token" \
  ANTHROPIC_BASE_URL="$base_url" \
  ANTHROPIC_API_KEY="" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$opus" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "${cmd_args[@]}" "$@"
}

# ─── Dedicated runners (non-registry providers) ─────────────────────────────

_ai_run_claude() {
  local model="${1:?model required}"; shift
  _ai_require_cmd claude || return 1
  printf "${_AI[bcyan]}▶${_AI[r]} Claude ${_AI[b]}%s${_AI[r]}\n" "$model"
  _ai_save_last "$model"
  claude --dangerously-skip-permissions --model "$model" "$@"
}

_ai_run_codex() {
  _ai_require_cmd codex || return 1
  [[ -z "$OPENAI_API_KEY" ]] && { printf "${_AI[red]}✗ OPENAI_API_KEY not set${_AI[r]}\n"; return 1; }
  printf "${_AI[bred]}▶${_AI[r]} Codex\n"
  _ai_save_last "codex"
  codex --dangerously-bypass-approvals-and-sandbox "$@"
}

_ai_run_gemini() {
  _ai_require_cmd gemini || return 1
  [[ -z "$GEMINI_API_KEY" ]] && { printf "${_AI[red]}✗ GEMINI_API_KEY not set${_AI[r]}\n"; return 1; }
  printf "${_AI[byel]}▶${_AI[r]} Gemini ${_AI[b]}yolo${_AI[r]}\n"
  _ai_save_last "gemini"
  gemini --yolo "$@"
}

_ai_run_copilot() {
  _ai_require_cmd copilot || return 1
  printf "${_AI[bgreen]}▶${_AI[r]} Copilot\n"
  _ai_save_last "cp"
  copilot --allow-all "$@"
}

_ai_run_opencode() {
  _ai_require_cmd opencode || return 1

  local do_review=0 model="" args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --review)       do_review=1; shift ;;
      --model)        model="$2"; shift 2 ;;
      *)              args+=("$1"); shift ;;
    esac
  done

  local prompt_args=()
  if [[ "$do_review" -eq 1 ]]; then
    local diff
    diff=$(git diff HEAD 2>/dev/null)
    [[ -z "$diff" ]] && diff=$(git diff origin/main...HEAD 2>/dev/null)
    [[ -z "$diff" ]] && diff=$(git diff main...HEAD 2>/dev/null)
    if [[ -z "$diff" ]]; then
      printf "${_AI[yellow]}⚠  No changes found to review${_AI[r]}\n"
    else
      local review_prompt="Please do a thorough code review of the following changes. Focus on: correctness, security, performance, maintainability, and adherence to best practices. Provide specific, actionable feedback with line references where applicable.

\`\`\`diff
${diff}
\`\`\`"
      prompt_args=(--prompt "$review_prompt")
    fi
  fi

  local model_args=()
  [[ -n "$model" ]] && model_args=(-m "$model")

  printf "${_AI[bmag]}▶${_AI[r]} OpenCode ${_AI[b]}build${_AI[r]}${model:+ ${_AI[d]}$model${_AI[r]}}\n"
  _ai_save_last "oc"
  opencode --agent build "${model_args[@]}" "${prompt_args[@]}" "${args[@]}"
}

_ai_run_custom() {
  _ai_require_cmd claude || return 1

  local model="" endpoint="" apikey="" args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)    model="$2"; shift 2 ;;
      --endpoint) endpoint="$2"; shift 2 ;;
      --apikey)   apikey="$2"; shift 2 ;;
      *)          args+=("$1"); shift ;;
    esac
  done

  [[ -z "$model" ]]    && { printf "${_AI[red]}✗ --model required${_AI[r]}\n"; return 1; }
  [[ -z "$endpoint" ]] && { printf "${_AI[red]}✗ --endpoint required${_AI[r]}\n"; return 1; }
  [[ -z "$apikey" ]]   && { printf "${_AI[red]}✗ --apikey required${_AI[r]}\n"; return 1; }

  printf "${_AI[bmag]}▶${_AI[r]} Custom ${_AI[b]}%s${_AI[r]} ${_AI[d]}@ %s${_AI[r]}\n" "$model" "$endpoint"
  _ai_save_last "custom --model $model --endpoint $endpoint --apikey $apikey"

  ANTHROPIC_AUTH_TOKEN="$apikey" \
  ANTHROPIC_BASE_URL="$endpoint" \
  ANTHROPIC_API_KEY="" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$model" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$model" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$model" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude --dangerously-skip-permissions --model "$model" "${args[@]}"
}

# ─── fzf picker ──────────────────────────────────────────────────────────────

_ai_pick() {
  if ! command -v fzf &>/dev/null; then
    printf "${_AI[red]}✗ fzf not found.${_AI[r]} Install with: brew install fzf\n"
    _ai_help
    return 1
  fi

  # Tab-delimited: cmd<TAB>display — fzf shows only display, we extract cmd.
  local -a entries=()
  _ai_cmd_available sonnet    && entries+=("sonnet"$'\t'"$(_ai_check_cmd claude)  sonnet     │  Claude Sonnet        │  claude-sonnet-4      │  claude")
  _ai_cmd_available haiku     && entries+=("haiku"$'\t'"$(_ai_check_cmd claude)  haiku      │  Claude Haiku         │  claude-haiku-4       │  claude")
  _ai_cmd_available opus      && entries+=("opus"$'\t'"$(_ai_check_cmd claude)  opus       │  Claude Opus          │  claude-opus-4        │  claude")
  _ai_cmd_available glm       && entries+=("glm"$'\t'"$(_ai_check GLM_API_KEY)  glm        │  GLM-4.7 (Z.ai)       │  glm-4.7              │  claude")
  _ai_cmd_available kimi      && entries+=("kimi"$'\t'"$(_ai_check KIMI_API_KEY)  kimi       │  Kimi K2.5            │  kimi-k2.5            │  claude")
  _ai_cmd_available mini      && entries+=("mini"$'\t'"$(_ai_check MINIMAX_API_KEY)  mini       │  MiniMax M2.1         │  MiniMax-M2.1         │  claude")
  _ai_cmd_available openrouter && entries+=("openrouter"$'\t'"$(_ai_check OPENROUTER_API_KEY)  openrouter │  OpenRouter           │  claude-sonnet-4      │  claude")
  _ai_cmd_available ollama    && entries+=("ollama"$'\t'"$(_ai_check_ollama)  ollama     │  Ollama Local         │  glm-5:cloud          │  claude")
  _ai_cmd_available codex     && entries+=("codex"$'\t'"$(_ai_check OPENAI_API_KEY)  codex      │  OpenAI Codex CLI     │  codex                │  openai")
  _ai_cmd_available gemini    && entries+=("gemini"$'\t'"$(_ai_check GEMINI_API_KEY)  gemini     │  Gemini CLI (yolo)    │  gemini-cli           │  google")
  _ai_cmd_available cp        && entries+=("cp"$'\t'"$(_ai_check_cmd copilot)  cp         │  GitHub Copilot CLI   │  copilot              │  github")
  _ai_cmd_available oc        && entries+=("oc"$'\t'"$(_ai_check_cmd opencode)  oc         │  OpenCode CLI         │  build agent          │  opencode")

  if (( ${#entries[@]} == 0 )); then
    printf "${_AI[yellow]}⚠ No provider is currently available. Run ${_AI[cyan]}ai --help${_AI[r]} for setup status.\n"
    return 1
  fi

  local header="   CMD     │  PROVIDER        │  MODEL                │  BACKEND"

  local choice
  choice=$(printf '%s\n' "${entries[@]}" | fzf \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=2 \
    --header="$header" \
    --prompt="ai ❯ " \
    --height=~14 \
    --reverse \
    --no-info \
    --pointer="▶" \
    --color="pointer:cyan,prompt:cyan,header:dim" \
  )

  [[ -z "$choice" ]] && return 0

  ai "${choice%%$'\t'*}"
}

# ─── Help ────────────────────────────────────────────────────────────────────

_ai_help() {
  local printed=0
  local example_count=0
  printf "\n"
  printf "${_AI[bcyan]}  ▄▀█ █${_AI[r]}   ${_AI[d]}AI Provider Launcher${_AI[r]}\n"
  printf "${_AI[bcyan]}  █▀█ █${_AI[r]}   ${_AI[d]}v3.1${_AI[r]}\n"
  printf "\n"
  printf "  ${_AI[b]}USAGE${_AI[r]}\n"
  printf "    ai                     interactive picker (fzf)\n"
  printf "    ai ${_AI[cyan]}<cmd>${_AI[r]} [args...]     launch provider directly\n"
  printf "\n"
  printf "  ${_AI[b]}COMMANDS${_AI[r]}\n"
  printf "  ${_AI[b]}  CLAUDE CODE${_AI[r]}\n"
  _ai_cmd_available sonnet    && { _ai_help_cmd_row "sonnet" "s" "Claude Sonnet"; printed=1; }
  _ai_cmd_available haiku     && { _ai_help_cmd_row "haiku" "h" "Claude Haiku"; printed=1; }
  _ai_cmd_available opus      && { _ai_help_cmd_row "opus" "o" "Claude Opus"; printed=1; }
  _ai_cmd_available glm       && { _ai_help_cmd_row "glm" "g" "GLM-4.7 (Z.ai)"; printed=1; }
  _ai_cmd_available kimi      && { _ai_help_cmd_row "kimi" "k" "Kimi K2.5 (Moonshot)"; printed=1; }
  _ai_cmd_available mini      && { _ai_help_cmd_row "mini" "m" "MiniMax M2.1"; printed=1; }
  _ai_cmd_available openrouter && { _ai_help_cmd_row "openrouter" "or" "OpenRouter (--model)"; printed=1; }
  _ai_cmd_available ollama    && { _ai_help_cmd_row "ollama" "ol" "Ollama local (--model)"; printed=1; }
  _ai_cmd_available custom    && { _ai_help_cmd_row "custom" "cu" "Custom endpoint"; printed=1; }
  printf "\n"
  printf "  ${_AI[b]}  OTHERS${_AI[r]}\n"
  _ai_cmd_available codex     && { _ai_help_cmd_row "codex" "c" "OpenAI Codex CLI"; printed=1; }
  _ai_cmd_available gemini    && { _ai_help_cmd_row "gemini" "ge" "Gemini CLI (--yolo)"; printed=1; }
  _ai_cmd_available cp        && { _ai_help_cmd_row "copilot" "cp" "GitHub Copilot CLI"; printed=1; }
  _ai_cmd_available oc        && { _ai_help_cmd_row "opencode" "oc" "OpenCode CLI (--model --review)"; printed=1; }
  printf "\n"
  printf "  ${_AI[b]}  UTILITIES${_AI[r]}\n"
  _ai_cmd_available last      && { _ai_help_cmd_row "last" "l" "Re-run last provider"; printed=1; }
  _ai_help_cmd_row "help" "-h" "Show help and status"
  (( printed == 0 )) && printf "    ${_AI[yellow]}⚠ No providers available yet. Configure keys/tools below.${_AI[r]}\n"
  printf "\n"
  printf "  ${_AI[b]}EXAMPLES${_AI[r]}\n"
  _ai_cmd_available sonnet    && { printf "    ${_AI[d]}ai s \"review this diff\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available haiku     && { printf "    ${_AI[d]}ai h \"summarize this error\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available glm       && { printf "    ${_AI[d]}ai g \"design a rollback\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available kimi      && { printf "    ${_AI[d]}ai k \"plan migration\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available openrouter && { printf "    ${_AI[d]}ai or --model anthropic/claude-opus-4 \"analyze this\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available ollama    && { printf "    ${_AI[d]}ai ol --model qwen2.5-coder:14b \"write tests\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available codex     && { printf "    ${_AI[d]}ai c \"refactor this\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available gemini    && { printf "    ${_AI[d]}ai ge \"summarize PR\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available cp        && { printf "    ${_AI[d]}ai cp \"create release notes\"${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available oc        && { printf "    ${_AI[d]}ai oc --review${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available last      && { printf "    ${_AI[d]}ai l${_AI[r]}\n"; ((example_count++)); }
  _ai_cmd_available custom    && { printf "    ${_AI[d]}ai cu --model <m> --endpoint <url> --apikey <key> \"prompt\"${_AI[r]}\n"; ((example_count++)); }
  (( example_count == 0 )) && printf "    ${_AI[d]}ai -h${_AI[r]}\n"
  printf "\n"
  printf "  ${_AI[b]}STATUS${_AI[r]}\n"
  _ai_help_status_row "$(_ai_check_cmd claude)" "claude (cli)" "$(_ai_check_cmd codex)" "codex (cli)"
  _ai_help_status_row "$(_ai_check_cmd gemini)" "gemini (cli)" "$(_ai_check_cmd copilot)" "copilot (cli)"
  _ai_help_status_row "$(_ai_check_cmd opencode)" "opencode (cli)" "$(_ai_check_ollama)" "ollama (localhost)"
  _ai_help_status_row "$(_ai_check GLM_API_KEY)" "GLM_API_KEY" "$(_ai_check KIMI_API_KEY)" "KIMI_API_KEY"
  _ai_help_status_row "$(_ai_check MINIMAX_API_KEY)" "MINIMAX_API_KEY" "$(_ai_check OPENROUTER_API_KEY)" "OPENROUTER_API_KEY"
  _ai_help_status_row "$(_ai_check OPENAI_API_KEY)" "OPENAI_API_KEY" "$(_ai_check GEMINI_API_KEY)" "GEMINI_API_KEY"
  printf "\n"
}

# ─── Ship command ───────────────────────────────────────────────────────────

_ai_run_ship() {
  local provider="$1"; shift

  # Check if in git repo
  if ! _ai_in_git_repo; then
    printf "${_AI[red]}✗ Not in a git repository${_AI[r]}\n"
    return 1
  fi

  # Warn if gh not available
  if ! _ai_has_cmd gh; then
    printf "${_AI[yellow]}⚠ gh CLI not found. PR creation will not work.${_AI[r]}\n"
    printf "   Install: brew install gh && gh auth login\n"
  fi

  # Build the launch command based on provider
  case "$provider" in
    sonnet|s)       _ai_run_claude_ship "sonnet" "$@" ;;
    haiku|h)        _ai_run_claude_ship "haiku" "$@" ;;
    opus|o)         _ai_run_claude_ship "opus" "$@" ;;
    glm|g)          _ai_run_provider_ship "glm" "$@" ;;
    kimi|k)         _ai_run_provider_ship "kimi" "$@" ;;
    mini|m)         _ai_run_provider_ship "mini" "$@" ;;
    or|openrouter)  _ai_run_provider_ship "or" "$@" ;;
    ol|ollama)      _ai_run_provider_ship "ol" "$@" ;;
    *)
      printf "${_AI[red]}✗ Unknown provider for ship: %s${_AI[r]}\n" "$provider"
      return 1
      ;;
  esac
}

_ai_run_claude_ship() {
  local model="$1"; shift
  _ai_require_cmd claude || return 1
  printf "${_AI[bcyan]}▶${_AI[r]} Claude Ship ${_AI[b]}%s${_AI[r]}\n" "$model"
  _ai_save_last "$model ship"
  claude --dangerously-skip-permissions --model "$model" \
    --system-prompt "$_AI_SHIP_PROMPT" \
    -p "Let's review and commit the changes. What's the current git status?" \
    "$@"
}

_ai_run_provider_ship() {
  local key="$1"; shift
  local cfg="${_AI_PROVIDERS[$key]}"
  [[ -z "$cfg" ]] && { printf "${_AI[red]}✗ Unknown provider: %s${_AI[r]}\n" "$key"; return 1; }

  _ai_require_cmd claude || return 1

  local parts=("${(@s:|:)cfg}")
  local env_var="$parts[1]"   base_url="$parts[2]"  default_model="$parts[3]"
  local haiku="$parts[4]"     sonnet="$parts[5]"    opus="$parts[6]"
  local color="$parts[7]"     label="$parts[8]"     model_flag="$parts[9]"

  # Resolve auth token
  local token
  if [[ "$env_var" == "_OLLAMA" ]]; then
    _ai_has_ollama || {
      printf "${_AI[red]}✗ Ollama unavailable (install ollama and run server at localhost:11434)${_AI[r]}\n"
      return 1
    }
    token="ollama"
  else
    token="${(P)env_var}"
    [[ -z "$token" ]] && { printf "${_AI[red]}✗ %s not set${_AI[r]}\n" "$env_var"; return 1; }
  fi

  printf "${_AI[$color]}▶${_AI[r]} %s Ship ${_AI[b]}%s${_AI[r]}\n" "$label" "$default_model"
  _ai_save_last "$key ship"

  ANTHROPIC_AUTH_TOKEN="$token" \
  ANTHROPIC_BASE_URL="$base_url" \
  ANTHROPIC_API_KEY="" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$default_model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$opus" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude --dangerously-skip-permissions \
    --system-prompt "$_AI_SHIP_PROMPT" \
    -p "Let's review and commit the changes. What's the current git status?" \
    "$@"
}

# ─── Main dispatcher ────────────────────────────────────────────────────────

_ai_in_git_repo() {
  git rev-parse --git-dir &>/dev/null
}

ai() {
  # Ship subcommand detection
  if [[ $# -ge 2 && "$2" == "ship" ]]; then
    local provider="$1"
    shift 2
    _ai_run_ship "$provider" "$@"
    return
  fi
  if [[ $# -eq 1 && "$1" == "ship" ]]; then
    _ai_run_ship "haiku"
    return
  fi

  if [[ $# -eq 0 ]]; then
    _ai_pick
    return
  fi

  local cmd="$1"; shift
  case "$cmd" in
    sonnet|s)       _ai_run_claude sonnet "$@" ;;
    haiku|h)        _ai_run_claude haiku "$@" ;;
    opus|o)         _ai_run_claude opus "$@" ;;
    glm|g)          _ai_run_provider glm "$@" ;;
    kimi|k)         _ai_run_provider kimi "$@" ;;
    mini|m)         _ai_run_provider mini "$@" ;;
    or|openrouter)  _ai_run_provider or "$@" ;;
    ol|ollama)      _ai_run_provider ol "$@" ;;
    codex|c)        _ai_run_codex "$@" ;;
    gemini|ge)      _ai_run_gemini "$@" ;;
    copilot|cp)     _ai_run_copilot "$@" ;;
    oc|opencode)    _ai_run_opencode "$@" ;;
    custom|cu)      _ai_run_custom "$@" ;;
    last|l)
      local last_file="${TMPDIR:-/tmp}/.ai_last_provider"
      [[ -f "$last_file" ]] || { printf "${_AI[red]}✗ No previous provider${_AI[r]}\n"; return 1; }
      ai "$(< "$last_file")" "$@"
      ;;
    help|--help|-h) _ai_help ;;
    *)
      printf "${_AI[red]}✗ Unknown command:${_AI[r]} %s\n" "$cmd"
      _ai_help
      return 1
      ;;
  esac
}

# ─── Completions ─────────────────────────────────────────────────────────────

_ai_completions() {
  local -a subcmds=(
    'sonnet:Claude Sonnet'
    's:Claude Sonnet'
    'haiku:Claude Haiku'
    'h:Claude Haiku'
    'opus:Claude Opus'
    'o:Claude Opus'
    'glm:GLM-4.7'
    'g:GLM-4.7'
    'kimi:Kimi K2.5 via Moonshot'
    'k:Kimi K2.5 via Moonshot'
    'mini:MiniMax M2.1'
    'm:MiniMax M2.1'
    'or:OpenRouter'
    'openrouter:OpenRouter'
    'ol:Ollama'
    'ollama:Ollama'
    'codex:Codex'
    'c:Codex'
    'gemini:Gemini CLI'
    'ge:Gemini CLI'
    'copilot:GitHub Copilot'
    'cp:GitHub Copilot'
    'oc:OpenCode (build agent)'
    'opencode:OpenCode (build agent)'
    'custom:Custom endpoint'
    'cu:Custom endpoint'
    'last:Re-run last provider'
    'l:Re-run last provider'
    'help:Show help'
  )
  _describe 'ai command' subcmds
}
(( ${+functions[compdef]} )) && compdef _ai_completions ai
