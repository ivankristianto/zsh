# Completion for ai command

_ai_completions() {
  local -a subcmds=(
    'sonnet:Claude Sonnet'
    's:Claude Sonnet'
    'haiku:Claude Haiku'
    'h:Claude Haiku'
    'opus:Claude Opus'
    'o:Claude Opus'
    'glm:GLM-5.1'
    'g:GLM-5.1'
    'kimi:Kimi K2.5 via Moonshot'
    'k:Kimi K2.5 via Moonshot'
    'mini:MiniMax M2.1'
    'm:MiniMax M2.1'
    'or:OpenRouter'
    'openrouter:OpenRouter'
    'ol:Ollama'
    'ollama:Ollama'
    'll:llama.cpp'
    'llama.cpp:llama.cpp local'
    'llamacpp:llama.cpp local'
    'llama:llama.cpp local'
    'codex:Codex'
    'c:Codex'
    'gemini:Gemini CLI'
    'ge:Gemini CLI'
    'copilot:GitHub Copilot'
    'cp:GitHub Copilot'
    'oc:OpenCode (build agent)'
    'opencode:OpenCode (build agent)'
    'custom:Custom endpoint'
    'cu:Custom endpoint'
    'install:Install AI CLI'
    'i:Install AI CLI'
    'last:Re-run last provider'
    'l:Re-run last provider'
    'help:Show help'
  )
  _describe 'ai command' subcmds
}

if (( ${+functions[compdef]} )) && (( ${+_comps} )); then
  compdef _ai_completions ai
fi
