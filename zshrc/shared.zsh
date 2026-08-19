# Generated from shell/profile.py. Do not edit manually.

export EDITOR='nvim'
export BUN_INSTALL="$HOME/.bun"

function path_prepend() {
    case :$PATH: in
        *:$1:*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

path_prepend "$HOME/.local/share/pnpm"
path_prepend "$HOME/.local/bin"
path_prepend '/usr/lib/cache/bin/'

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi

if [ -d "$HOME/Dev-Work/dotfiles/starship" ] && [ -f "$HOME/Dev-Work/dotfiles/starship/starship.toml" ]; then
    export STARSHIP_CONFIG="$HOME/Dev-Work/dotfiles/starship/starship.toml"
fi
if [ -f "$HOME/Dev-Work/dotfiles/fastfetch/config.jsonc" ]; then
    export FASTFETCH_CONFIG_DEFAULT="$HOME/Dev-Work/dotfiles/fastfetch/config.jsonc"
fi
if [ -f "$HOME/Dev-Work/dotfiles/fastfetch/config-v2.jsonc" ]; then
    export FASTFETCH_CONFIG_CAELESTIA="$HOME/Dev-Work/dotfiles/fastfetch/config-v2.jsonc"
fi

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh --cmd cd)"
fi
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

tmux() {
    local socket="${TMUX_SOCKET:-$HOME/.tmux-zsh.sock}"
    command tmux -f "$HOME/Dev-Work/dotfiles/tmux/tmux-zsh.conf" -S "$socket" "$@"
}

alias c='clear'
alias ls='eza --icons --group-directories-first -1'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lla='eza -la --icons --group-directories-first'
alias lt='eza -a --tree --level=1 --icons=always'
alias fastfetch='ff'
alias nf='ff'
alias pf='ff'
alias shutdown='systemctl poweroff'
alias wifi='nmtui'
alias ncode='nvim'
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'