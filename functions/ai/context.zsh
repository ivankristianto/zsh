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
