# Optional local plugins and CLI integrations.
# Each block is guarded so startup does not fail if a tool/plugin is missing.

if [[ -r "$ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [[ -r "$ZSH/plugins/zsh-completions/zsh-completions.plugin.zsh" ]]; then
  source "$ZSH/plugins/zsh-completions/zsh-completions.plugin.zsh"
fi

if [[ -r "$HOME/.fzf.zsh" ]]; then
  source "$HOME/.fzf.zsh"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi

# Keep syntax highlighting late in init order.
if [[ -r "$ZSH/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
