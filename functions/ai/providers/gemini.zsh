# Gemini provider

_ai_run_gemini() {
  _ai_require_cmd gemini || return 1
  [[ -z "$GEMINI_API_KEY" ]] && {
    printf "${_AI[red]}✗ GEMINI_API_KEY not set${_AI[r]}\n"
    return 1
  }
  printf "${_AI[byel]}▶${_AI[r]} Gemini ${_AI[b]}yolo${_AI[r]}\n"
  _ai_save_last "gemini"
  gemini --yolo "$@"
}
