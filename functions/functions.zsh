# General utility functions

# Prerequisites
# Before running the container, you need two things from Telegram:
# Bot Token: Create a bot by messaging @BotFather on Telegram and sending /newbot.
# Chat ID: Message your new bot (e.g., say "Hello"), then visit https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates to find the "id" inside the chat object (it will be a number like 123456789).

# Send to telegram
# Telegram Notification Function
tt() {
    # 1. Configuration (loaded from ~/.zsh/keys)
    local BOT_TOKEN="${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN not set}"
    local CHAT_ID="${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID not set}"

    # 2. Variable to hold the message
    local MESSAGE=""

    # 3. Handle flags (like -m)
    while getopts ":m:" opt; do
      case $opt in
        m) MESSAGE="$OPTARG"
        ;;
        \?) echo "Invalid option -$OPTARG" >&2; return 1
        ;;
      esac
    done

    # 4. Fallback: If no -m flag, use the first argument, or default to "Ping"
    if [ -z "$MESSAGE" ]; then
        shift $((OPTIND -1))
        MESSAGE="${1:-Ping}"
    fi

    # 5. Send the request
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d text="${MESSAGE}" > /dev/null
}

# Alias to ssh to orb -> k2-dev(debian)
k2-dev() {
    orb -m k2-dev -w ''
}


# PHP
switchphp() {
    local version="$1"

    # Validate version format (e.g., 8.3, 7.4)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Usage: switchphp <version> (e.g., switchphp 8.3)" >&2
        return 1
    fi

    # Check if requested PHP version is installed
    if ! brew list "php@$version" &>/dev/null; then
        echo "php@$version is not installed. Install with: brew install php@$version" >&2
        return 1
    fi

    brew unlink php 2>/dev/null || true
    brew link --overwrite --force "shivammathur/php/php@$version" || return 1

    if [[ "$version" == "7.4" || "$version" == "8.1" ]]; then
        brew unlink "php@$version" && brew link --force "php@$version"
        brew link --overwrite "php@$version"
    fi
}

# Daily software update helper
# Short command: up
up() {
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local git_upstream
        git_upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)"
        if [[ -n "$git_upstream" ]]; then
            echo "==> Git pull (${git_upstream})"
            git pull --ff-only || echo "    ⚠ git pull failed (continuing)" >&2
        else
            echo "==> Git: no upstream tracking branch; skipping pull"
        fi
    else
        echo "==> Git: not in a git repository; skipping pull"
    fi

    if ! command -v brew >/dev/null 2>&1; then
        echo "brew not found; skipping Homebrew updates" >&2
        return 1
    fi

    echo "==> Homebrew upgrade"
    brew upgrade || return 1

    echo "==> Homebrew cleanup"
    brew cleanup || return 1

    if command -v npm >/dev/null 2>&1; then
        local npm_global_packages
        npm_global_packages=($(npm list -g --depth=0 --parseable 2>/dev/null | tail -n +2 | sed 's|.*/node_modules/||' | grep -v '^npm$'))
        if [[ ${#npm_global_packages[@]} -gt 0 ]]; then
            echo "==> npm global CLI refresh (${#npm_global_packages[@]} packages: ${npm_global_packages[*]})"
            npm install -g "${npm_global_packages[@]}" || echo "    ⚠ npm update failed (continuing)" >&2
        else
            echo "==> npm: no global packages found"
        fi
    else
        echo "npm not found; skipping npm global package refresh"
    fi

    if command -v nvm >/dev/null 2>&1; then
        echo "==> Node LTS check"
        nvm install --lts || echo "    ⚠ nvm LTS install failed (continuing)" >&2
    else
        echo "nvm not found; skipping Node LTS check"
    fi

    echo "==> Skills update"
    npx skills update || echo "    ⚠ skills update failed (continuing)" >&2
}
