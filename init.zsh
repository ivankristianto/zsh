# Single entry point for ~/.zsh config
# Usage in .zshrc: source ~/.zsh/init.zsh

export ZSH="${0:A:h}"

_zsh_load() {
  local file="$1"
  if [[ -r "$ZSH/$file" ]]; then
    source "$ZSH/$file" || echo "Warning: failed to load $file" >&2
  else
    echo "Warning: $file not found" >&2
  fi
}

_zsh_load "settings.zsh"
_zsh_load "keys.zsh"
_zsh_load "themes/.zsh_theme"
_zsh_load "functions/ai_functions.zsh"
_zsh_load "functions/functions.zsh"
_zsh_load "plugins/plugins.zsh"

unset -f _zsh_load
