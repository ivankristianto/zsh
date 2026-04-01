# zsh Config Improvements — Design Spec

**Date:** 2026-04-01
**Scope:** Five improvements to the `~/.zsh` personal config repo

---

## Overview

Five targeted improvements across the `ai` CLI subsystem and general shell utilities:

1. Provider config refactor — replace fragile pipe-delimited strings with named associative arrays and deduplicate shared env-setup logic
2. `ai bench` — run a prompt across multiple providers sequentially with timing
3. `ai context` — dump git/directory context as markdown for AI paste-in
4. `up` self-update — always pull `~/.zsh` itself as the first step
5. `zload` profiling shim — quick startup performance report

Items 1–3 touch `functions/ai/`. Items 4–5 touch `functions/functions.zsh`. All changes are additive or internal refactors with no UX regression.

---

## 1. Provider Config Refactor

### Problem

`_AI_PROVIDERS` in `providers/claude.zsh` encodes each provider as a 9-field pipe-delimited string:

```zsh
[glm]="GLM_API_KEY|https://api.z.ai/api/anthropic|glm-5.1|glm-5.1|glm-5.1|glm-5.1|byel|GLM|0"
```

Adding or reordering a field requires touching every provider string and every parse site. A wrong field count fails silently.

Additionally, `_ai_run_provider` in `claude.zsh` and `_ai_run_provider_ship` in `ship.zsh` duplicate ~40 lines of identical token validation and env-var setup.

### Design

**Data layer:** Replace `_AI_PROVIDERS` with per-provider named associative arrays using the `_AI_P_<key>` convention, defined in `providers/claude.zsh`:

```zsh
typeset -gA _AI_P_glm=(
  [env]="GLM_API_KEY"
  [url]="https://api.z.ai/api/anthropic"
  [model]="glm-5.1"
  [haiku]="glm-5.1"
  [sonnet]="glm-5.1"
  [opus]="glm-5.1"
  [color]="byel"
  [label]="GLM"
  [model_flag]="0"
)
```

Fields defined for every provider: `env`, `url`, `model`, `haiku`, `sonnet`, `opus`, `color`, `label`, `model_flag`.

Special `env` values `_OLLAMA` and `_LLAMACPP` retain their existing semantics for local providers.

**Lookup helper** in `core.zsh`:

```zsh
_ai_pget() {
  local key="$1" field="$2"
  local -n _ref="_AI_P_${key}"
  print -- "${_ref[$field]}"
}
```

Adding a new field in future: one line per provider declaration, no parser changes.

**Deduplication:** Extract `_ai_provider_run <key> [cmd...]` to `core.zsh`. It validates the token (handling `_OLLAMA`/`_LLAMACPP` special cases), then executes `cmd` inside a subshell with the provider env vars set:

```zsh
_ai_provider_run() {
  local key="$1"; shift
  # ... validate token, resolve model ...
  (
    ANTHROPIC_AUTH_TOKEN="$token"
    ANTHROPIC_BASE_URL="$base_url"
    ANTHROPIC_API_KEY="$api_key"
    API_TIMEOUT_MS=3000000
    ANTHROPIC_MODEL="$model"
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku"
    ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet"
    ANTHROPIC_DEFAULT_OPUS_MODEL="$opus"
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
    export ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_API_KEY \
           API_TIMEOUT_MS ANTHROPIC_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
           ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL \
           CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
    "$@"
  )
}
```

The subshell ensures env vars never leak to the calling shell — satisfying the AGENTS.md constraint against global provider env exports. `_ai_run_provider` becomes `_ai_provider_run "$key" claude "${cmd_args[@]}" "$@"`. `_ai_run_provider_ship` becomes `_ai_provider_run "$key" claude --dangerously-skip-permissions --system-prompt "$_AI_SHIP_PROMPT" "..."`. No behavior change.

**Affected files:** `providers/claude.zsh`, `ship.zsh`, `core.zsh`

**Providers covered:** `glm`, `kimi`, `mini`, `or` (OpenRouter), `ol` (Ollama), `lc` (llama.cpp)

---

## 2. `ai bench`

### Design

**New file:** `functions/ai/bench.zsh`

**Usage:**

```zsh
ai bench "what is 2+2" sonnet glm kimi
```

**Behavior:**

1. Require at least one prompt argument and one provider
2. For each named provider:
   - Check availability via `_ai_cmd_available`; skip with warning if unavailable
   - Reject non-Claude-backed providers (`codex`, `gemini`, `copilot`, `opencode`) with a clear error — these do not accept a bare prompt non-interactively
   - Print header: `▶ [N/total] <provider>`
   - Record start time via `$SECONDS`
   - Run the provider with the prompt as a positional arg
   - Print elapsed: `✓ <provider>  Xs`
