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
    brew unlink php && brew link --overwrite --force shivammathur/php/php@$1

    if [ "$1" = "7.4" ] || [  "$1" = "8.1" ]; 
    then
	brew unlink php@$1 && brew link --force php@$1;
	brew link --overwrite php@$1;
    fi
}

# Daily software update helper
# Short command: up
up() {
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
            npm install -g "${npm_global_packages[@]}" || return 1
        else
            echo "==> npm: no global packages found"
        fi
    else
        echo "npm not found; skipping npm global package refresh"
    fi

    if command -v nvm >/dev/null 2>&1; then
        echo "==> Node LTS check"
        nvm install --lts || return 1
    else
        echo "nvm not found; skipping Node LTS check"
    fi
}
