# zsh Config Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the `ai` provider config from fragile pipe-delimited strings to named associative arrays, deduplicate shared env-setup logic, add `ai bench` and `ai context` commands, fix `up` to always self-update `~/.zsh`, and add a `zload` startup profiler.

**Architecture:** Data layer moves from one `_AI_PROVIDERS` array (pipe-encoded strings) to per-provider `_AI_P_<key>` associative arrays with a `_ai_pget` lookup helper and a `_ai_provider_exec` shared executor. New commands `bench` and `context` are each isolated in their own file. `up` and `zload` are plain additions to `functions/functions.zsh`.

**Tech Stack:** zsh 5.9 (macOS default), existing stub-based test framework in `tests/ai_functions_test.zsh`, no external test runner.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `functions/ai/core.zsh` | Add `_ai_pget`, `_ai_provider_exec` |
| Modify | `functions/ai/providers/claude.zsh` | Replace `_AI_PROVIDERS` with `_AI_P_*` arrays; simplify `_ai_run_provider` |
| Modify | `functions/ai/ship.zsh` | Simplify `_ai_run_provider_ship` to use `_ai_provider_exec` |
| Create | `functions/ai/bench.zsh` | `_ai_bench` implementation |
| Create | `functions/ai/context.zsh` | `_ai_context` implementation |
| Modify | `functions/ai/ai.zsh` | Route `bench` and `context` |
| Modify | `functions/ai/help.zsh` | Add bench/context rows |
| Modify | `functions/ai/completion.zsh` | Add bench/context completions |
| Modify | `functions/ai/ai_functions.zsh` | Add bench.zsh, context.zsh to load list |
| Modify | `functions/functions.zsh` | Add `~/.zsh` pull to `up`; add `zload` |
| Modify | `tests/ai_functions_test.zsh` | Extend with new assertions |

---

## Task 1: Provider data layer — `_ai_pget` + per-provider assoc arrays

**Files:**
- Modify: `functions/ai/core.zsh` (append after line 122)
- Modify: `functions/ai/providers/claude.zsh` (full replacement)
- Modify: `tests/ai_functions_test.zsh` (append before the final `print PASS` line)

- [ ] **Step 1: Write the failing tests**

Append these assertions to `tests/ai_functions_test.zsh`, before the final `print -r -- "PASS: ai functions tests"` line:

```zsh
# _ai_pget: data layer
pget_env="$(_ai_pget glm env)"
if [[ "$pget_env" != "GLM_API_KEY" ]]; then
  print -r -- "FAIL: _ai_pget glm env expected GLM_API_KEY, got $pget_env"
  exit 1
fi

pget_url="$(_ai_pget kimi url)"
if [[ "$pget_url" != "https://api.kimi.com/coding/" ]]; then
  print -r -- "FAIL: _ai_pget kimi url expected https://api.kimi.com/coding/, got $pget_url"
  exit 1
fi

pget_ol="$(_ai_pget ol env)"
if [[ "$pget_ol" != "_OLLAMA" ]]; then
  print -r -- "FAIL: _ai_pget ol env expected _OLLAMA, got $pget_ol"
  exit 1
fi

pget_lc="$(_ai_pget lc env)"
if [[ "$pget_lc" != "_LLAMACPP" ]]; then
  print -r -- "FAIL: _ai_pget lc env expected _LLAMACPP, got $pget_lc"
  exit 1
fi

if _ai_pget nonexistent env >/dev/null 2>&1; then
  print -r -- "FAIL: _ai_pget nonexistent should return non-zero"
  exit 1
fi

pget_color="$(_ai_pget or color)"
if [[ "$pget_color" != "bgreen" ]]; then
  print -r -- "FAIL: _ai_pget or color expected bgreen, got $pget_color"
  exit 1
fi
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: FAIL with `_ai_pget glm env expected GLM_API_KEY` (function does not exist yet).

- [ ] **Step 3: Add `_ai_pget` to `core.zsh`**

Append to the end of `functions/ai/core.zsh`:

```zsh
# Provider config lookup. Returns the value of field for provider key.
# Returns non-zero if the provider key is not registered.
_ai_pget() {
  local key="$1" field="$2"
  local varname="_AI_P_${key}"
  (( ${(P)+varname} )) || return 1
  local -n _pget_ref="$varname"
  print -- "${_pget_ref[$field]:-}"
}
```

- [ ] **Step 4: Replace `providers/claude.zsh` with per-provider assoc arrays**

Full replacement of `functions/ai/providers/claude.zsh`. The file has two sections: the provider data declarations, then the `_ai_run_provider` and `_ai_run_custom` functions.

```zsh
# Claude-based providers (Anthropic-compatible endpoints)
# Each provider is a named associative array _AI_P_<key>.
# Fields: env, url, model, haiku, sonnet, opus, color, label, model_flag
# Special env values: _OLLAMA (local ollama), _LLAMACPP (local llama.cpp)

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

