# Generated from shell/profile.py. Do not edit manually.

set -gx EDITOR 'nvim'
set -gx BUN_INSTALL '/home/khoahoc/.bun'

fish_add_path --move --prepend '/home/khoahoc/.amp/bin'
fish_add_path --move --prepend '/home/linuxbrew/.linuxbrew/bin'
fish_add_path --move --prepend '/home/linuxbrew/.linuxbrew/sbin'
fish_add_path --move --prepend '/home/khoahoc/.local/share/pnpm'
fish_add_path --move --prepend '/home/khoahoc/.cargo/bin'
fish_add_path --move --prepend '/home/khoahoc/.local/bin'
fish_add_path --move --prepend '/usr/lib/cache/bin/'

if command -q brew
    brew shellenv | source
end
if command -q mise
    mise activate fish | source
end

if status is-interactive
    set -l dotfiles_root '/home/khoahoc/Dev-Work/dotfiles'
    set -l starship_config $dotfiles_root/starship/starship.toml
    set -l fastfetch_default $dotfiles_root/fastfetch/config.jsonc
    set -l fastfetch_caelestia $dotfiles_root/fastfetch/config-v2.jsonc

    if test -f "$starship_config"
        set -gx STARSHIP_CONFIG "$starship_config"
    end
    if test -f "$fastfetch_default"
        set -gx FASTFETCH_CONFIG_DEFAULT "$fastfetch_default"
    end
    if test -f "$fastfetch_caelestia"
        set -gx FASTFETCH_CONFIG_CAELESTIA "$fastfetch_caelestia"
    end

    if command -q starship
        starship init fish | source
    end
    if command -q direnv
        direnv hook fish | source
    end
    if command -q zoxide
        zoxide init fish | source
    end
    if command -q fzf
        source (fzf --fish | psub)
    end

    set -l fnm_path '/home/khoahoc/.local/share/fnm'
    if test -d "$fnm_path"
        fish_add_path --move --prepend "$fnm_path"
        fnm env | source
    end

    if status is-login
        eval (ssh-agent -c)
    end

    function tmux
        set -l socket "$HOME/.tmux-fish.sock"
        command tmux -f "$HOME/Dev-Work/dotfiles/tmux/tmux-fish.conf" -S $socket $argv
    end

    function __fastfetch_config_for_profile
        switch "$HYPRLAND_SHELL"
            case caelestia quickshell qs
                if test -n "$FASTFETCH_CONFIG_CAELESTIA"; and test -f "$FASTFETCH_CONFIG_CAELESTIA"
                    echo "$FASTFETCH_CONFIG_CAELESTIA"
                    return 0
                end
            case '*'
                if test -n "$FASTFETCH_CONFIG_DEFAULT"; and test -f "$FASTFETCH_CONFIG_DEFAULT"
                    echo "$FASTFETCH_CONFIG_DEFAULT"
                    return 0
                end
        end

        if test -n "$FASTFETCH_CONFIG_DEFAULT"; and test -f "$FASTFETCH_CONFIG_DEFAULT"
            echo "$FASTFETCH_CONFIG_DEFAULT"
            return 0
        end

        if test -n "$FASTFETCH_CONFIG_CAELESTIA"; and test -f "$FASTFETCH_CONFIG_CAELESTIA"
            echo "$FASTFETCH_CONFIG_CAELESTIA"
            return 0
        end

        echo ""
    end

    function ff
        set -l cfg (__fastfetch_config_for_profile)
        if test -n "$cfg"
            command fastfetch --config "$cfg" $argv
        else
            command fastfetch $argv
        end
    end

    function v
        if set -q EDITOR
            command $EDITOR $argv
        else
            command nvim $argv
        end
    end

    function vim
        v $argv
    end

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

    abbr lg 'lazygit'
    abbr yd 'yarn dev'
    abbr yb 'yarn build'
    abbr yf 'yarn format'
    abbr yst 'yarn start'
    abbr yln 'yarn lint'
    abbr g 'git'
    abbr ga 'git add'
    abbr gaa 'git add --all'
    abbr gapa 'git add --patch'
    abbr gau 'git add --update'
    abbr gb 'git branch'
    abbr gba 'git branch -a'
    abbr gbd 'git branch -d'
    abbr gbD 'git branch -D'
    abbr gbl 'git blame -b -w'
    abbr gbnm 'git branch --no-merged'
    abbr gbr 'git branch --remote'
    abbr gbs 'git bisect'
    abbr gbsb 'git bisect bad'
    abbr gbsg 'git bisect good'
    abbr gbsr 'git bisect reset'
    abbr gbss 'git bisect start'
    abbr gc 'git commit -v'
    abbr gc! 'git commit -v --amend'
    abbr gcn! 'git commit -v --no-edit --amend'
    abbr gcam 'git commit -a -m'
    abbr gcas 'git commit -a -s'
    abbr gcasm 'git commit -a -s -m'
    abbr gcb 'git checkout -b'
    abbr gcd 'git checkout develop'
    abbr gcf 'git config --list'
    abbr gcl 'git clone --recurse-submodules'
    abbr gclean 'git clean -id'
    abbr gcm 'git checkout main'
    abbr gcmsg 'git commit -m'
    abbr gco 'git checkout'
    abbr gcor 'git checkout --recurse-submodules'
    abbr gcount 'git shortlog -sn'
    abbr gcp 'git cherry-pick'
    abbr gcpa 'git cherry-pick --abort'
    abbr gcpc 'git cherry-pick --continue'
    abbr gcs 'git commit -S'
    abbr gd 'git diff'
    abbr gdca 'git diff --cached'
    abbr gdcw 'git diff --cached --word-diff'
    abbr gds 'git diff --staged'
    abbr gdt 'git diff-tree --no-commit-id --name-only -r'
    abbr gdup 'git diff @{upstream}'
    abbr gdw 'git diff --word-diff'
    abbr gf 'git fetch'
    abbr gfa 'git fetch --all --prune'
    abbr gfo 'git fetch origin'
    abbr gg 'git gui citool'
    abbr gga 'git gui citool --amend'
    abbr ghh 'git help'
    abbr gignore 'git update-index --assume-unchanged'
    abbr gignored 'git ls-files -v | grep "^[[:lower:]]"'
    abbr gk 'gitk --all --branches'
    abbr gl 'git pull'
    abbr glg 'git log --stat'
    abbr glgg 'git log --graph'
    abbr glgga 'git log --graph --decorate --all'
    abbr glgm 'git log --graph --max-count=20'
    abbr glgp 'git log --stat -p'
    abbr glog 'git log --oneline --decorate --graph'
    abbr gloga 'git log --oneline --decorate --graph --all'
    abbr gm 'git merge'
    abbr gma 'git merge --abort'
    abbr gmt 'git mergetool --no-prompt'
    abbr gmtvim 'git mergetool --no-prompt --tool=vimdiff'
    abbr gp 'git push'
    abbr gpd 'git push --dry-run'
    abbr gpf 'git push --force'
    abbr gpf! 'git push --force-with-lease'
    abbr gpoat 'git push origin --all && git push origin --tags'
    abbr gpr 'git pull --rebase'
    abbr gpristine 'git reset --hard && git clean -dffx'
    abbr gpu 'git push upstream'
    abbr gpv 'git push -v'
    abbr gr 'git remote'
    abbr gra 'git remote add'
    abbr grb 'git rebase'
    abbr grba 'git rebase --abort'
    abbr grbc 'git rebase --continue'
    abbr grbd 'git rebase develop'
    abbr grbi 'git rebase -i'
    abbr grbm 'git rebase main'
    abbr grbo 'git rebase --onto'
    abbr grbs 'git rebase --skip'
    abbr grev 'git revert'
    abbr grh 'git reset'
    abbr grhh 'git reset --hard'
    abbr grm 'git rm'
    abbr grmc 'git rm --cached'
    abbr grmv 'git remote rename'
    abbr grrm 'git remote remove'
    abbr grs 'git restore'
    abbr grset 'git remote set-url'
    abbr grss 'git restore --source'
    abbr gru 'git reset --'
    abbr grup 'git remote update'
    abbr grv 'git remote -v'
    abbr gsb 'git status -sb'
    abbr gsh 'git show'
    abbr gsps 'git show --pretty=short --show-signature'
    abbr gss 'git status -s'
    abbr gst 'git status'
    abbr gsta 'git stash push'
    abbr gstaa 'git stash apply'
    abbr gstc 'git stash clear'
    abbr gstd 'git stash drop'
    abbr gstl 'git stash list'
    abbr gstp 'git stash pop'
    abbr gsts 'git stash show --text'
    abbr gsu 'git submodule update'
    abbr gsw 'git switch'
    abbr gswc 'git switch -c'
    abbr gtl 'git tag --sort=-v:refname'
    abbr gts 'git tag -s'
    abbr gtv 'git tag | sort -V'
    abbr gunignore 'git update-index --no-assume-unchanged'
    abbr gup 'git pull --rebase'
    abbr gupv 'git pull --rebase -v'
    abbr gupa 'git pull --rebase --autostash'
    abbr gupav 'git pull --rebase --autostash -v'
    abbr gwch 'git whatchanged -p --abbrev-commit --pretty=medium'

    if test -s "$HOME/.bun/_bun"
        source "$HOME/.bun/_bun"
    end
end

function mark_prompt_start --on-event fish_prompt
    if test "$TERM" = "foot"
        echo -en "\e]133;A\e\\"
    end
end

function fish_greeting
    echo -ne '\x1b[38;5;16m'
    set_color normal
    ff --key-padding-left 5
end

if test -f ~/.config/caelestia/user-config.fish
    source ~/.config/caelestia/user-config.fish
end

string match -q "$TERM_PROGRAM" "kiro" and . (kiro --locate-shell-integration-path fish)
