# AGENTS.md

## Scope

This repository contains personal zsh runtime configuration under `/Users/ivan/.zsh`.

## Primary Goal

Keep shell startup predictable, secure, and fast while preserving current UX.

## Source Of Truth

- User-facing documentation: `README.md`
- Runtime entrypoint: `init.zsh`
- Prompt config: `themes/.zsh_theme`
- Secrets loader: `keys.zsh` + `.env`

## Non-Negotiable Rules

### Secrets

- Store real secrets only in `.env`.
- Never commit `.env`.
- Keep `.env.example` as placeholders only.
- Load env vars via `keys.zsh` (not inline in other files).

### Startup Structure

- `init.zsh` is the single entrypoint sourced by `~/.zshrc`.
- Keep current load order unless explicitly requested:
  1. `settings.zsh`
  2. `keys.zsh`
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

### AI Provider Isolation

- Do not export provider-specific runtime auth/base vars globally when they can affect other agents.
- `llama.cpp` must hardcode its local Anthropic-compatible runtime values inside provider execution only.
- Do not add `ANTHROPIC_BASE_URL` / `ANTHROPIC_API_KEY` to `keys.zsh`, `.env.example`, or global help/status for `llama.cpp`.

## Editing Guidelines

- Prefer small, targeted edits.
- Keep README examples executable and aligned with actual repo settings.
- Use real repo URL in setup docs: `git@github.com:ivankristianto/zsh.git`.
- If behavior changes, update both config and README in the same change.

## Dev Notes: Adding A New Coding Agent

When adding a new `ai` agent, keep the modular layout and domain split:

1. Add/extend provider implementation in `functions/ai/providers/*.zsh`.
2. Register command routing in `functions/ai/ai.zsh`.
3. Update command visibility in `functions/ai/help.zsh` and picker rows in `functions/ai/picker.zsh`.
4. Update completion entries in `functions/ai/completion.zsh`.
5. If installable, map npm package in `functions/ai/install.zsh` (`ai install <agent>`).
6. Keep `functions/ai_functions.zsh` as loader only; do not move runtime logic back into a monolith.
7. Update `README.md` AI command table/examples in the same change.
8. Keep helper notes link current: `https://github.com/ivankristianto/zsh`.
9. Keep provider runtime config scoped per provider; avoid global env exports that can leak across agents.

## Verification Checklist

Run these after relevant edits:

1. Syntax:
   `zsh -n ~/.zsh/init.zsh ~/.zsh/settings.zsh ~/.zsh/keys.zsh ~/.zsh/themes/.zsh_theme ~/.zsh/plugins/plugins.zsh ~/.zsh/functions/ai_functions.zsh ~/.zsh/functions/ai/*.zsh ~/.zsh/functions/ai/providers/*.zsh`

2. Secrets load:
   `zsh -lc 'source ~/.zsh/keys.zsh; [[ -n "$OPENAI_API_KEY" ]] && echo OK || echo MISSING'`

3. Prompt config state:
   `zsh -lic 'print -r -- "HOST_SHOW=$SPACESHIP_HOST_SHOW TIME_FORMAT=$SPACESHIP_TIME_FORMAT"'`

4. AI tests:
   `zsh ~/.zsh/tests/ai_functions_test.zsh`

5. Git hygiene:

- Confirm `.env` is not tracked.
- Confirm ignored plugin directories are not tracked.

## Commit Guidance

- Use clear, scoped commit messages (`docs:`, `chore:`, etc.).
- Do not commit unrelated generated files.
- Push to `origin/main` unless the user asks for a different flow.
