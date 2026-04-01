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
