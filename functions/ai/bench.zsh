# ai bench — run a prompt across multiple Claude-backed providers sequentially

# Providers that cannot accept a bare prompt non-interactively
typeset -ga _AI_BENCH_EXCLUDED=(codex c gemini ge copilot cp opencode oc)

_ai_bench() {
  if [[ $# -lt 2 ]]; then
    printf "${_AI[red]}✗ Usage: ai bench <prompt> <provider> [provider...]${_AI[r]}\n"
    return 1
  fi

  local prompt="$1"
  shift

  local -a available=()
  for p in "$@"; do
    if (( ${_AI_BENCH_EXCLUDED[(Ie)$p]} )); then
      printf "${_AI[yellow]}⚠ %s: not supported in bench (non-Claude provider)${_AI[r]}\n" "$p" >&2
      continue
    fi
    if ! _ai_cmd_available "$p"; then
      printf "${_AI[yellow]}⚠ %s: unavailable, skipping${_AI[r]}\n" "$p" >&2
      continue
    fi
    available+=("$p")
  done

  if (( ${#available[@]} == 0 )); then
    printf "${_AI[red]}✗ No available Claude-backed providers to bench${_AI[r]}\n"
    return 1
  fi

  local total=${#available[@]}
  local i=1

  for p in "${available[@]}"; do
    printf "\n${_AI[bcyan]}▶ [%d/%d] %s${_AI[r]}\n" "$i" "$total" "$p"
    local start=$SECONDS

    case "$p" in
      sonnet|s)                    _ai_run_claude sonnet "$prompt" ;;
      haiku|h)                     _ai_run_claude haiku  "$prompt" ;;
      opus|o)                      _ai_run_claude opus   "$prompt" ;;
      glm|g)                       _ai_run_provider glm  "$prompt" ;;
      kimi|k)                      _ai_run_provider kimi "$prompt" ;;
      mini|m)                      _ai_run_provider mini "$prompt" ;;
      or|openrouter)               _ai_run_provider or   "$prompt" ;;
      ol|ollama)                   _ai_run_provider ol   "$prompt" ;;
      ll|llama.cpp|llamacpp|llama) _ai_run_llamacpp      "$prompt" ;;
    esac

    local elapsed=$(( SECONDS - start ))
    printf "\n${_AI[green]}✓ %s  %ds${_AI[r]}\n" "$p" "$elapsed"
    (( i++ ))
  done
}
