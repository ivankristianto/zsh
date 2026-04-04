# Shared constants and helpers for AI launcher

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

_ai_last_file() {
  print -r -- "${TMPDIR:-/tmp}/.ai_last_provider"
}

_ai_has_env() {
  local var_name="$1"
  [[ -n "${(P)var_name-}" ]]
}

_ai_has_cmd() {
  command -v "$1" >/dev/null 2>&1
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

_ai_require_flag_value() {
  local flag="$1"
  local value="${2-}"
  [[ -n "$value" && "$value" != --* ]] && return 0
  printf "${_AI[red]}✗ %s requires a value${_AI[r]}\n" "$flag"
  return 1
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
  local last_file
  last_file="$(_ai_last_file)"
  printf '%s' "$1" > "$last_file"
}

_ai_load_last() {
  local last_file
  last_file="$(_ai_last_file)"
  [[ -f "$last_file" ]] || return 1
  cat "$last_file"
}

_ai_in_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

_ai_npm_install_global() {
  _ai_require_cmd npm || return 1

  if [[ "${AI_INSTALL_DRY_RUN:-0}" == "1" ]]; then
    printf "${_AI[yellow]}DRY-RUN${_AI[r]} npm install -g %s\n" "$*"
    return 0
  fi

  npm install -g "$@"
}

_ai_cmd_available() {
  local cmd="$1"
  case "$cmd" in
    sonnet|haiku|opus|custom) _ai_has_cmd claude ;;
    glm)                      _ai_has_cmd claude && _ai_has_env GLM_API_KEY ;;
    kimi|k)                   _ai_has_cmd claude && _ai_has_env KIMI_API_KEY ;;
    mini|m)                   _ai_has_cmd claude && _ai_has_env MINIMAX_API_KEY ;;
    or|openrouter)            _ai_has_cmd claude && _ai_has_env OPENROUTER_API_KEY ;;
    ol|ollama)                _ai_has_cmd claude && _ai_has_ollama ;;
    ll|llama.cpp|llamacpp|llama) _ai_has_cmd claude ;;
    codex|c)                  _ai_has_cmd codex && _ai_has_env OPENAI_API_KEY ;;
    gemini|ge)                _ai_has_cmd gemini && _ai_has_env GEMINI_API_KEY ;;
    copilot|cp)               _ai_has_cmd copilot ;;
    oc|opencode)              _ai_has_cmd opencode ;;
    last|l)                   [[ -f "$(_ai_last_file)" ]] ;;
    install|i|help|--help|-h) return 0 ;;
    *)                        return 1 ;;
  esac
}

# Provider config lookup. Returns the value of field for provider key.
# Returns non-zero if the provider key is not registered.
_ai_pget() {
  local key="$1" field="$2"
  local varname="_AI_P_${key}"
  (( ${(P)+varname} )) || return 1
  print -- "${${(P)varname}[$field]:-}"
}

# Shared provider executor: validates token, sets ANTHROPIC_* env, runs claude.
# Usage: _ai_provider_exec <key> <model_override|""> [claude_args...]
# model_override controls ANTHROPIC_MODEL; pass "" to use the provider default.
# Does NOT print a header or call _ai_save_last — callers are responsible for those.
_ai_provider_exec() {
  local key="$1"
  local override_model="${2:-}"
  shift 2

  local env_var url default_model haiku sonnet_m opus
  env_var="$(_ai_pget "$key" env)"
  url="$(_ai_pget "$key" url)"
  default_model="$(_ai_pget "$key" model)"
  haiku="$(_ai_pget "$key" haiku)"
  sonnet_m="$(_ai_pget "$key" sonnet)"
  opus="$(_ai_pget "$key" opus)"

  local model="${override_model:-$default_model}"
  local token="" api_key=""

  if [[ "$env_var" == "_OLLAMA" ]]; then
    _ai_has_ollama || {
      printf "${_AI[red]}✗ Ollama unavailable (install ollama and run server at localhost:11434)${_AI[r]}\n"
      return 1
    }
    token="ollama"
  elif [[ "$env_var" == "_LLAMACPP" ]]; then
    token="sk-no-key-required"
    api_key="sk-no-key-required"
    url="http://localhost:8001"
  else
    token="${(P)env_var}"
    [[ -z "$token" ]] && {
      printf "${_AI[red]}✗ %s not set${_AI[r]}\n" "$env_var"
      return 1
    }
  fi

  ANTHROPIC_AUTH_TOKEN="$token" \
  ANTHROPIC_BASE_URL="$url" \
  ANTHROPIC_API_KEY="$api_key" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet_m" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$opus" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "$@"
}