typeset -gA _AI_P_kimi=(
  [env]="KIMI_API_KEY"
  [url]="https://api.kimi.com/coding/"
  [model]="kimi-k2.5"
  [haiku]="kimi-k2.5"
  [sonnet]="kimi-k2.5"
  [opus]="kimi-k2.5"
  [color]="mag"
  [label]="Kimi"
  [model_flag]="0"
)

typeset -gA _AI_P_mini=(
  [env]="MINIMAX_API_KEY"
  [url]="https://api.minimax.io/anthropic"
  [model]="MiniMax-M2.1"
  [haiku]="MiniMax-M2.1"
  [sonnet]="MiniMax-M2.1"
  [opus]="MiniMax-M2.1"
  [color]="bmag"
  [label]="MiniMax"
  [model_flag]="0"
)

typeset -gA _AI_P_or=(
  [env]="OPENROUTER_API_KEY"
  [url]="https://openrouter.ai/api"
  [model]="anthropic/claude-sonnet-4"
  [haiku]="anthropic/claude-sonnet-4"
  [sonnet]="anthropic/claude-sonnet-4"
  [opus]="anthropic/claude-sonnet-4"
  [color]="bgreen"
  [label]="OpenRouter"
  [model_flag]="1"
)

typeset -gA _AI_P_ol=(
  [env]="_OLLAMA"
  [url]="http://localhost:11434"
  [model]="glm-5:cloud"
  [haiku]="glm-5:cloud"
  [sonnet]="glm-5:cloud"
  [opus]="glm-5:cloud"
  [color]="blue"
  [label]="Ollama"
  [model_flag]="1"
)

typeset -gA _AI_P_lc=(
  [env]="_LLAMACPP"
  [url]="http://localhost:8001"
  [model]="llama.cpp"
  [haiku]="llama.cpp"
  [sonnet]="llama.cpp"
  [opus]="llama.cpp"
  [color]="green"
  [label]="llama.cpp"
  [model_flag]="1"
)

_ai_run_provider() {
  local key="$1"
  shift

  local varname="_AI_P_${key}"
  (( ${(P)+varname} )) || {
    printf "${_AI[red]}✗ Unknown provider: %s${_AI[r]}\n" "$key"
    return 1
  }

  _ai_require_cmd claude || return 1

  local color label model_flag model
  color="$(_ai_pget "$key" color)"
  label="$(_ai_pget "$key" label)"
  model_flag="$(_ai_pget "$key" model_flag)"
  model="$(_ai_pget "$key" model)"

  local final_model="$model"
  local args=()
  if [[ "$model_flag" == "1" ]]; then
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--model" && -n "${2-}" ]]; then
        final_model="$2"
        shift 2
      else
        args+=("$1")
        shift
      fi
    done
    set -- "${args[@]}"
  fi

  printf "${_AI[$color]}▶${_AI[r]} %s ${_AI[b]}%s${_AI[r]}\n" "$label" "$final_model"
  _ai_save_last "$key"

  local cmd_args=(--dangerously-skip-permissions)
  [[ "$model_flag" == "1" ]] && cmd_args+=(--model "$final_model")

  _ai_provider_exec "$key" "$final_model" "${cmd_args[@]}" "$@"
}

