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
- [Functions Reference](#functions-reference)
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
git clone git@github.com:ivankristianto/zsh.git ~/.zsh
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

## Functions Reference

Both files are auto-loaded from `init.zsh`:

- `functions/ai_functions.zsh`
- `functions/functions.zsh`

### AI Functions (`functions/ai_functions.zsh`)

Primary command:

```zsh
ai [command] [args...]
```

| Command   | Alias | Purpose                                          | Example                                                        |
| --------- | ----- | ------------------------------------------------ | -------------------------------------------------------------- |
| `ai`      | -     | Open interactive `fzf` provider picker           | `ai`                                                           |
| `sonnet`  | `s`   | Run Claude Sonnet                                | `ai sonnet "review this"`                                      |
| `haiku`   | `h`   | Run Claude Haiku                                 | `ai haiku "summarize"`                                         |
| `opus`    | `o`   | Run Claude Opus                                  | `ai opus "deep analysis"`                                      |
| `glm`     | `g`   | Run GLM provider via Z.ai endpoint               | `ai glm "hello"`                                               |
| `mini`    | `m`   | Run MiniMax provider                             | `ai mini "hello"`                                              |
| `or`      | -     | Run OpenRouter provider (`--model` supported)    | `ai or --model anthropic/claude-opus-4 "check"`                |
| `ol`      | -     | Run Ollama provider (`--model` supported)        | `ai ol --model llama3.2 "quick task"`                          |
| `codex`   | `c`   | Run OpenAI Codex CLI                             | `ai codex`                                                     |
| `gemini`  | `ge`  | Run Gemini CLI in yolo mode                      | `ai gemini`                                                    |
| `copilot` | `cp`  | Run GitHub Copilot CLI                           | `ai copilot`                                                   |
| `oc`      | -     | Run OpenCode build agent (`--model`, `--review`) | `ai oc --review`                                               |
| `custom`  | `cu`  | Run custom Anthropic-compatible endpoint         | `ai custom --model gpt-4o --endpoint https://... --apikey ...` |
| `last`    | `l`   | Re-run last selected provider                    | `ai last`                                                      |
| `help`    | `-h`  | Show built-in help and status                    | `ai help`                                                      |

Required tooling/env depends on command:

- `claude` for Anthropic-compatible routes (`sonnet/haiku/opus/glm/mini/or/ol/custom`)
- `codex` + `OPENAI_API_KEY` for `ai codex`
- `gemini` + `GEMINI_API_KEY` for `ai gemini`
- `copilot` for `ai copilot`
- `opencode` for `ai oc`
- `fzf` for interactive picker mode (`ai` with no subcommand)

### General Functions (`functions/functions.zsh`)

| Function    | Purpose                                                                 | Example               |
| ----------- | ----------------------------------------------------------------------- | --------------------- |
| `tt`        | Send Telegram message using `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` | `tt -m "deploy done"` |
| `k2-dev`    | Shortcut SSH/orb connect helper for `k2-dev`                            | `k2-dev`              |
| `switchphp` | Switch linked Homebrew PHP version                                      | `switchphp 8.3`       |
| `up`        | Run daily software refresh (`brew upgrade`, `brew cleanup`, npm globals, Node LTS) | `up`                  |

Daily update command details:

```zsh
up
```

`up` executes:

- `brew upgrade`
- `brew cleanup`
- `npm install -g @google/gemini-cli @openai/codex @github/copilot`
- `nvm install --lts` (when `nvm` is available)

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

### CLI Tools

| Tool             | Purpose                                             | Repo                                  | Install                |
| ---------------- | --------------------------------------------------- | ------------------------------------- | ---------------------- |
| `fzf`            | Fuzzy finder for files/history/processes            | https://github.com/junegunn/fzf       | `brew install fzf`     |
| `zoxide`         | Smarter `cd` that learns frequent paths             | https://github.com/ajeetdsouza/zoxide | `brew install zoxide`  |
| `eza`            | Modern `ls` replacement with icons and git metadata | https://github.com/eza-community/eza  | `brew install eza`     |
| `bat`            | Syntax-highlighted `cat` with pager integration     | https://github.com/sharkdp/bat        | `brew install bat`     |
| `fd`             | Fast and simple alternative to `find`               | https://github.com/sharkdp/fd         | `brew install fd`      |
| `ripgrep` (`rg`) | Fast recursive text search                          | https://github.com/BurntSushi/ripgrep | `brew install ripgrep` |

Usage examples:

```zsh
# fzf: fuzzy-find files under current directory
fzf

# zoxide: jump to a frequently visited directory (configured as `cd`)
cd .zsh

# eza: long list with icons and git status
eza -la --icons --git

# bat: preview file with syntax highlighting
bat ~/.zsh/README.md

# fd: find zsh files quickly
fd '\.zsh$' ~/.zsh

# ripgrep: search text recursively
rg "SPACESHIP_HOST_SHOW" ~/.zsh
```

Note: this config initializes zoxide with `--cmd cd` in `plugins/plugins.zsh`, so use `cd` (not `z`).

Install zsh plugins used by this repo:

```zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/.zsh/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/zsh-users/zsh-completions.git ~/.zsh/plugins/zsh-completions
```

### zsh Plugins

| Plugin                    | Purpose                                       | Repo                                                 | Install Path                             |
| ------------------------- | --------------------------------------------- | ---------------------------------------------------- | ---------------------------------------- |
| `zsh-autosuggestions`     | Suggests commands based on shell history      | https://github.com/zsh-users/zsh-autosuggestions     | `~/.zsh/plugins/zsh-autosuggestions`     |
| `zsh-syntax-highlighting` | Highlights valid/invalid commands as you type | https://github.com/zsh-users/zsh-syntax-highlighting | `~/.zsh/plugins/zsh-syntax-highlighting` |
| `zsh-completions`         | Adds many extra command completions           | https://github.com/zsh-users/zsh-completions         | `~/.zsh/plugins/zsh-completions`         |

Usage examples:

- `zsh-autosuggestions`: type `git st` (after `git status` exists in history), then press Right Arrow to accept suggestion.
- `zsh-syntax-highlighting`: compare typing `ls` (valid) vs `lss` (invalid) to see different highlighting.
- `zsh-completions`: type `git ch` then press Tab to expand completion candidates.

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
