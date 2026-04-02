# ai bench — run a prompt across multiple Claude-backed providers sequentially

# Providers that cannot accept a bare prompt non-interactively
typeset -ga _AI_BENCH_EXCLUDED=(codex c gemini ge copilot cp opencode oc custom cu)
typeset -ga _AI_BENCH_SUPPORTED=(
  sonnet s haiku h opus o glm g kimi k mini m or openrouter ol ollama ll llama.cpp llamacpp llama
)

_ai_bench() {
  if [[ $# -lt 2 ]]; then
    printf "${_AI[red]}✗ Usage: ai bench <prompt> <provider> [provider...]${_AI[r]}\n"
    return 1
  fi

  local prompt="$1"
  shift

  local -a available=()
  local candidate=""
  for p in "$@"; do
    if (( ${_AI_BENCH_EXCLUDED[(Ie)$p]} )); then
      printf "${_AI[yellow]}⚠ %s: not supported in bench (non-Claude provider)${_AI[r]}\n" "$p" >&2
      continue
    fi
    if (( ! ${_AI_BENCH_SUPPORTED[(Ie)$p]} )); then
      printf "${_AI[yellow]}⚠ %s: unavailable, skipping${_AI[r]}\n" "$p" >&2
      continue
    fi
    case "$p" in
      s) candidate="sonnet" ;;
      h) candidate="haiku" ;;
      o) candidate="opus" ;;
      g) candidate="glm" ;;
      k) candidate="kimi" ;;
      m) candidate="mini" ;;
      *) candidate="$p" ;;
    esac
    if ! _ai_cmd_available "$candidate"; then
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
  local had_failure=0

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
    local rc=$?
    if (( rc != 0 )); then
      had_failure=1
      printf "${_AI[yellow]}⚠ %s: provider failed, continuing${_AI[r]}\n" "$p" >&2
      (( i++ ))
      continue
    fi

    local elapsed=$(( SECONDS - start ))
    printf "\n${_AI[green]}✓ %s  %ds${_AI[r]}\n" "$p" "$elapsed"
    (( i++ ))
  done

  (( had_failure == 0 )) || return 1
}
