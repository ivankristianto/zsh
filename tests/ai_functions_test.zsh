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

print -r -- "PASS: ai functions tests"
