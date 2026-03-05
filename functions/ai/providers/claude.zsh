# Claude-based providers (including Anthropic-compatible endpoints)

typeset -gA _AI_PROVIDERS=(
  [glm]="GLM_API_KEY|https://api.z.ai/api/anthropic|glm-4.7|glm-4.5-Air|glm-4.7|glm-4.7|byel|GLM|0"
  [kimi]="KIMI_API_KEY|https://api.kimi.com/coding/|kimi-k2.5|kimi-k2.5|kimi-k2.5|kimi-k2.5|mag|Kimi|0"
  [mini]="MINIMAX_API_KEY|https://api.minimax.io/anthropic|MiniMax-M2.1|MiniMax-M2.1|MiniMax-M2.1|MiniMax-M2.1|bmag|MiniMax|0"
  [or]="OPENROUTER_API_KEY|https://openrouter.ai/api|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|anthropic/claude-sonnet-4|bgreen|OpenRouter|1"
  [ol]="_OLLAMA|http://localhost:11434|glm-5:cloud|glm-5:cloud|glm-5:cloud|glm-5:cloud|blue|Ollama|1"
  [lc]="_LLAMACPP|http://localhost:8001|llama.cpp|llama.cpp|llama.cpp|llama.cpp|green|llama.cpp|1"
)

_ai_run_provider() {
  local key="$1"
  shift

  local cfg="${_AI_PROVIDERS[$key]}"
  [[ -z "$cfg" ]] && {
    printf "${_AI[red]}✗ Unknown provider: %s${_AI[r]}\n" "$key"
    return 1
  }

  _ai_require_cmd claude || return 1

  local parts=("${(@s:|:)cfg}")
  local env_var="${parts[1]}"
  local base_url="${parts[2]}"
  local default_model="${parts[3]}"
  local haiku="${parts[4]}"
  local sonnet="${parts[5]}"
  local opus="${parts[6]}"
  local color="${parts[7]}"
  local label="${parts[8]}"
  local model_flag="${parts[9]}"

  local token
  local api_key=""
  if [[ "$env_var" == "_OLLAMA" ]]; then
    _ai_has_ollama || {
      printf "${_AI[red]}✗ Ollama unavailable (install ollama and run server at localhost:11434)${_AI[r]}\n"
      return 1
    }
    token="ollama"
  elif [[ "$env_var" == "_LLAMACPP" ]]; then
    token="sk-no-key-required"
    api_key="sk-no-key-required"
    base_url="http://localhost:8001"
  else
    token="${(P)env_var}"
    [[ -z "$token" ]] && {
      printf "${_AI[red]}✗ %s not set${_AI[r]}\n" "$env_var"
      return 1
    }
  fi

  local model="$default_model"
  if [[ "$model_flag" == "1" ]]; then
    local args=()
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--model" && -n "$2" ]]; then
        model="$2"
        shift 2
      else
        args+=("$1")
        shift
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
  ANTHROPIC_API_KEY="$api_key" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$opus" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "${cmd_args[@]}" "$@"
}

_ai_run_claude() {
  local model="${1:?model required}"
  shift
  _ai_require_cmd claude || return 1
  printf "${_AI[bcyan]}▶${_AI[r]} Claude ${_AI[b]}%s${_AI[r]}\n" "$model"
  _ai_save_last "$model"
  claude --dangerously-skip-permissions --model "$model" "$@"
}

_ai_run_custom() {
  _ai_require_cmd claude || return 1

  local model=""
  local endpoint=""
  local apikey=""
  local apikey_env=""
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)
        _ai_require_flag_value "--model" "${2-}" || return 1
        model="$2"
        shift 2
        ;;
      --endpoint)
        _ai_require_flag_value "--endpoint" "${2-}" || return 1
        endpoint="$2"
        shift 2
        ;;
      --apikey)
        _ai_require_flag_value "--apikey" "${2-}" || return 1
        apikey="$2"
        shift 2
        ;;
      --apikey-env)
        _ai_require_flag_value "--apikey-env" "${2-}" || return 1
        apikey_env="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$apikey" && -n "$apikey_env" ]]; then
    apikey="${(P)apikey_env}"
  fi

  [[ -z "$model" ]] && {
    printf "${_AI[red]}✗ --model required${_AI[r]}\n"
    return 1
  }
  [[ -z "$endpoint" ]] && {
    printf "${_AI[red]}✗ --endpoint required${_AI[r]}\n"
    return 1
  }
  [[ -z "$apikey" ]] && {
    printf "${_AI[red]}✗ --apikey required${_AI[r]}\n"
    return 1
  }

  printf "${_AI[bmag]}▶${_AI[r]} Custom ${_AI[b]}%s${_AI[r]} ${_AI[d]}@ %s${_AI[r]}\n" "$model" "$endpoint"
  typeset -g AI_CUSTOM_API_KEY_LAST="$apikey"
  _ai_save_last "custom --model $model --endpoint $endpoint --apikey-env AI_CUSTOM_API_KEY_LAST"

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
