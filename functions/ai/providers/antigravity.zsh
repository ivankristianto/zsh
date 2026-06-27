# Antigravity provider

_ai_run_antigravity() {
  _ai_require_cmd agy || return 1
  printf "${_AI[bcyan]}▶${_AI[r]} Antigravity\n"
  _ai_save_last "ag"
  agy "$@"
}
