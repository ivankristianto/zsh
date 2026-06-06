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

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# uv
[ -s "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Keep syntax highlighting late in init order.
if [[ -r "$ZSH/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$ZSH/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