_ai_run_custom() {
  _ai_require_cmd claude || return 1

  local model="" endpoint="" apikey="" apikey_env=""
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model)
        _ai_require_flag_value "--model" "${2-}" || return 1
        model="$2"
        shift 2
        ;;
      --endpoint)
        _ai_require_flag_value "--endpoint" "${2-}" || return 1
        endpoint="$2"
        shift 2
        ;;
      --apikey)
        _ai_require_flag_value "--apikey" "${2-}" || return 1
        apikey="$2"
        shift 2
        ;;
      --apikey-env)
        _ai_require_flag_value "--apikey-env" "${2-}" || return 1
        apikey_env="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$apikey" && -n "$apikey_env" ]]; then
    apikey="${(P)apikey_env}"
  fi

  [[ -z "$model" ]] && { printf "${_AI[red]}✗ --model required${_AI[r]}\n"; return 1; }
  [[ -z "$endpoint" ]] && { printf "${_AI[red]}✗ --endpoint required${_AI[r]}\n"; return 1; }
  [[ -z "$apikey" ]] && { printf "${_AI[red]}✗ --apikey required${_AI[r]}\n"; return 1; }

  printf "${_AI[bmag]}▶${_AI[r]} Custom ${_AI[b]}%s${_AI[r]} ${_AI[d]}@ %s${_AI[r]}\n" "$model" "$endpoint"
  typeset -g AI_CUSTOM_API_KEY_LAST="$apikey"
  _ai_save_last "custom --model $model --endpoint $endpoint --apikey-env AI_CUSTOM_API_KEY_LAST"

  ANTHROPIC_AUTH_TOKEN="$apikey" \
  ANTHROPIC_BASE_URL="$endpoint" \
  ANTHROPIC_API_KEY="" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$model" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$model" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$model" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude --dangerously-skip-permissions --model "$model" "${args[@]}"
}
```

- [ ] **Step 5: Run all tests**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: PASS (all assertions including the new `_ai_pget` ones, and all pre-existing tests).

- [ ] **Step 6: Commit**

```bash
git add functions/ai/core.zsh functions/ai/providers/claude.zsh tests/ai_functions_test.zsh
git commit -m "refactor(ai): replace pipe-delimited _AI_PROVIDERS with named assoc arrays + _ai_pget"
```

---

## Task 2: Deduplicate with `_ai_provider_exec`

**Files:**
- Modify: `functions/ai/core.zsh` (append after `_ai_pget`)
- Modify: `functions/ai/ship.zsh` (replace `_ai_run_provider_ship`)
- Modify: `tests/ai_functions_test.zsh` (append assertions)

`_ai_provider_exec` handles token validation and env-var setup for any `_AI_P_*` provider, then runs `claude` with the caller's args. It uses env-var prefix notation (not global export) so vars are scoped to the subprocess only.

- [ ] **Step 1: Write failing tests**

Append to `tests/ai_functions_test.zsh` before the final `print -r -- "PASS: ..."` line:

```zsh
# _ai_provider_exec: sets correct env vars for provider
: > "$AI_TEST_CALLS"
export GLM_API_KEY="test-glm-token"
ai glm "bench test prompt" >/dev/null 2>&1
exec_calls="$(cat "$AI_TEST_CALLS")"
assert_contains "$exec_calls" "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic" \
  "_ai_provider_exec should set GLM base URL"
assert_contains "$exec_calls" "ANTHROPIC_AUTH_TOKEN=test-glm-token" \
  "_ai_provider_exec should set GLM token"
