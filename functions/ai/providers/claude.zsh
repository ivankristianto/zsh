# Claude-based providers (Anthropic-compatible endpoints)
# Each provider is a named associative array _AI_P_<key>.
# Fields: env, url, model, haiku, sonnet, opus, color, label, model_flag
# Special env values: _OLLAMA (local ollama), _LLAMACPP (local llama.cpp)

typeset -gA _AI_P_glm=(
  [env]="GLM_API_KEY"
  [url]="https://api.z.ai/api/anthropic"
  [model]="glm-5.1"
  [haiku]="glm-5.1"
  [sonnet]="glm-5.1"
  [opus]="glm-5.1"
  [color]="byel"
  [label]="GLM"
  [model_flag]="0"
)

typeset -gA _AI_P_kimi=(
  [env]="KIMI_API_KEY"
  [url]="https://api.kimi.com/coding/"
  [model]="kimi-k2.5"
  [haiku]="kimi-k2.5"
  [sonnet]="kimi-k2.5"
  [opus]="kimi-k2.5"
  [color]="mag"
  [label]="Kimi"
  [model_flag]="0"
)

typeset -gA _AI_P_mini=(
  [env]="MINIMAX_API_KEY"
  [url]="https://api.minimax.io/anthropic"
  [model]="MiniMax-M2.1"
  [haiku]="MiniMax-M2.1"
  [sonnet]="MiniMax-M2.1"
  [opus]="MiniMax-M2.1"
  [color]="bmag"
  [label]="MiniMax"
  [model_flag]="0"
)

typeset -gA _AI_P_or=(
  [env]="OPENROUTER_API_KEY"
  [url]="https://openrouter.ai/api"
  [model]="anthropic/claude-sonnet-4"
  [haiku]="anthropic/claude-sonnet-4"
  [sonnet]="anthropic/claude-sonnet-4"
  [opus]="anthropic/claude-sonnet-4"
  [color]="bgreen"
  [label]="OpenRouter"
  [model_flag]="1"
)

typeset -gA _AI_P_ol=(
  [env]="_OLLAMA"
  [url]="http://localhost:11434"
  [model]="glm-5:cloud"
  [haiku]="glm-5:cloud"
  [sonnet]="glm-5:cloud"
  [opus]="glm-5:cloud"
  [color]="blue"
  [label]="Ollama"
  [model_flag]="1"
)

typeset -gA _AI_P_lc=(
  [env]="_LLAMACPP"
  [url]="http://localhost:8001"
  [model]="llama.cpp"
  [haiku]="llama.cpp"
  [sonnet]="llama.cpp"
  [opus]="llama.cpp"
  [color]="green"
  [label]="llama.cpp"
  [model_flag]="1"
)

_ai_run_provider() {
  local key="$1"
  shift

  local varname="_AI_P_${key}"
  (( ${(P)+varname} )) || {
    printf "${_AI[red]}✗ Unknown provider: %s${_AI[r]}\n" "$key"
    return 1
  }

  _ai_require_cmd claude || return 1

  local color label model_flag model
  color="$(_ai_pget "$key" color)"
  label="$(_ai_pget "$key" label)"
  model_flag="$(_ai_pget "$key" model_flag)"
  model="$(_ai_pget "$key" model)"

  local final_model="$model"
  local args=()
  if [[ "$model_flag" == "1" ]]; then
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--model" && -n "${2-}" ]]; then
        final_model="$2"
        shift 2
      else
        args+=("$1")
        shift
      fi
    done
    set -- "${args[@]}"
  fi

  printf "${_AI[$color]}▶${_AI[r]} %s ${_AI[b]}%s${_AI[r]}\n" "$label" "$final_model"
  _ai_save_last "$key"

  local cmd_args=(--dangerously-skip-permissions)
  [[ "$model_flag" == "1" ]] && cmd_args+=(--model "$final_model")

  _ai_provider_exec "$key" "$final_model" "${cmd_args[@]}" "$@"
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
