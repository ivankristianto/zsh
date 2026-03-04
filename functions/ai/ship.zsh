# Ship workflow support

_AI_SHIP_PROMPT='You are a git assistant. Help me commit changes, push to the current branch, and create a PR if the PR needs to be created.

Use these tools available to you:
- git commands via shell
- gh CLI for PR creation

Workflow:
1. Check git status and suggest what to stage
2. Craft a good commit message based on the diff
3. Commit and push to current branch
4. Create a PR with gh pr create

Be concise but thorough. Ask me questions if anything is unclear.'

_ai_run_claude_ship() {
  local model="$1"
  shift
  _ai_require_cmd claude || return 1
  printf "${_AI[bcyan]}▶${_AI[r]} Claude Ship ${_AI[b]}%s${_AI[r]}\n" "$model"
  _ai_save_last "$model ship"
  claude --dangerously-skip-permissions --model "$model" \
    --system-prompt "$_AI_SHIP_PROMPT" \
    "Let's review and commit the changes. What's the current git status?" \
    "$@"
}

_ai_run_provider_ship() {
  local key="$1"
  shift
  local cfg="${_AI_PROVIDERS[$key]}"
  [[ -z "$cfg" ]] && {
    printf "${_AI[red]}✗ Unknown provider: %s${_AI[r]}\n" "$key"
    return 1
  }

  _ai_require_cmd claude || return 1

  local parts=("${(@s:|:)cfg}")
  local env_var="${parts[1]}"
  local base_url="${parts[2]}"
  local default_model="${parts[3]}"
  local haiku="${parts[4]}"
  local sonnet="${parts[5]}"
  local opus="${parts[6]}"
  local color="${parts[7]}"
  local label="${parts[8]}"

  local token
  if [[ "$env_var" == "_OLLAMA" ]]; then
    _ai_has_ollama || {
      printf "${_AI[red]}✗ Ollama unavailable (install ollama and run server at localhost:11434)${_AI[r]}\n"
      return 1
    }
    token="ollama"
  else
    token="${(P)env_var}"
    [[ -z "$token" ]] && {
      printf "${_AI[red]}✗ %s not set${_AI[r]}\n" "$env_var"
      return 1
    }
  fi

  printf "${_AI[$color]}▶${_AI[r]} %s Ship ${_AI[b]}%s${_AI[r]}\n" "$label" "$default_model"
  _ai_save_last "$key ship"

  ANTHROPIC_AUTH_TOKEN="$token" \
  ANTHROPIC_BASE_URL="$base_url" \
  ANTHROPIC_API_KEY="" \
  API_TIMEOUT_MS=3000000 \
  ANTHROPIC_MODEL="$default_model" \
  ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="$opus" \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
  claude --dangerously-skip-permissions \
    --system-prompt "$_AI_SHIP_PROMPT" \
    "Let's review and commit the changes. What's the current git status?" \
    "$@"
}

_ai_run_ship() {
  local provider="$1"
  shift

  if ! _ai_in_git_repo; then
    printf "${_AI[red]}✗ Not in a git repository${_AI[r]}\n"
    return 1
  fi

  if ! _ai_has_cmd gh; then
    printf "${_AI[yellow]}⚠ gh CLI not found. PR creation will not work.${_AI[r]}\n"
    printf "   Install: brew install gh && gh auth login\n"
  fi

  case "$provider" in
    sonnet|s) _ai_run_claude_ship "sonnet" "$@" ;;
    haiku|h) _ai_run_claude_ship "haiku" "$@" ;;
    opus|o) _ai_run_claude_ship "opus" "$@" ;;
    glm|g) _ai_run_provider_ship "glm" "$@" ;;
    kimi|k) _ai_run_provider_ship "kimi" "$@" ;;
    mini|m) _ai_run_provider_ship "mini" "$@" ;;
    or|openrouter) _ai_run_provider_ship "or" "$@" ;;
    ol|ollama) _ai_run_provider_ship "ol" "$@" ;;
    *)
      printf "${_AI[red]}✗ Unknown provider for ship: %s${_AI[r]}\n" "$provider"
      return 1
      ;;
  esac
}
