# Main ai command dispatcher

ai() {
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

  local cmd="$1"
  shift

  case "$cmd" in
    sonnet|s) _ai_run_claude sonnet "$@" ;;
    haiku|h) _ai_run_claude haiku "$@" ;;
    opus|o) _ai_run_claude opus "$@" ;;
    glm|g) _ai_run_provider glm "$@" ;;
    kimi|k) _ai_run_provider kimi "$@" ;;
    mini|m) _ai_run_provider mini "$@" ;;
    or|openrouter) _ai_run_provider or "$@" ;;
    ol|ollama) _ai_run_ollama "$@" ;;
    ll|llama.cpp|llamacpp|llama) _ai_run_llamacpp "$@" ;;
    codex|c) _ai_run_codex "$@" ;;
    gemini|ge) _ai_run_gemini "$@" ;;
    copilot|cp) _ai_run_copilot "$@" ;;
    oc|opencode) _ai_run_opencode "$@" ;;
    custom|cu) _ai_run_custom "$@" ;;
    bench|b) _ai_bench "$@" ;;
    install|i) _ai_install "$@" ;;
    last|l)
      local last_cmd
      last_cmd="$(_ai_load_last)" || {
        printf "${_AI[red]}✗ No previous provider${_AI[r]}\n"
        return 1
      }
      ai "$last_cmd" "$@"
      ;;
    help|--help|-h) _ai_help ;;
    *)
      printf "${_AI[red]}✗ Unknown command:${_AI[r]} %s\n" "$cmd"
      _ai_help
      return 1
      ;;
  esac
}
