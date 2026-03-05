# Help output

_ai_help_cmd_row() {
  local cmd="$1"
  local alias="$2"
  local desc="$3"
  printf "    ${_AI[cyan]}%-10s${_AI[r]} ${_AI[d]}%-3s${_AI[r]}  %s\n" "$cmd" "$alias" "$desc"
}

_ai_help_status_row() {
  local lcheck="$1"
  local llabel="$2"
  local rcheck="$3"
  local rlabel="$4"
  printf "    %s %-24s %s %s\n" "$lcheck" "$llabel" "$rcheck" "$rlabel"
}

_ai_help() {
  local printed=0
  local example_count=0

  printf "\n"
  printf "${_AI[bcyan]}  ▄▀█ █${_AI[r]}   ${_AI[d]}AI Provider Launcher${_AI[r]}\n"
  printf "${_AI[bcyan]}  █▀█ █${_AI[r]}   ${_AI[d]}v4.0${_AI[r]}\n"
  printf "\n"
  printf "  ${_AI[b]}USAGE${_AI[r]}\n"
  printf "    ai                     interactive picker (fzf)\n"
  printf "    ai ${_AI[cyan]}<cmd>${_AI[r]} [args...]     launch provider directly\n"
  printf "\n"

  printf "  ${_AI[b]}COMMANDS${_AI[r]}\n"
  printf "  ${_AI[b]}  CLAUDE DOMAIN${_AI[r]}\n"
  _ai_cmd_available sonnet && { _ai_help_cmd_row "sonnet" "s" "Claude Sonnet"; printed=1; }
  _ai_cmd_available haiku && { _ai_help_cmd_row "haiku" "h" "Claude Haiku"; printed=1; }
  _ai_cmd_available opus && { _ai_help_cmd_row "opus" "o" "Claude Opus"; printed=1; }
  _ai_cmd_available glm && { _ai_help_cmd_row "glm" "g" "GLM-4.7 (Z.ai)"; printed=1; }
  _ai_cmd_available kimi && { _ai_help_cmd_row "kimi" "k" "Kimi K2.5 (Moonshot)"; printed=1; }
  _ai_cmd_available mini && { _ai_help_cmd_row "mini" "m" "MiniMax M2.1"; printed=1; }
  _ai_cmd_available openrouter && { _ai_help_cmd_row "openrouter" "or" "OpenRouter (--model)"; printed=1; }
  _ai_cmd_available ollama && { _ai_help_cmd_row "ollama" "ol" "Ollama local (--model)"; printed=1; }
  _ai_cmd_available llamacpp && { _ai_help_cmd_row "llama.cpp" "ll" "llama.cpp local (--model)"; printed=1; }
  _ai_cmd_available custom && { _ai_help_cmd_row "custom" "cu" "Custom endpoint"; printed=1; }

  printf "\n"
  printf "  ${_AI[b]}  OTHER AGENTS${_AI[r]}\n"
  _ai_cmd_available codex && { _ai_help_cmd_row "codex" "c" "OpenAI Codex CLI"; printed=1; }
  _ai_cmd_available gemini && { _ai_help_cmd_row "gemini" "ge" "Gemini CLI (--yolo)"; printed=1; }
  _ai_cmd_available copilot && { _ai_help_cmd_row "copilot" "cp" "GitHub Copilot CLI"; printed=1; }
  _ai_cmd_available opencode && { _ai_help_cmd_row "opencode" "oc" "OpenCode CLI (--model --review)"; printed=1; }

  printf "\n"
  printf "  ${_AI[b]}  UTILITIES${_AI[r]}\n"
  _ai_help_cmd_row "install" "i" "Install supported AI CLIs"
  _ai_cmd_available last && { _ai_help_cmd_row "last" "l" "Re-run last provider"; printed=1; }
  _ai_help_cmd_row "help" "-h" "Show help and status"
  (( printed == 0 )) && printf "    ${_AI[yellow]}⚠ No providers available yet. Configure keys/tools below.${_AI[r]}\n"

  printf "\n"
  printf "  ${_AI[b]}EXAMPLES${_AI[r]}\n"
  _ai_cmd_available sonnet && { printf "    ${_AI[d]}ai s \"review this diff\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available haiku && { printf "    ${_AI[d]}ai h \"summarize this error\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available glm && { printf "    ${_AI[d]}ai g \"design a rollback\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available openrouter && { printf "    ${_AI[d]}ai or --model anthropic/claude-opus-4 \"analyze this\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available llamacpp && { printf "    ${_AI[d]}ai ll --model qwen2.5-coder:14b \"draft tests\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available codex && { printf "    ${_AI[d]}ai c \"refactor this\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available gemini && { printf "    ${_AI[d]}ai ge \"summarize PR\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available copilot && { printf "    ${_AI[d]}ai cp \"create release notes\"${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available opencode && { printf "    ${_AI[d]}ai oc --review${_AI[r]}\n"; ((example_count+=1)); }
  _ai_cmd_available last && { printf "    ${_AI[d]}ai l${_AI[r]}\n"; ((example_count+=1)); }
  printf "    ${_AI[d]}ai install codex${_AI[r]}\n"
  (( example_count == 0 )) && printf "    ${_AI[d]}ai -h${_AI[r]}\n"

  printf "\n"
  printf "  ${_AI[b]}HELPER NOTES${_AI[r]}\n"
  printf "    Repo: ${_AI[cyan]}https://github.com/ivankristianto/zsh${_AI[r]}\n"
  printf "    Installer: ${_AI[d]}ai install claude|codex|gemini|ollama|copilot|opencode${_AI[r]}\n"

  printf "\n"
  printf "  ${_AI[b]}STATUS${_AI[r]}\n"
  _ai_help_status_row "$(_ai_check_cmd claude)" "claude (cli)" "$(_ai_check_cmd codex)" "codex (cli)"
  _ai_help_status_row "$(_ai_check_cmd gemini)" "gemini (cli)" "$(_ai_check_cmd copilot)" "copilot (cli)"
  _ai_help_status_row "$(_ai_check_cmd opencode)" "opencode (cli)" "$(_ai_check_ollama)" "ollama (localhost)"
  _ai_help_status_row "$(_ai_check GLM_API_KEY)" "GLM_API_KEY" "$(_ai_check KIMI_API_KEY)" "KIMI_API_KEY"
  _ai_help_status_row "$(_ai_check MINIMAX_API_KEY)" "MINIMAX_API_KEY" "$(_ai_check OPENROUTER_API_KEY)" "OPENROUTER_API_KEY"
  _ai_help_status_row "$(_ai_check OPENAI_API_KEY)" "OPENAI_API_KEY" "$(_ai_check GEMINI_API_KEY)" "GEMINI_API_KEY"
  printf "\n"
}
