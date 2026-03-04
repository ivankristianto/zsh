# Copilot provider

_ai_run_copilot() {
  _ai_require_cmd copilot || return 1
  printf "${_AI[bgreen]}▶${_AI[r]} Copilot\n"
  _ai_save_last "cp"
  copilot --allow-all "$@"
}
