# Single entry point for ~/.zsh config
# Usage in .zshrc: source ~/.zsh/init.zsh

export ZSH="${0:A:h}"

source "$ZSH/settings.zsh"
source "$ZSH/keys.sh"
source "$ZSH/themes/.zsh_theme"
source "$ZSH/functions/ai_functions.zsh"
source "$ZSH/functions/functions.zsh"
source "$ZSH/plugins/plugins.zsh"
