# Load API keys from .env
_keys_script_dir="${${(%):-%N}:A:h}"
_env_file="${_keys_script_dir}/.env"

if [[ -f "${_env_file}" ]]; then
  set -a
  source "${_env_file}"
  set +a
fi

# Re-export expected variables for compatibility.
export OPENAI_API_KEY
export OPENROUTER_API_KEY
export GLM_API_KEY
export MINIMAX_API_KEY
export GOOGLE_API_KEY
export GEMINI_API_KEY
export SUMOPOD_API_KEY
export GROQ_API_KEY
export TELEGRAM_BOT_TOKEN
export TELEGRAM_CHAT_ID

unset _keys_script_dir
unset _env_file