assert_contains "$exec_calls" "ANTHROPIC_MODEL=glm-5.1" \
  "_ai_provider_exec should set ANTHROPIC_MODEL for glm"

# Missing token should fail
unset GLM_API_KEY
if ai glm "test" >/dev/null 2>&1; then
  print -r -- "FAIL: ai glm without GLM_API_KEY should fail"
  exit 1
fi
export GLM_API_KEY="test-glm-token"
```

- [ ] **Step 2: Run to verify failure**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: FAIL on the ANTHROPIC_BASE_URL assertion (function does not exist yet, so env vars are not being set correctly).

- [ ] **Step 3: Add `_ai_provider_exec` to `core.zsh`**

Append immediately after the `_ai_pget` block added in Task 1:

```zsh
# Shared provider executor: validates token, sets ANTHROPIC_* env, runs claude.
# Usage: _ai_provider_exec <key> <model_override|""> [claude_args...]
# model_override controls ANTHROPIC_MODEL; pass "" to use the provider default.
# Does NOT print a header or call _ai_save_last — callers are responsible for those.
_ai_provider_exec() {
  local key="$1"
  local override_model="${2:-}"
  shift 2

  local env_var url default_model haiku sonnet_m opus
  env_var="$(_ai_pget "$key" env)"
  url="$(_ai_pget "$key" url)"
  default_model="$(_ai_pget "$key" model)"
  haiku="$(_ai_pget "$key" haiku)"
  sonnet_m="$(_ai_pget "$key" sonnet)"
  opus="$(_ai_pget "$key" opus)"

  local model="${override_model:-$default_model}"
  local token="" api_key=""

  if [[ "$env_var" == "_OLLAMA" ]]; then
    _ai_has_ollama || {
      printf "${_AI[red]}✗ Ollama unavailable (install ollama and run server at localhost:11434)${_AI[r]}\n"
      return 1
    }
    token="ollama"
  elif [[ "$env_var" == "_LLAMACPP" ]]; then
    token="sk-no-key-required"
    api_key="sk-no-key-required"
    url="http://localhost:8001"
  else
    token="${(P)env_var}"
    [[ -z "$token" ]] && {
      printf "${_AI[red]}✗ %s not set${_AI[r]}\n" "$env_var"
      return 1
    }
  fi

  ANTHROPIC_AUTH_TOKEN="$token" \
  ANTHROPIC_BASE_URL="$url" \
  ANTHROPIC_API_KEY="$api_key" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet_m" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$opus" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude "$@"
}
```

- [ ] **Step 4: Simplify `_ai_run_provider_ship` in `ship.zsh`**

Replace the entire `_ai_run_provider_ship` function (lines 29–81 of the current file) with:

```zsh
_ai_run_provider_ship() {
  local key="$1"
  shift

  local varname="_AI_P_${key}"
  (( ${(P)+varname} )) || {
    printf "${_AI[red]}✗ Unknown provider: %s${_AI[r]}\n" "$key"
    return 1
  }

  _ai_require_cmd claude || return 1

  local color label model
  color="$(_ai_pget "$key" color)"
  label="$(_ai_pget "$key" label)"
  model="$(_ai_pget "$key" model)"

  printf "${_AI[$color]}▶${_AI[r]} %s Ship ${_AI[b]}%s${_AI[r]}\n" "$label" "$model"
  _ai_save_last "$key ship"

  _ai_provider_exec "$key" "" \
    --dangerously-skip-permissions \
    --system-prompt "$_AI_SHIP_PROMPT" \
    "Let's review and commit the changes. What's the current git status?" \
    "$@"
}
```

The `_ai_run_claude_ship` function (lines 17–27) and `_ai_run_ship` dispatcher (lines 83–111) stay unchanged.

- [ ] **Step 5: Run all tests**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: PASS — including the llama.cpp env isolation test (`_ai_provider_exec` handles the `_LLAMACPP` branch with hardcoded `http://localhost:8001` / `sk-no-key-required`).

