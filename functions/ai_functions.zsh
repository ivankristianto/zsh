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

# ─── Provider registry ──────────────────────────────────────────────────────
# Anthropic-compatible providers: env_var|base_url|model|haiku|sonnet|opus|color|label|model_flag
#   model_flag: 1 = supports --model override + passes --model to claude, 0 = fixed model

typeset -gA _AI_PROVIDERS=(
  [glm]="GLM_API_KEY|https://api.z.ai/api/anthropic|glm-4.7|glm-4.5-Air|glm-4.7|glm-4.7|byel|GLM|0"
  [mini]="MINIMAX_API_KEY|https://api.minimax.io/anthropic|MiniMax-M2.1|MiniMax-M2.1|MiniMax-M2.1|MiniMax-M2.1|bmag|MiniMax|0"
  [or]="OPENROUTER_API_KEY|https://openrouter.ai/api|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|bgreen|OpenRouter|1"
  [ol]="_OLLAMA|http://localhost:11434|glm-5:cloud|glm-5:cloud|glm-5:cloud|glm-5:cloud|blue|Ollama|1"
)

# ─── Internal helpers ────────────────────────────────────────────────────────

_ai_require_cmd() {
  command -v "$1" &>/dev/null || {
    printf "${_AI[red]}✗ %s not found${_AI[r]}\n" "$1"
    return 1
  }
}

_ai_check() {
  if [[ -n "${(P)1}" ]]; then
    printf "${_AI[green]}●${_AI[r]}"
  else
    printf "${_AI[red]}○${_AI[r]}"
  fi
}

_ai_check_cmd() {
  if command -v "$1" &>/dev/null; then
    printf "${_AI[green]}●${_AI[r]}"
  else
    printf "${_AI[red]}○${_AI[r]}"
  fi
}

_ai_check_ollama() {
  if curl -sf --connect-timeout 1 http://localhost:11434/api/tags >/dev/null 2>&1; then
    printf "${_AI[green]}●${_AI[r]}"
  else
    printf "${_AI[red]}○${_AI[r]}"
  fi
}