3. Output is sequential and linear — providers run one at a time, results appear inline

**Error handling:**
- Zero available providers after filtering → exit 1 with message
- Individual provider failure → print warning, continue to next

**Routing updates:**
- `ai.zsh`: add `bench|b) _ai_bench "$@" ;;` case
- `help.zsh`: add one row under UTILITIES: `bench  b  Run prompt across providers`
- `completion.zsh`: add `'bench:Run prompt across providers'` and `'b:Run prompt across providers'`
- `ai_functions.zsh`: add `bench.zsh` to load list

---

## 3. `ai context`

### Design

**New file:** `functions/ai/context.zsh`

**Usage:**

```zsh
ai context           # print to stdout
ai context --copy    # also copy to clipboard
```

**Output format** (markdown, no ANSI):

```markdown
# Context

## Directory
/path/to/project

## File Tree
(2-level depth; uses fd if available, falls back to find)

## Git Branch
main

## Git Status
M  src/foo.zsh

## Recent Commits
a1b2c3 feat: add bench command
...
```

**Behavior:**
- Git sections skipped gracefully when not in a git repo
- File tree respects `.gitignore` when `fd` is available (`fd --max-depth 2`); falls back to `find . -maxdepth 2 -not -path './.git*'`
- `--copy` detects OS: uses `pbcopy` on macOS, `xclip -selection clipboard` on Linux; warns if neither available
- No colors in output — plain markdown safe for any AI chat paste

**Routing updates:**
- `ai.zsh`: add `context|ctx) _ai_context "$@" ;;` case
- `help.zsh`: add one row under UTILITIES: `context  ctx  Dump project context as markdown`
- `completion.zsh`: add `'context:Dump project context'` and `'ctx:Dump project context'`
- `ai_functions.zsh`: add `context.zsh` to load list

---

## 4. `up` Self-Update

### Design

**File:** `functions/functions.zsh`

Add as the first step inside `up()`, before the existing git-repo block:

```zsh
echo "==> ~/.zsh update"
git -C "$HOME/.zsh" pull --ff-only || echo "    ⚠ ~/.zsh pull failed (continuing)" >&2
```

Uses `git -C` to avoid changing the working directory. The existing git-repo block remains unchanged — it handles whatever project the user is currently in. These are separate concerns: config repo (always) vs. current project (context-aware).

---

## 5. `zload` Profiling Shim

### Design

**File:** `functions/functions.zsh`

New function alongside `up`, `tt`, `switchphp`:

```zsh
zload() {
  local n="${1:-20}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  printf 'zmodload zsh/zprof\nsource "$HOME/.zshrc"\nzprof\n' > "$tmpdir/.zshrc"
  ZDOTDIR="$tmpdir" zsh -i 2>/dev/null | head -"$n"
  rm -rf "$tmpdir"
}
```

Uses `ZDOTDIR` to inject a wrapper `.zshrc` that loads `zsh/zprof` **before** sourcing the real `~/.zshrc`, ensuring all init files are profiled. The temp dir is cleaned up after.

**Usage:**

```zsh
zload       # top 20 slow contributors
zload 40    # top 40
```

Output is zprof's native format, already sorted by total time descending. No external dependencies.

---

## Architecture Summary

| Item | Files changed | New files |
|------|--------------|-----------|
| #1 Provider refactor | `core.zsh`, `providers/claude.zsh`, `ship.zsh` | — |
| #2 `ai bench` | `ai.zsh`, `help.zsh`, `completion.zsh`, `ai_functions.zsh` | `bench.zsh` |
| #3 `ai context` | `ai.zsh`, `help.zsh`, `completion.zsh`, `ai_functions.zsh` | `context.zsh` |
| #4 `up` fix | `functions/functions.zsh` | — |
| #5 `zload` | `functions/functions.zsh` | — |

## Testing

Extend `tests/ai_functions_test.zsh`:

- Provider config: assert `_ai_pget glm env` returns `GLM_API_KEY`; assert `_ai_pget ol env` returns `_OLLAMA`
- Deduplication: assert `_ai_provider_setup_env` is callable and sets expected env vars given a provider key
- `ai bench`: assert it rejects unknown providers, skips unavailable ones with warning, accepts valid Claude-backed providers
- `ai context`: assert output contains `# Context` header; assert `--copy` flag path is exercised without error (dry-run with a mock pbcopy)
- `up`: no test change needed — the new step is a side-effectful shell command; verify manually
- `zload`: no automated test — verify manually with `zload 5`

## Implementation Order

1. Provider config refactor (#1) — foundation; everything else is easier after this
2. `up` fix (#4) and `zload` (#5) — independent, can go in same commit
3. `ai bench` (#2) — new file, builds on clean provider config
4. `ai context` (#3) — new file, fully independent

