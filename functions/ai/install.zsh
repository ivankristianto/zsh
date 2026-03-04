# Installer utilities

typeset -gA _AI_INSTALL_PACKAGES=(
  [claude]='@anthropic-ai/claude-code'
  [codex]='@openai/codex'
  [gemini]='@google/gemini-cli'
  [ollama]='ollama'
  [copilot]='@github/copilot'
  [opencode]='opencode-ai'
)

_ai_install_usage() {
  printf "${_AI[b]}Usage:${_AI[r]} ai install <agent> [--dry-run]\n"
  printf "${_AI[d]}Supported agents:${_AI[r]} claude codex gemini ollama copilot opencode\n"
}

_ai_install_resolve_agent() {
  case "$1" in
    c|codex) print -r -- "codex" ;;
    ge|gemini) print -r -- "gemini" ;;
    cp|copilot) print -r -- "copilot" ;;
    ol|ollama) print -r -- "ollama" ;;
    oc|opencode) print -r -- "opencode" ;;
    claude) print -r -- "claude" ;;
    *) return 1 ;;
  esac
}

_ai_install() {
  local dry_run=0
  local agent=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=1
        shift
        ;;
      -h|--help)
        _ai_install_usage
        return 0
        ;;
      *)
        if [[ -n "$agent" ]]; then
          printf "${_AI[red]}✗ Unexpected argument: %s${_AI[r]}\n" "$1"
          _ai_install_usage
          return 1
        fi
        agent="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$agent" ]]; then
    _ai_install_usage
    return 1
  fi

  local normalized
  normalized="$(_ai_install_resolve_agent "$agent")" || {
    printf "${_AI[red]}✗ Unsupported agent: %s${_AI[r]}\n" "$agent"
    _ai_install_usage
    return 1
  }

  local pkg="${_AI_INSTALL_PACKAGES[$normalized]}"
  [[ -z "$pkg" ]] && {
    printf "${_AI[red]}✗ No install package mapped for: %s${_AI[r]}\n" "$normalized"
    return 1
  }

  if [[ "$normalized" == "ollama" ]]; then
    printf "${_AI[yellow]}⚠ Note:${_AI[r]} npm package %s does not provide the official Ollama server binary.\n" "$pkg"
    printf "  Install server separately from https://ollama.com/download for local model runtime.\n"
  fi

  printf "${_AI[bcyan]}▶${_AI[r]} Installing ${_AI[b]}%s${_AI[r]} (${_AI[d]}%s${_AI[r]})\n" "$normalized" "$pkg"

  if [[ "$dry_run" -eq 1 ]]; then
    AI_INSTALL_DRY_RUN=1 _ai_npm_install_global "$pkg"
  else
    _ai_npm_install_global "$pkg"
  fi
}
