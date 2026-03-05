# AI CLI loader
# Keeps init.zsh load order stable while splitting implementation into modules.

typeset -g _AI_MODULE_DIR="${${(%):-%N}:A:h}/ai"

for _ai_file in \
  core.zsh \
  providers/claude.zsh \
  providers/ollama.zsh \
  providers/llamacpp.zsh \
  providers/codex.zsh \
  providers/gemini.zsh \
  providers/copilot.zsh \
  providers/opencode.zsh \
  ship.zsh \
  install.zsh \
  help.zsh \
  picker.zsh \
  ai.zsh \
  completion.zsh
  do
  if [[ -r "$_AI_MODULE_DIR/$_ai_file" ]]; then
    source "$_AI_MODULE_DIR/$_ai_file" || printf "Warning: failed to load functions/ai/%s\n" "$_ai_file" >&2
  else
    printf "Warning: missing functions/ai/%s\n" "$_ai_file" >&2
  fi
done

unset _AI_MODULE_DIR
unset _ai_file
