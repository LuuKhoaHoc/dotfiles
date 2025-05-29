# -----------------------------------------------------
# Exports
# -----------------------------------------------------
set -gx EDITOR nvim [cite: 1]
set -gx PATH /usr/lib/cache/bin/ $PATH [cite: 1]
set -gx BUN_INSTALL $HOME/.bun [cite: 1]

# -----------------------------------------------------
# Set-up FZF key bindings (CTRL R for fuzzy history finder)
# -----------------------------------------------------
source (fzf --fish) [cite: 2]

# -----------------------------------------------------
# Prompt (Starship)
# -----------------------------------------------------
starship init fish | source

# bun completions
if test -s "/home/khoahoc/.bun/_bun"
  source "/home/khoahoc/.bun/_bun"
end
# bun completions
if test -s "/home/khoahoc/.bun/_bun" [cite: 2]
  source "/home/khoahoc/.bun/_bun" [cite: 2]
end

# -----------------------------------------------------
# ALIASES
# -----------------------------------------------------

# General
alias c='clear' [cite: 3]
alias nf='fastfetch' [cite: 3]
alias pf='fastfetch' [cite: 3]
alias ff='fastfetch' [cite: 3]
alias ls='eza -a --icons=always' [cite: 3]
alias ll='eza -al --icons=always' [cite: 3]
alias lt='eza -a --tree --level=1 --icons=always' [cite: 3]
alias shutdown='systemctl poweroff' [cite: 3]
alias v='$EDITOR' [cite: 3]
alias vim='$EDITOR' [cite: 3]
alias wifi='nmtui' [cite: 3]
alias ncode='nvim' [cite: 3]
alias zshrc='nvim ~/Dev-Work/dotfiles/zshrc' [cite: 3]
alias szshrc='source ~/.zshrc' [cite: 3]
alias cdwm='nvim ~/.config/chadwm/chadwm/config.def.h' [cite: 3]
function mdwm
  cd ~/.config/chadwm/chadwm/ [cite: 3]
  sudo make clean install [cite: 3]
  cd - [cite: 3]
end
alias cst='nvim ~/.config/st/config.def.h' [cite: 3]
function mst
  cd ~/Dev-Work/dotfiles/st/ [cite: 3, 4]
  rm -rf config.h [cite: 4]
  sudo make clean install [cite: 4]
  cd - [cite: 4]
end

# Yarn
alias yd='yarn dev' [cite: 4]
alias yb='yarn build' [cite: 4]
alias yf='yarn format' [cite: 4]
alias yst='yarn start' [cite: 4]
alias yln='yarn lint' [cite: 4]

# Window Managers
alias Qtile='startx' [cite: 4]

# System
alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg' [cite: 4]

# Qtile
alias res1='xrandr --output DisplayPort-0 --mode 2560x1440 --rate 120' [cite: 5]
alias res2='xrandr --output DisplayPort-0 --mode 1920x1080 --rate 120' [cite: 5]
alias setkb='setxkbmap de;echo "Keyboard set back to de."' [cite: 5]

# -----------------------------------------------------
# AUTOSTART
# -----------------------------------------------------
eval (ssh-agent -c) [cite: 5]
zoxide init fish | source
# fnm
set FNM_PATH "$HOME/.local/share/fnm" [cite: 5]
if test -d "$FNM_PATH" [cite: 5]
  set -gx PATH "$FNM_PATH" $PATH [cite: 5]
  fnm env | source [cite: 5]
end
eval (mise activate) [cite: 5]

# -----------------------------------------------------
# Fastfetch
# -----------------------------------------------------
if string match -q "*pts*" (tty) [cite: 7]
    fastfetch --config examples/18 [cite: 7]
else
    echo
    if test -f /bin/qtile [cite: 8]
        echo "Start Qtile X11 with command Qtile" [cite: 8]
    end
    if test -f /bin/hyprctl [cite: 9]
        echo "Start Hyprland with command Hyprland" [cite: 9]
    end
end