- [ ] **Step 6: Commit**

```bash
git add functions/ai/core.zsh functions/ai/ship.zsh tests/ai_functions_test.zsh
git commit -m "refactor(ai): extract _ai_provider_exec, deduplicate provider/ship env setup"
```

---

## Task 3: `up` self-update + `zload`

**Files:**
- Modify: `functions/functions.zsh`

No automated tests — side-effectful shell commands. Verify manually.

- [ ] **Step 1: Add `~/.zsh` pull as the first step in `up()`**

In `functions/functions.zsh`, insert these two lines immediately inside `up()`, before the existing `if command -v git ...` block:

```zsh
    echo "==> ~/.zsh update"
    git -C "$HOME/.zsh" pull --ff-only || echo "    ⚠ ~/.zsh pull failed (continuing)" >&2
```

The opening of `up()` should now read:

```zsh
up() {
    echo "==> ~/.zsh update"
    git -C "$HOME/.zsh" pull --ff-only || echo "    ⚠ ~/.zsh pull failed (continuing)" >&2

    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
```

- [ ] **Step 2: Add `zload` function**

Append to the end of `functions/functions.zsh`:

```zsh
# Startup profiler. Injects zsh/zprof before .zshrc runs via ZDOTDIR wrapper.
# Usage: zload [n]   — show top n contributors by time (default: 20)
zload() {
  local n="${1:-20}"
  local tmpdir
  tmpdir="$(mktemp -d)"
  printf 'zmodload zsh/zprof\nsource "$HOME/.zshrc"\nzprof\n' > "$tmpdir/.zshrc"
  ZDOTDIR="$tmpdir" zsh -i 2>/dev/null | head -"$n"
  rm -rf "$tmpdir"
}
```

- [ ] **Step 3: Verify syntax**

```bash
zsh -n ~/.zsh/functions/functions.zsh
```

Expected: exits 0, no output.

- [ ] **Step 4: Smoke-test zload**

```bash
source ~/.zsh/functions/functions.zsh
zload 5
```

Expected: 5 lines of zprof output with function names and timing (exact content varies per machine).

- [ ] **Step 5: Commit**

```bash
git add functions/functions.zsh
git commit -m "feat(up): always pull ~/.zsh first; feat(shell): add zload startup profiler"
```

---

## Task 4: `ai bench`

**Files:**
- Create: `functions/ai/bench.zsh`
- Modify: `functions/ai/ai.zsh`
- Modify: `functions/ai/help.zsh`
- Modify: `functions/ai/completion.zsh`
- Modify: `functions/ai/ai_functions.zsh`
- Modify: `tests/ai_functions_test.zsh`

- [ ] **Step 1: Write failing tests**

Append to `tests/ai_functions_test.zsh` before the final `print -r -- "PASS: ..."` line:

```zsh
# ai bench: usage error — no providers given
if ai bench "hello" >/dev/null 2>&1; then
  print -r -- "FAIL: ai bench with no providers should fail"
  exit 1
fi

# ai bench: excluded provider emits "not supported in bench"
bench_skip_output="$(ai bench "hello" codex 2>&1)"
assert_contains "$bench_skip_output" "not supported in bench" \
  "ai bench should reject codex as non-Claude provider"

# ai bench: unknown provider emits "unavailable"
bench_unknown_output="$(ai bench "hello" unknownxyz 2>&1)"
assert_contains "$bench_unknown_output" "unavailable" \
  "ai bench should warn and skip unknown provider"

# ai bench: all providers excluded → exits non-zero
if ai bench "hello" codex gemini >/dev/null 2>&1; then
  print -r -- "FAIL: ai bench with only excluded providers should exit non-zero"
  exit 1
fi

# ai bench: runs claude-backed provider (glm)
: > "$AI_TEST_CALLS"
export GLM_API_KEY="test-glm-token"
ai bench "bench prompt" glm >/dev/null 2>&1
bench_calls="$(cat "$AI_TEST_CALLS")"
assert_contains "$bench_calls" "claude" \
  "ai bench glm should invoke the claude stub"
```

- [ ] **Step 2: Run to verify failure**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: FAIL with `ai bench with no providers should fail` (function not yet defined).

- [ ] **Step 3: Create `functions/ai/bench.zsh`**

```zsh
# ai bench — run a prompt across multiple Claude-backed providers sequentially

# Providers that cannot accept a bare prompt non-interactively
typeset -ga _AI_BENCH_EXCLUDED=(codex c gemini ge copilot cp opencode oc)

_ai_bench() {
  if [[ $# -lt 2 ]]; then
    printf "${_AI[red]}✗ Usage: ai bench <prompt> <provider> [provider...]${_AI[r]}\n"
    return 1
  fi

  local prompt="$1"
  shift

  local -a available=()
  for p in "$@"; do
    if (( ${_AI_BENCH_EXCLUDED[(Ie)$p]} )); then
      printf "${_AI[yellow]}⚠ %s: not supported in bench (non-Claude provider)${_AI[r]}\n" "$p" >&2
      continue
    fi
    if ! _ai_cmd_available "$p"; then
      printf "${_AI[yellow]}⚠ %s: unavailable, skipping${_AI[r]}\n" "$p" >&2
      continue
    fi
    available+=("$p")
  done

  if (( ${#available[@]} == 0 )); then
    printf "${_AI[red]}✗ No available Claude-backed providers to bench${_AI[r]}\n"
    return 1
  fi

  local total=${#available[@]}
  local i=1

  for p in "${available[@]}"; do
    printf "\n${_AI[bcyan]}▶ [%d/%d] %s${_AI[r]}\n" "$i" "$total" "$p"
    local start=$SECONDS

    case "$p" in
      sonnet|s)                    _ai_run_claude sonnet "$prompt" ;;
      haiku|h)                     _ai_run_claude haiku  "$prompt" ;;
      opus|o)                      _ai_run_claude opus   "$prompt" ;;
      glm|g)                       _ai_run_provider glm  "$prompt" ;;
      kimi|k)                      _ai_run_provider kimi "$prompt" ;;
      mini|m)                      _ai_run_provider mini "$prompt" ;;
      or|openrouter)               _ai_run_provider or   "$prompt" ;;
      ol|ollama)                   _ai_run_provider ol   "$prompt" ;;
      ll|llama.cpp|llamacpp|llama) _ai_run_llamacpp      "$prompt" ;;
    esac

    local elapsed=$(( SECONDS - start ))
    printf "\n${_AI[green]}✓ %s  %ds${_AI[r]}\n" "$p" "$elapsed"
    (( i++ ))
  done
}
```

- [ ] **Step 4: Add `bench` case to `ai.zsh`**

In `functions/ai/ai.zsh`, add immediately before the `install|i)` line:

```zsh
    bench|b) _ai_bench "$@" ;;
```

- [ ] **Step 5: Add `bench` row to `help.zsh`**

In `functions/ai/help.zsh`, inside the `UTILITIES` block, add after the `install` row:

```zsh
  _ai_help_cmd_row "bench" "b" "Run prompt across providers (Claude-backed only)"
```

- [ ] **Step 6: Add `bench` entries to `completion.zsh`**

In `functions/ai/completion.zsh`, add inside `subcmds` after the `'install:Install AI CLI'` line:

```zsh
    'bench:Run prompt across Claude-backed providers'
    'b:Run prompt across Claude-backed providers'
```

- [ ] **Step 7: Add `bench.zsh` to load list in `ai_functions.zsh`**

In `functions/ai/ai_functions.zsh`, add `bench.zsh \` before `completion.zsh`:

```zsh
  bench.zsh \
  completion.zsh
```

The full updated load list:

```zsh
for _ai_file in \
  core.zsh \
  providers/claude.zsh \
  providers/ollama.zsh \
  providers/llamacpp.zsh \
  providers/codex.zsh \
  providers/gemini.zsh \
  providers/copilot.zsh \
  providers/opencode.zsh \
  ship.zsh \
  install.zsh \
  help.zsh \
  picker.zsh \
  ai.zsh \
  bench.zsh \
  completion.zsh
```

- [ ] **Step 8: Run all tests**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add functions/ai/bench.zsh functions/ai/ai.zsh functions/ai/help.zsh \
        functions/ai/completion.zsh functions/ai/ai_functions.zsh \
        tests/ai_functions_test.zsh
git commit -m "feat(ai): add bench command — run prompt across Claude-backed providers"
```

---

## Task 5: `ai context`

**Files:**
- Create: `functions/ai/context.zsh`
- Modify: `functions/ai/ai.zsh`
- Modify: `functions/ai/help.zsh`
- Modify: `functions/ai/completion.zsh`
- Modify: `functions/ai/ai_functions.zsh`
- Modify: `tests/ai_functions_test.zsh`

- [ ] **Step 1: Write failing tests**

Append to `tests/ai_functions_test.zsh` before the final `print -r -- "PASS: ..."` line:

```zsh
# ai context: required sections present
context_out="$(ai context 2>/dev/null)"
assert_contains "$context_out" "# Context" \
  "ai context should output # Context header"
assert_contains "$context_out" "## Directory" \
  "ai context should output ## Directory section"
assert_contains "$context_out" "## File Tree" \
  "ai context should output ## File Tree section"

# ai context: git sections present (tests run inside the ~/.zsh git repo)
assert_contains "$context_out" "## Git Branch" \
  "ai context should include ## Git Branch when in git repo"
assert_contains "$context_out" "## Recent Commits" \
  "ai context should include ## Recent Commits when in git repo"

# ai context: --copy pipes to pbcopy
cat > "$TEST_TMP/bin/pbcopy" <<'STUB'
#!/usr/bin/env zsh
cat > "$TEST_TMP/pbcopy_received"
STUB
chmod +x "$TEST_TMP/bin/pbcopy"
ai context --copy >/dev/null 2>/dev/null
if [[ ! -f "$TEST_TMP/pbcopy_received" ]]; then
  print -r -- "FAIL: ai context --copy should pipe to pbcopy"
  exit 1
fi
copy_received="$(cat "$TEST_TMP/pbcopy_received")"
assert_contains "$copy_received" "# Context" \
  "ai context --copy should send # Context content to pbcopy"

# ai context: unknown flag exits non-zero
if ai context --badopt >/dev/null 2>&1; then
  print -r -- "FAIL: ai context --badopt should exit non-zero"
  exit 1
fi
```

- [ ] **Step 2: Run to verify failure**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: FAIL with `ai context should output # Context header`.

- [ ] **Step 3: Create `functions/ai/context.zsh`**

