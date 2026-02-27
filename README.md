# zsh Config

Personal zsh setup with:

- a single entrypoint (`init.zsh`)
- local secret loading from `.env`
- Spaceship prompt customization
- optional productivity plugins and CLI integrations

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Setup (Fresh Machine)](#setup-fresh-machine)
- [Update (Existing Install)](#update-existing-install)
- [Configuration Load Order](#configuration-load-order)
- [Repository Layout](#repository-layout)
- [Secrets Management](#secrets-management)
- [DevX Bootstrap](#devx-bootstrap)
- [Spaceship Prompt Notes](#spaceship-prompt-notes)
- [Customization Examples](#customization-examples)
- [Verification Commands](#verification-commands)
- [Troubleshooting](#troubleshooting)

## Overview

This repo manages shell behavior through one entrypoint:

```zsh
source ~/.zsh/init.zsh
```

`init.zsh` then loads settings, keys, prompt, functions, and plugins in a predictable order.

## Prerequisites

- macOS or Linux with `zsh`
- `git`
- Homebrew (recommended on macOS for tool installation)

## Setup (Fresh Machine)

1. Clone repo:

```zsh
git clone <your-repo-url> ~/.zsh
cd ~/.zsh
```

2. Initialize submodules (required for Spaceship prompt):

```zsh
git submodule update --init --recursive
```

3. Create your local secrets file:

```zsh
cp .env.example .env
```

4. Add entrypoint to `~/.zshrc`:

```zsh
source ~/.zsh/init.zsh
```

5. Reload shell:

```zsh
exec zsh
```

## Update (Existing Install)

From `~/.zsh`:

```zsh
git pull
git submodule update --init --recursive --remote
exec zsh
```

## Configuration Load Order

`init.zsh` loads files in this order:

1. `settings.zsh`
2. `keys.sh`
3. `themes/.zsh_theme`
4. `functions/ai_functions.zsh`
5. `functions/functions.zsh`
6. `plugins/plugins.zsh`

This order is intentional:

- secrets are available before function/theme usage
- prompt is configured before interactive usage
- syntax-highlighting plugin is loaded near the end

## Repository Layout

- `init.zsh`: single entrypoint
- `settings.zsh`: shell history and zsh options
- `keys.sh`: loads variables from `.env` and exports compatibility vars
- `.env.example`: tracked template for required env variable names
- `functions/`: custom shell functions
- `themes/.zsh_theme`: Spaceship prompt config
- `themes/spaceship-prompt/`: Spaceship git submodule
- `plugins/plugins.zsh`: optional plugin/tool loader (safe guards if missing)

## Secrets Management

Rules:

- store real tokens only in `.env`
- never commit `.env`
- commit only `.env.example`

`.env` is ignored by git via `.gitignore`.

Minimal example:

```env
OPENAI_API_KEY="your-openai-api-key"
OPENROUTER_API_KEY="your-openrouter-api-key"
```

## DevX Bootstrap

Install core tools:

```zsh
brew install fzf zoxide eza bat fd ripgrep
$(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc
```

Tool purpose + repo:

- `fzf`: fuzzy finder for files/history/processes  
  https://github.com/junegunn/fzf
- `zoxide`: smarter `cd` that learns frequent paths  
  https://github.com/ajeetdsouza/zoxide
- `eza`: modern `ls` replacement with icons/git metadata  
  https://github.com/eza-community/eza
- `bat`: syntax-highlighted `cat` with pager integration  
  https://github.com/sharkdp/bat
- `fd`: simpler, fast alternative to `find`  
  https://github.com/sharkdp/fd
- `ripgrep` (`rg`): fast recursive text search  
  https://github.com/BurntSushi/ripgrep

Install zsh plugins used by this repo:

```zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/zsh-users/zsh-completions.git ~/.zsh/plugins/zsh-completions
```

Optional aliases:

```zsh
alias ls='eza --group-directories-first'
alias ll='eza -la --icons --git'
alias cat='bat'
```

## Spaceship Prompt Notes

Configured in `themes/.zsh_theme`.

Current default prompt order:

- `dir`
- `git`
- `node`
- `php`
- `exec_time`
- `time`
- `line_sep`
- `jobs`
- `exit_code`
- `char`

Important behavior:

- host section is disabled (`SPACESHIP_HOST_SHOW=false`)
- time uses `SPACESHIP_TIME_FORMAT="%D{%H:%M}"`  
  This avoids `%M` hostname expansion side effects.

## Customization Examples

Hide Node and PHP sections:

```zsh
SPACESHIP_NODE_SHOW=false
SPACESHIP_PHP_SHOW=false
```

Remove `at ` before time:

```zsh
SPACESHIP_TIME_PREFIX=""
```

Disable time completely:

```zsh
SPACESHIP_TIME_SHOW=false
```

Show username always:

```zsh
SPACESHIP_USER_SHOW=always
```

## Verification Commands

Validate zsh syntax:

```zsh
zsh -n ~/.zsh/init.zsh ~/.zsh/settings.zsh ~/.zsh/keys.sh ~/.zsh/themes/.zsh_theme ~/.zsh/plugins/plugins.zsh
```

Verify secrets load:

```zsh
zsh -lc 'source ~/.zsh/keys.sh; [[ -n "$OPENAI_API_KEY" ]] && echo OK || echo MISSING'
```

Check current Spaceship values:

```zsh
zsh -lic 'print -r -- "HOST_SHOW=$SPACESHIP_HOST_SHOW TIME_FORMAT=$SPACESHIP_TIME_FORMAT"'
```

## Troubleshooting

Prompt still shows hostname-like output at the end:

- check `SPACESHIP_TIME_FORMAT` first; `%M` inside prompt context can render hostname
- recommended value: `SPACESHIP_TIME_FORMAT="%D{%H:%M}"`
- reload shell: `exec zsh`

Plugins not loading:

- ensure plugin dirs exist under `~/.zsh/plugins`
- plugin loader is guarded; missing plugins do not crash startup

Submodule missing after clone:

- run `git submodule update --init --recursive`

Secrets not available in commands:

- confirm `.env` exists and contains valid `KEY="value"` lines
- run `source ~/.zsh/keys.sh`
- verify with `printenv | rg 'OPENAI_API_KEY|OPENROUTER_API_KEY'`
