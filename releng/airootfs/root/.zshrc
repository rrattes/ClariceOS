# ClariceOS — Zsh configuration
# grml-zsh-config provides the base (completion, keybindings, syntax-highlighting).
# This file adds autosuggestions, history substring search, and the Starship prompt.

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY INC_APPEND_HISTORY

# ── Zsh Autosuggestions ───────────────────────────────────────────────────────
# Suggest commands from history as you type (greyed-out ghost text)
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6272a4"          # Dracula comment colour
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# ── History substring search ──────────────────────────────────────────────────
# Up/Down arrows search history by the already-typed prefix
if [[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND="bg=#44475a,fg=#f8f8f2,bold"
    HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND="bg=#ff5555,fg=#282a36,bold"
fi

# ── Aliases ───────────────────────────────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias lt='ls -lah --color=auto --sort=time'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip --color=auto'

# ── Starship prompt ───────────────────────────────────────────────────────────
# Initialised last so it overrides any prompt set by grml-zsh-config
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi
