#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

export TMPDIR="$TEST_TMP/tmp"
mkdir -p "$TMPDIR" "$TEST_TMP/bin"
export AI_TEST_CALLS="$TEST_TMP/calls.log"
: > "$AI_TEST_CALLS"

cat > "$TEST_TMP/bin/npm" <<'STUB'
#!/usr/bin/env zsh
print -r -- "npm $*" >> "$AI_TEST_CALLS"
STUB

cat > "$TEST_TMP/bin/codex" <<'STUB'
#!/usr/bin/env zsh
print -r -- "codex $*" >> "$AI_TEST_CALLS"
STUB

cat > "$TEST_TMP/bin/claude" <<'STUB'
#!/usr/bin/env zsh
print -r -- "claude $*" >> "$AI_TEST_CALLS"
print -r -- "env ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-} ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN:-} ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-} ANTHROPIC_MODEL=${ANTHROPIC_MODEL:-}" >> "$AI_TEST_CALLS"
if [[ "${AI_TEST_CLAUDE_FAIL:-0}" == "1" ]]; then
  exit 1
fi
STUB

cat > "$TEST_TMP/bin/opencode" <<'STUB'
#!/usr/bin/env zsh
print -r -- "opencode $*" >> "$AI_TEST_CALLS"
STUB

chmod +x "$TEST_TMP/bin/npm" "$TEST_TMP/bin/codex" "$TEST_TMP/bin/claude" "$TEST_TMP/bin/opencode"
export PATH="$TEST_TMP/bin:$PATH"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    print -r -- "FAIL: $message"
    print -r -- "Expected to find: $needle"
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    print -r -- "FAIL: $message"
    print -r -- "Did not expect to find: $needle"
    exit 1
  fi
}

source "$ROOT_DIR/functions/ai_functions.zsh"

help_output="$(ai help)"
assert_contains "$help_output" "https://github.com/ivankristianto/zsh" "help should include repo helper link"
assert_contains "$help_output" "ai install claude|codex|gemini|ollama|copilot|opencode" "help should include installer helper notes"
assert_contains "$help_output" "llama.cpp" "help should include llama.cpp command when claude is available"

dry_run_output="$(ai install codex --dry-run)"
assert_contains "$dry_run_output" "@openai/codex" "codex installer should map to @openai/codex"

alias_dry_run_output="$(ai install c --dry-run)"
assert_contains "$alias_dry_run_output" "@openai/codex" "installer should support codex alias"

typeset -A expected_install=(
  [claude]='@anthropic-ai/claude-code'
  [codex]='@openai/codex'
  [gemini]='@google/gemini-cli'
  [ollama]='ollama'
  [copilot]='@github/copilot'
  [opencode]='opencode-ai'
)

for agent in "${(@k)expected_install}"; do
  output="$(ai install "$agent" --dry-run)"
  assert_contains "$output" "${expected_install[$agent]}" "installer mapping should match for $agent"
done

ollama_output="$(ai install ollama --dry-run)"
assert_contains "$ollama_output" "ollama.com/download" "ollama installer should show server install note"

if ai install unknown >/dev/null 2>&1; then
  print -r -- "FAIL: ai install unknown should fail"
  exit 1
fi

if ai oc --model >/dev/null 2>&1; then
  print -r -- "FAIL: ai oc --model without value should fail"
  exit 1
fi

if ai custom --model test --endpoint https://api.example.com --apikey >/dev/null 2>&1; then
  print -r -- "FAIL: ai custom --apikey without value should fail"
  exit 1
fi

export OPENAI_API_KEY="test-openai-key"
ai c "hello world" >/dev/null
ai l >/dev/null

codex_count="$(rg -c "^codex " "$AI_TEST_CALLS")"
if [[ "$codex_count" -lt 2 ]]; then
  print -r -- "FAIL: expected codex to be called at least twice (direct + last), got $codex_count"
  exit 1
fi

ai custom --model test-model --endpoint https://api.example.com --apikey sk-secret >/dev/null
last_command="$(cat "$TMPDIR/.ai_last_provider")"
if [[ "$last_command" == *"sk-secret"* ]]; then
  print -r -- "FAIL: custom api key must not be persisted in .ai_last_provider"
  exit 1
fi
assert_contains "$last_command" "--apikey-env AI_CUSTOM_API_KEY_LAST" "custom last command should use env-based key reference"

# llama.cpp should hardcode local anthropic-compatible values and ignore ambient env.
export ANTHROPIC_BASE_URL="http://wrong-host:9999"
export ANTHROPIC_API_KEY="sk-wrong"
ai llama.cpp --model qwen2.5-coder:14b "hello llama" >/dev/null

calls_output="$(cat "$AI_TEST_CALLS")"
assert_contains "$calls_output" "claude --dangerously-skip-permissions --model qwen2.5-coder:14b hello llama" "llama.cpp should execute claude with model forwarding"
assert_contains "$calls_output" "env ANTHROPIC_BASE_URL=http://localhost:8001 ANTHROPIC_AUTH_TOKEN=sk-no-key-required ANTHROPIC_API_KEY=sk-no-key-required ANTHROPIC_MODEL=qwen2.5-coder:14b" "llama.cpp should hardcode anthropic-compatible endpoint config"

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

# provider-backed ship: uses shared provider config/executor after provider refactor
: > "$AI_TEST_CALLS"
export GLM_API_KEY="test-glm-token"
(cd "$ROOT_DIR" && ai glm ship >/dev/null 2>&1)
ship_calls="$(cat "$AI_TEST_CALLS")"
assert_contains "$ship_calls" "claude --dangerously-skip-permissions --system-prompt" \
  "ai glm ship should invoke claude with ship prompt"
assert_contains "$ship_calls" "You are a git assistant. Help me commit changes, push to the current branch, and create a PR if the PR needs to be created." \
  "ai glm ship should pass the ship prompt content"
assert_contains "$ship_calls" "ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic" \
  "ai glm ship should set GLM base URL"
assert_contains "$ship_calls" "ANTHROPIC_AUTH_TOKEN=test-glm-token" \
  "ai glm ship should set GLM token"
assert_contains "$ship_calls" "ANTHROPIC_MODEL=glm-5.1" \
  "ai glm ship should set GLM model"

set +e

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

# ai bench: utility commands are not valid bench targets
bench_help_output="$(ai bench "hello" help 2>&1)"
assert_contains "$bench_help_output" "unavailable" \
  "ai bench should reject help as a non-provider target"

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

# ai bench: supports Claude aliases
: > "$AI_TEST_CALLS"
ai bench "bench prompt" s >/dev/null 2>&1
bench_alias_calls="$(cat "$AI_TEST_CALLS")"
assert_contains "$bench_alias_calls" "claude --dangerously-skip-permissions --model sonnet bench prompt" \
  "ai bench should support sonnet alias"

# ai bench: custom endpoint is rejected
bench_custom_output="$(ai bench "hello" custom 2>&1)"
assert_contains "$bench_custom_output" "not supported in bench" \
  "ai bench should reject custom provider"

# ai bench: provider runner failures propagate
export AI_TEST_CLAUDE_FAIL="1"
bench_fail_output="$(ai bench "bench prompt" glm 2>&1)"
bench_fail_rc=$?
unset AI_TEST_CLAUDE_FAIL
if [[ "$bench_fail_rc" -eq 0 ]]; then
  print -r -- "FAIL: ai bench should fail when provider runner fails"
  exit 1
fi
assert_not_contains "$bench_fail_output" "✓ glm" \
  "ai bench should not print success for failed provider"

set -e

print -r -- "PASS: ai functions tests"
