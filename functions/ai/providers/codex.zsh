# Codex provider

_ai_run_codex() {
  _ai_require_cmd codex || return 1
  [[ -z "$OPENAI_API_KEY" ]] && {
    printf "${_AI[red]}✗ OPENAI_API_KEY not set${_AI[r]}\n"
    return 1
  }
  printf "${_AI[bred]}▶${_AI[r]} Codex\n"
  _ai_save_last "codex"
  codex --dangerously-bypass-approvals-and-sandbox "$@"
}