_ai_save_last() {
  printf '%s' "$1" > "${TMPDIR:-/tmp}/.ai_last_provider"
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
    curl -sf --connect-timeout 1 http://localhost:11434/api/tags >/dev/null 2>&1 || {
      printf "${_AI[red]}✗ Ollama not running at localhost:11434${_AI[r]}\n"
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

  # Tab-delimited: cmd<TAB>display — fzf shows only display, we extract cmd
  local entries=(
    "sonnet"$'\t'"$(_ai_check_cmd claude)  sonnet  │  Claude Sonnet   │  claude-sonnet-4      │  anthropic"
    "haiku"$'\t'"$(_ai_check_cmd claude)  haiku   │  Claude Haiku    │  claude-haiku-4       │  anthropic"
    "opus"$'\t'"$(_ai_check_cmd claude)  opus    │  Claude Opus     │  claude-opus-4        │  anthropic"
    "glm"$'\t'"$(_ai_check GLM_API_KEY)  glm     │  GLM-4.7         │  glm-4.7              │  z.ai"
    "mini"$'\t'"$(_ai_check MINIMAX_API_KEY)  mini    │  MiniMax M2.1    │  MiniMax-M2.1         │  minimax"
    "or"$'\t'"$(_ai_check OPENROUTER_API_KEY)  or      │  OpenRouter      │  claude-sonnet-4      │  openrouter"
    "ol"$'\t'"$(_ai_check_ollama)  ol      │  Ollama          │  glm-5:cloud          │  local"
    "codex"$'\t'"$(_ai_check OPENAI_API_KEY)  codex   │  Codex           │  codex                │  openai"
    "gemini"$'\t'"$(_ai_check GEMINI_API_KEY)  gemini  │  Gemini          │  gemini-cli           │  google"
    "cp"$'\t'"$(_ai_check_cmd copilot)  cp      │  Copilot         │  copilot              │  github"
    "oc"$'\t'"$(_ai_check_cmd opencode)  oc      │  OpenCode        │  build agent          │  opencode"
  )

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
  printf "\n"
  printf "${_AI[bcyan]}  ▄▀█ █${_AI[r]}   ${_AI[d]}AI Provider Launcher${_AI[r]}\n"
  printf "${_AI[bcyan]}  █▀█ █${_AI[r]}   ${_AI[d]}v3.0${_AI[r]}\n"
  printf "\n"
  printf "  ${_AI[b]}USAGE${_AI[r]}\n"
  printf "    ai                     interactive picker (fzf)\n"
  printf "    ai ${_AI[cyan]}<cmd>${_AI[r]} [args...]     launch provider directly\n"
  printf "\n"
  printf "  ${_AI[b]}COMMANDS${_AI[r]}\n"
  printf "    ${_AI[cyan]}sonnet${_AI[r]}  ${_AI[d]}s${_AI[r]}    Claude Sonnet\n"
  printf "    ${_AI[cyan]}haiku${_AI[r]}   ${_AI[d]}h${_AI[r]}    Claude Haiku\n"
  printf "    ${_AI[cyan]}opus${_AI[r]}    ${_AI[d]}o${_AI[r]}    Claude Opus\n"
  printf "    ${_AI[cyan]}glm${_AI[r]}     ${_AI[d]}g${_AI[r]}    GLM-4.7 via Z.ai\n"
  printf "    ${_AI[cyan]}mini${_AI[r]}    ${_AI[d]}m${_AI[r]}    MiniMax M2.1\n"
  printf "    ${_AI[cyan]}or${_AI[r]}           OpenRouter          ${_AI[d]}--model to override${_AI[r]}\n"
  printf "    ${_AI[cyan]}ol${_AI[r]}           Ollama              ${_AI[d]}--model to override${_AI[r]}\n"
  printf "    ${_AI[cyan]}codex${_AI[r]}   ${_AI[d]}c${_AI[r]}    OpenAI Codex\n"
  printf "    ${_AI[cyan]}gemini${_AI[r]}  ${_AI[d]}ge${_AI[r]}   Gemini CLI (yolo)\n"
  printf "    ${_AI[cyan]}copilot${_AI[r]} ${_AI[d]}cp${_AI[r]}   GitHub Copilot\n"
  printf "    ${_AI[cyan]}oc${_AI[r]}           OpenCode            ${_AI[d]}build agent  --model  --review${_AI[r]}\n"
  printf "    ${_AI[cyan]}custom${_AI[r]}  ${_AI[d]}cu${_AI[r]}   Custom endpoint     ${_AI[d]}--model --endpoint --apikey${_AI[r]}\n"
  printf "    ${_AI[cyan]}last${_AI[r]}    ${_AI[d]}l${_AI[r]}    Re-run last provider\n"
  printf "\n"
  printf "  ${_AI[b]}EXAMPLES${_AI[r]}\n"
  printf "    ${_AI[d]}ai sonnet \"explain this code\"${_AI[r]}\n"
  printf "    ${_AI[d]}ai or --model anthropic/claude-opus-4 \"analyze\"${_AI[r]}\n"
  printf "    ${_AI[d]}ai ol --model llama3.2 \"quick question\"${_AI[r]}\n"
  printf "    ${_AI[d]}ai custom --model gpt-4o --endpoint https://api.example.com --apikey sk-...${_AI[r]}\n"
  printf "    ${_AI[d]}ai oc                                     # opencode TUI (build agent)${_AI[r]}\n"
  printf "    ${_AI[d]}ai oc --review                            # review uncommitted or branch changes${_AI[r]}\n"
  printf "    ${_AI[d]}ai last                                   # re-run last used${_AI[r]}\n"
  printf "\n"
  printf "  ${_AI[b]}STATUS${_AI[r]}\n"
  printf "    $(_ai_check_cmd claude) Claude (cli)           $(_ai_check GLM_API_KEY) GLM_API_KEY\n"
  printf "    $(_ai_check OPENROUTER_API_KEY) OPENROUTER_API_KEY     $(_ai_check MINIMAX_API_KEY) MINIMAX_API_KEY\n"
  printf "    $(_ai_check OPENAI_API_KEY) OPENAI_API_KEY         $(_ai_check GEMINI_API_KEY) GEMINI_API_KEY\n"
  printf "    $(_ai_check_ollama) Ollama (localhost)     $(_ai_check_cmd opencode) opencode (cli)\n"
  printf "    $(_ai_check_cmd copilot) copilot (cli)\n"
  printf "\n"
}

# ─── Main dispatcher ────────────────────────────────────────────────────────

ai() {
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
    mini|m)         _ai_run_provider mini "$@" ;;
    or)             _ai_run_provider or "$@" ;;
    ol)             _ai_run_provider ol "$@" ;;
    codex|c)        _ai_run_codex "$@" ;;
    gemini|ge)      _ai_run_gemini "$@" ;;
    copilot|cp)     _ai_run_copilot "$@" ;;
    oc)             _ai_run_opencode "$@" ;;
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
    'mini:MiniMax M2.1'
    'm:MiniMax M2.1'
    'or:OpenRouter'
    'ol:Ollama'
    'codex:Codex'
    'c:Codex'
    'gemini:Gemini CLI'
    'ge:Gemini CLI'
    'copilot:GitHub Copilot'
    'cp:GitHub Copilot'
    'oc:OpenCode (build agent)'
    'custom:Custom endpoint'
    'cu:Custom endpoint'
    'last:Re-run last provider'
    'l:Re-run last provider'
    'help:Show help'
  )
  _describe 'ai command' subcmds
}
(( ${+functions[compdef]} )) && compdef _ai_completions ai
