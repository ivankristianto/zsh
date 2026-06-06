# ZSH Settings

# Homebrew
export PATH="/opt/homebrew/bin:$PATH"
HISTSIZE=20000
HISTFILE=~/.zsh_history
SAVEHIST=20000
setopt sharehistory
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Modern CLI aliases
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first'
  alias ll='eza -la --icons --git --group-directories-first --time-style=relative --no-user'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
fi

# Locale
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
