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

  local -a lines
  local file_tree status_output recent_commits branch

  lines+=("# Context" "")
  lines+=("## Directory" "$(pwd)" "")
  lines+=("## File Tree" '```')
  if command -v fd >/dev/null 2>&1; then
    file_tree="$(fd --max-depth 2 --hidden --exclude .git 2>/dev/null)"
  else
    file_tree="$(find . -maxdepth 2 -not -path './.git/*' -not -name '.git' 2>/dev/null | sort)"
  fi
  if [[ -n "$file_tree" ]]; then
    lines+=("${(@f)file_tree}")
  fi
  lines+=('```' "")

  if _ai_in_git_repo; then
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    status_output="$(git status -s 2>/dev/null)"
    recent_commits="$(git log --oneline -10 2>/dev/null)"

    lines+=("## Git Branch" "$branch" "")
    lines+=("## Git Status" '```')
    if [[ -n "$status_output" ]]; then
      lines+=("${(@f)status_output}")
    fi
    lines+=('```' "")
    lines+=("## Recent Commits" '```')
    if [[ -n "$recent_commits" ]]; then
      lines+=("${(@f)recent_commits}")
    fi
    lines+=('```')
  fi

  print -rl -- "$lines[@]"

  if [[ "$copy" -eq 1 ]]; then
    if command -v pbcopy >/dev/null 2>&1; then
      print -rl -- "$lines[@]" | pbcopy
      printf "${_AI[green]}✓ Copied to clipboard${_AI[r]}\n" >&2
    elif command -v xclip >/dev/null 2>&1; then
      print -rl -- "$lines[@]" | xclip -selection clipboard
      printf "${_AI[green]}✓ Copied to clipboard${_AI[r]}\n" >&2
    else
      printf "${_AI[yellow]}⚠ No clipboard tool found (pbcopy/xclip)${_AI[r]}\n" >&2
    fi
  fi
}