```zsh
# ai context — dump project context as plain markdown for AI paste-in

_ai_context() {
  local copy=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --copy|-c) copy=1; shift ;;
      *)
        printf "${_AI[red]}✗ Unknown flag: %s${_AI[r]}\n" "$1" >&2
        return 1
        ;;
    esac
  done

  local out=""

  out+="# Context\n\n"

  out+="## Directory\n"
  out+="$(pwd)\n\n"

  out+="## File Tree\n\`\`\`\n"
  if command -v fd >/dev/null 2>&1; then
    out+="$(fd --max-depth 2 --hidden --exclude .git 2>/dev/null)\n"
  else
    out+="$(find . -maxdepth 2 -not -path './.git/*' -not -name '.git' 2>/dev/null | sort)\n"
  fi
  out+="\`\`\`\n\n"

  if _ai_in_git_repo; then
    local branch
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    out+="## Git Branch\n${branch}\n\n"

    out+="## Git Status\n\`\`\`\n"
    out+="$(git status -s 2>/dev/null)\n"
    out+="\`\`\`\n\n"

    out+="## Recent Commits\n\`\`\`\n"
    out+="$(git log --oneline -10 2>/dev/null)\n"
    out+="\`\`\`\n"
  fi

  printf '%b' "$out"

  if [[ "$copy" -eq 1 ]]; then
    if command -v pbcopy >/dev/null 2>&1; then
      printf '%b' "$out" | pbcopy
      printf "${_AI[green]}✓ Copied to clipboard${_AI[r]}\n" >&2
    elif command -v xclip >/dev/null 2>&1; then
      printf '%b' "$out" | xclip -selection clipboard
      printf "${_AI[green]}✓ Copied to clipboard${_AI[r]}\n" >&2
    else
      printf "${_AI[yellow]}⚠ No clipboard tool found (pbcopy/xclip)${_AI[r]}\n" >&2
    fi
  fi
}
```

- [ ] **Step 4: Add `context` case to `ai.zsh`**

In `functions/ai/ai.zsh`, add immediately before the `bench|b)` line:

```zsh
    context|ctx) _ai_context "$@" ;;
```

- [ ] **Step 5: Add `context` row to `help.zsh`**

In `functions/ai/help.zsh`, add after the `bench` row:

```zsh
  _ai_help_cmd_row "context" "ctx" "Dump project context as markdown"
```

- [ ] **Step 6: Add `context` entries to `completion.zsh`**

In `functions/ai/completion.zsh`, add after the `bench` entries:

```zsh
    'context:Dump project context as markdown'
    'ctx:Dump project context as markdown'
```

- [ ] **Step 7: Add `context.zsh` to load list in `ai_functions.zsh`**

In `functions/ai/ai_functions.zsh`, add `context.zsh \` after `bench.zsh \`:

```zsh
  bench.zsh \
  context.zsh \
  completion.zsh
```

- [ ] **Step 8: Run all tests**

```bash
zsh ~/.zsh/tests/ai_functions_test.zsh
```

Expected: PASS — all assertions including all pre-existing ones.

- [ ] **Step 9: Verify full syntax check**

```bash
zsh -n ~/.zsh/init.zsh ~/.zsh/settings.zsh ~/.zsh/keys.zsh \
    ~/.zsh/themes/.zsh_theme ~/.zsh/plugins/plugins.zsh \
    ~/.zsh/functions/ai_functions.zsh \
    ~/.zsh/functions/ai/*.zsh ~/.zsh/functions/ai/providers/*.zsh
```

Expected: exits 0, no output.

- [ ] **Step 10: Commit**

```bash
git add functions/ai/context.zsh functions/ai/ai.zsh functions/ai/help.zsh \
        functions/ai/completion.zsh functions/ai/ai_functions.zsh \
        tests/ai_functions_test.zsh
git commit -m "feat(ai): add context command — dump project context as markdown"
```

---

## Implementation Order

1. Task 1 (data layer) → foundation for Tasks 2, 4
2. Task 2 (deduplication) → depends on Task 1
3. Task 3 (up + zload) → fully independent, any time
4. Task 4 (bench) → depends on Task 1 (uses `_ai_run_provider`)
5. Task 5 (context) → fully independent

## Key Invariants (verify after all tasks)

- `zsh ~/.zsh/tests/ai_functions_test.zsh` → PASS
- `ai ll --model qwen2.5-coder:14b "hello"` → claude called with `ANTHROPIC_BASE_URL=http://localhost:8001 ANTHROPIC_AUTH_TOKEN=sk-no-key-required`
- `ai c "hello"` + `ai l` → codex called twice
- Custom API key not persisted in `.ai_last_provider`
