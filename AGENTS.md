# AGENTS.md

## Scope
This repository contains zsh runtime configuration.

## Secrets Policy
- Store all secret values only in `.env`.
- Load secrets through `keys.sh`.
- Never commit real keys or tokens.

## Startup Entry Point
- `init.zsh` is the single entry point.
- Keep imports in `init.zsh` explicit and ordered.

## Validation
After editing key-related files, verify with:
`zsh -lc 'source /Users/ivan/.zsh/keys.sh'`
