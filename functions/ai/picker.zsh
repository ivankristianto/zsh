# Interactive provider picker

_ai_pick() {
  if ! _ai_has_cmd fzf; then
    printf "${_AI[red]}✗ fzf not found.${_AI[r]} Install with: brew install fzf\n"
    _ai_help
    return 1
  fi

  local -a entries=()
  _ai_cmd_available sonnet && entries+=("sonnet"$'\t'"$(_ai_check_cmd claude)  sonnet     │  Claude Sonnet        │  claude-sonnet-4      │  claude")
  _ai_cmd_available haiku && entries+=("haiku"$'\t'"$(_ai_check_cmd claude)  haiku      │  Claude Haiku         │  claude-haiku-4       │  claude")
  _ai_cmd_available opus && entries+=("opus"$'\t'"$(_ai_check_cmd claude)  opus       │  Claude Opus          │  claude-opus-4        │  claude")
  _ai_cmd_available glm && entries+=("glm"$'\t'"$(_ai_check GLM_API_KEY)  glm        │  GLM-5.1 (Z.ai)       │  glm-5.1              │  claude")
  _ai_cmd_available kimi && entries+=("kimi"$'\t'"$(_ai_check KIMI_API_KEY)  kimi       │  Kimi K2.5            │  kimi-k2.5            │  claude")
  _ai_cmd_available mini && entries+=("mini"$'\t'"$(_ai_check MINIMAX_API_KEY)  mini       │  MiniMax M2.1         │  MiniMax-M2.1         │  claude")
  _ai_cmd_available openrouter && entries+=("openrouter"$'\t'"$(_ai_check OPENROUTER_API_KEY)  openrouter │  OpenRouter           │  claude-sonnet-4      │  claude")
  _ai_cmd_available ollama && entries+=("ollama"$'\t'"$(_ai_check_ollama)  ollama     │  Ollama Local         │  glm-5:cloud          │  claude")
  _ai_cmd_available llamacpp && entries+=("llama.cpp"$'\t'"$(_ai_check_cmd claude)  llama.cpp  │  llama.cpp Local      │  llama.cpp            │  claude")
  _ai_cmd_available codex && entries+=("codex"$'\t'"$(_ai_check OPENAI_API_KEY)  codex      │  OpenAI Codex CLI     │  codex                │  openai")
  _ai_cmd_available gemini && entries+=("gemini"$'\t'"$(_ai_check GEMINI_API_KEY)  gemini     │  Gemini CLI (yolo)    │  gemini-cli           │  google")
  _ai_cmd_available cp && entries+=("cp"$'\t'"$(_ai_check_cmd copilot)  cp         │  GitHub Copilot CLI   │  copilot              │  github")
  _ai_cmd_available oc && entries+=("oc"$'\t'"$(_ai_check_cmd opencode)  oc         │  OpenCode CLI         │  build agent          │  opencode")

  if (( ${#entries[@]} == 0 )); then
    printf "${_AI[yellow]}⚠ No provider is currently available. Run ${_AI[cyan]}ai --help${_AI[r]} for setup status.\n"
    return 1
  fi

  local header="   CMD     │  PROVIDER        │  MODEL                │  BACKEND"
  local choice
  choice=$(printf '%s\n' "${entries[@]}" | fzf \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=2 \
    --header="$header" \
    --prompt="ai ❯ " \
    --height=~14 \
    --reverse \
    --no-info \
    --pointer="▶" \
    --color="pointer:cyan,prompt:cyan,header:dim")

  [[ -z "$choice" ]] && return 0
  ai "${choice%%$'\t'*}"
}
