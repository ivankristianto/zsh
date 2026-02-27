# AGENTS.md

## Scope

This repository contains personal zsh runtime configuration under `/Users/ivan/.zsh`.

## Primary Goal

Keep shell startup predictable, secure, and fast while preserving current UX.

## Source Of Truth

- User-facing documentation: `README.md`
- Runtime entrypoint: `init.zsh`
- Prompt config: `themes/.zsh_theme`
- Secrets loader: `keys.sh` + `.env`

## Non-Negotiable Rules

### Secrets

- Store real secrets only in `.env`.
- Never commit `.env`.
- Keep `.env.example` as placeholders only.
- Load env vars via `keys.sh` (not inline in other files).

### Startup Structure

- `init.zsh` is the single entrypoint sourced by `~/.zshrc`.
- Keep current load order unless explicitly requested:
  1. `settings.zsh`
  2. `keys.sh`
  3. `themes/.zsh_theme`
  4. `functions/ai_functions.zsh`
  5. `functions/functions.zsh`
  6. `plugins/plugins.zsh`

### Git Boundaries

- `themes/spaceship-prompt` is an intentional git submodule; do not vendor or flatten it.
- `plugins/zsh-autosuggestions`, `plugins/zsh-completions`, and `plugins/zsh-syntax-highlighting` are local-only and ignored by git.
- Do not re-add ignored plugin directories to tracking.

### Prompt Safety

- Host section must stay disabled unless user asks otherwise.
- Time format should avoid hostname expansion (`SPACESHIP_TIME_FORMAT="%D{%H:%M}"`).

## Editing Guidelines

- Prefer small, targeted edits.
- Keep README examples executable and aligned with actual repo settings.
- Use real repo URL in setup docs: `git@github.com:ivankristianto/zsh.git`.
- If behavior changes, update both config and README in the same change.

## Verification Checklist

Run these after relevant edits:

1. Syntax:
   `zsh -n ~/.zsh/init.zsh ~/.zsh/settings.zsh ~/.zsh/keys.sh ~/.zsh/themes/.zsh_theme ~/.zsh/plugins/plugins.zsh`

2. Secrets load:
   `zsh -lc 'source ~/.zsh/keys.sh; [[ -n "$OPENAI_API_KEY" ]] && echo OK || echo MISSING'`

3. Prompt config state:
   `zsh -lic 'print -r -- "HOST_SHOW=$SPACESHIP_HOST_SHOW TIME_FORMAT=$SPACESHIP_TIME_FORMAT"'`

4. Git hygiene:

- Confirm `.env` is not tracked.
- Confirm ignored plugin directories are not tracked.

## Commit Guidance

- Use clear, scoped commit messages (`docs:`, `chore:`, etc.).
- Do not commit unrelated generated files.
- Push to `origin/main` unless the user asks for a different flow.
