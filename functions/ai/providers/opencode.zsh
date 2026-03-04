# OpenCode provider

_ai_run_opencode() {
  _ai_require_cmd opencode || return 1

  local do_review=0
  local model=""
  local args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --review)
        do_review=1
        shift
        ;;
      --model)
        _ai_require_flag_value "--model" "${2-}" || return 1
        model="$2"
        shift 2
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  local prompt_args=()
  if [[ "$do_review" -eq 1 ]]; then
    local diff
    diff=$(git diff HEAD 2>/dev/null)
    [[ -z "$diff" ]] && diff=$(git diff origin/main...HEAD 2>/dev/null)
    [[ -z "$diff" ]] && diff=$(git diff main...HEAD 2>/dev/null)
    if [[ -z "$diff" ]]; then
      printf "${_AI[yellow]}⚠  No changes found to review${_AI[r]}\n"
    else
      local review_prompt="Please do a thorough code review of the following changes. Focus on: correctness, security, performance, maintainability, and adherence to best practices. Provide specific, actionable feedback with line references where applicable.

\`\`\`diff
${diff}
\`\`\`"
      prompt_args=(--prompt "$review_prompt")
    fi
  fi

  local model_args=()
  [[ -n "$model" ]] && model_args=(-m "$model")

  printf "${_AI[bmag]}▶${_AI[r]} OpenCode ${_AI[b]}build${_AI[r]}${model:+ ${_AI[d]}$model${_AI[r]}}\n"
  _ai_save_last "oc"
  opencode --agent build "${model_args[@]}" "${prompt_args[@]}" "${args[@]}"
}
