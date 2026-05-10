#!/usr/bin/env python3
from __future__ import annotations

import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILE = runpy.run_path(str(ROOT / "shell" / "profile.py"))["PROFILE"]
HOME = Path.home()


def expand_home(value: str) -> str:
    return value.replace("$HOME", str(HOME))


def quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def render_zsh() -> str:
    env = PROFILE["env"]
    paths = [expand_home(path) for path in PROFILE["paths"]]
    fastfetch_default = expand_home(str(ROOT / PROFILE["fastfetch"]["default"]))
    fastfetch_caelestia = expand_home(str(ROOT / PROFILE["fastfetch"]["caelestia"]))
    starship_config = expand_home(str(ROOT / "starship" / "starship.toml"))
    fnm_path = expand_home(PROFILE["fnm_path"])
    aliases = PROFILE["aliases"]

    lines = [
        "# Generated from shell/profile.py. Do not edit manually.",
        "",
        f"export EDITOR={quote(env['EDITOR'])}",
        f"export BUN_INSTALL={quote(expand_home(env['BUN_INSTALL']))}",
        "",
        "function path_prepend() {",
        "    case :$PATH: in",
        "        *:$1:*) ;;",
        '        *) PATH="$1:$PATH" ;;',
        "    esac",
        "}",
        "",
    ]
    for path in paths:
        lines.append(f"path_prepend {quote(path)}")
    lines.extend(
        [
            "",
            f"if [ -x {quote('/home/linuxbrew/.linuxbrew/bin/brew')} ]; then",
            f'    eval "$({quote("/home/linuxbrew/.linuxbrew/bin/brew")} shellenv)"',
            "fi",
            "",
            "if command -v mise >/dev/null 2>&1; then",
            '    eval "$(mise activate zsh)"',
            "fi",
            "",
            f"if [ -d {quote(fnm_path)} ]; then",
            f"    path_prepend {quote(fnm_path)}",
            '    eval "$(fnm env)"',
            "fi",
            "",
            f"if [ -f {quote(starship_config)} ]; then",
            f"    export STARSHIP_CONFIG={quote(starship_config)}",
            "fi",
            f"if [ -f {quote(fastfetch_default)} ]; then",
            f"    export FASTFETCH_CONFIG_DEFAULT={quote(fastfetch_default)}",
            "fi",
            f"if [ -f {quote(fastfetch_caelestia)} ]; then",
            f"    export FASTFETCH_CONFIG_CAELESTIA={quote(fastfetch_caelestia)}",
            "fi",
            "",
            "if command -v starship >/dev/null 2>&1; then",
            '    eval "$(starship init zsh)"',
            "fi",
            "if command -v direnv >/dev/null 2>&1; then",
            '    eval "$(direnv hook zsh)"',
            "fi",
            "if command -v zoxide >/dev/null 2>&1; then",
            '    eval "$(zoxide init zsh --cmd cd)"',
            "fi",
            "if command -v fzf >/dev/null 2>&1; then",
            "    source <(fzf --zsh)",
            "fi",
            "",
            "tmux() {",
            '    local socket="${TMUX_SOCKET:-$HOME/.tmux-zsh.sock}"',
            '    command tmux -f "$HOME/Dev-Work/dotfiles/tmux/tmux-zsh.conf" -S "$socket" "$@"',
            "}",
            "",
        ]
    )
    for alias, value in aliases.items():
        lines.append(f"alias {alias}={quote(value)}")
    lines.append("")
    return "\n".join(lines)


def render_fish() -> str:
    env = PROFILE["env"]
    paths = [expand_home(path) for path in PROFILE["paths"]]
    fastfetch_default = expand_home(str(ROOT / PROFILE["fastfetch"]["default"]))
    fastfetch_caelestia = expand_home(str(ROOT / PROFILE["fastfetch"]["caelestia"]))
    starship_config = expand_home(str(ROOT / "starship" / "starship.toml"))
    fnm_path = expand_home(PROFILE["fnm_path"])
    aliases = PROFILE["aliases"]
    abbrs = PROFILE["fish"]["abbrs"]
    greeting_lines = PROFILE["fish"]["greeting_lines"]

    lines = [
        "# Generated from shell/profile.py. Do not edit manually.",
        "",
        f"set -gx EDITOR {quote(env['EDITOR'])}",
        f"set -gx BUN_INSTALL {quote(expand_home(env['BUN_INSTALL']))}",
        "",
    ]
    for path in paths:
        lines.append(f"fish_add_path --move --prepend {quote(path)}")
    lines.extend(
        [
            "",
            "if command -q brew",
            "    brew shellenv | source",
            "end",
            "if command -q mise",
            "    mise activate fish | source",
            "end",
            "",
            "if status is-interactive",
            f"    set -l dotfiles_root {quote(str(ROOT))}",
            "    set -l starship_config $dotfiles_root/starship/starship.toml",
            "    set -l fastfetch_default $dotfiles_root/fastfetch/config.jsonc",
            "    set -l fastfetch_caelestia $dotfiles_root/fastfetch/config-v2.jsonc",
            "",
            '    if test -f "$starship_config"',
            '        set -gx STARSHIP_CONFIG "$starship_config"',
            "    end",
            '    if test -f "$fastfetch_default"',
            '        set -gx FASTFETCH_CONFIG_DEFAULT "$fastfetch_default"',
            "    end",
            '    if test -f "$fastfetch_caelestia"',
            '        set -gx FASTFETCH_CONFIG_CAELESTIA "$fastfetch_caelestia"',
            "    end",
            "",
            "    if command -q starship",
            "        starship init fish | source",
            "    end",
            "    if command -q direnv",
            "        direnv hook fish | source",
            "    end",
            "    if command -q zoxide",
            "        zoxide init fish | source",
            "    end",
            "    if command -q fzf",
            "        source (fzf --fish | psub)",
            "    end",
            "",
            f"    set -l fnm_path {quote(fnm_path)}",
            '    if test -d "$fnm_path"',
            '        fish_add_path --move --prepend "$fnm_path"',
            "        fnm env | source",
            "    end",
            "",
            "    if status is-login",
            "        eval (ssh-agent -c)",
            "    end",
            "",
            "    function tmux",
            '        set -l socket "$HOME/.tmux-fish.sock"',
            '        command tmux -f "$HOME/Dev-Work/dotfiles/tmux/tmux-fish.conf" -S $socket $argv',
            "    end",
            "",
            "    function __fastfetch_config_for_profile",
            '        switch "$HYPRLAND_SHELL"',
            "            case caelestia quickshell qs",
            '                if test -n "$FASTFETCH_CONFIG_CAELESTIA"; and test -f "$FASTFETCH_CONFIG_CAELESTIA"',
            '                    echo "$FASTFETCH_CONFIG_CAELESTIA"',
            "                    return 0",
            "                end",
            "            case '*'",
            '                if test -n "$FASTFETCH_CONFIG_DEFAULT"; and test -f "$FASTFETCH_CONFIG_DEFAULT"',
            '                    echo "$FASTFETCH_CONFIG_DEFAULT"',
            "                    return 0",
            "                end",
            "        end",
            "",
            '        if test -n "$FASTFETCH_CONFIG_DEFAULT"; and test -f "$FASTFETCH_CONFIG_DEFAULT"',
            '            echo "$FASTFETCH_CONFIG_DEFAULT"',
            "            return 0",
            "        end",
            "",
            '        if test -n "$FASTFETCH_CONFIG_CAELESTIA"; and test -f "$FASTFETCH_CONFIG_CAELESTIA"',
            '            echo "$FASTFETCH_CONFIG_CAELESTIA"',
            "            return 0",
            "        end",
            "",
            '        echo ""',
            "    end",
            "",
            "    function ff",
            "        set -l cfg (__fastfetch_config_for_profile)",
            '        if test -n "$cfg"',
            '            command fastfetch --config "$cfg" $argv',
            "        else",
            "            command fastfetch $argv",
            "        end",
            "    end",
            "",
            "    function v",
            "        if set -q EDITOR",
            "            command $EDITOR $argv",
            "        else",
            "            command nvim $argv",
            "        end",
            "    end",
            "",
            "    function vim",
            "        v $argv",
            "    end",
            "",
        ]
    )
    for alias, value in aliases.items():
        lines.append(f"    alias {alias}={quote(value)}")
    lines.append("")
    for abbr, value in abbrs.items():
        lines.append(f"    abbr {abbr} {quote(value)}")
    lines.extend(
        [
            "",
            '    if test -s "$HOME/.bun/_bun"',
            '        source "$HOME/.bun/_bun"',
            "    end",
            "end",
            "",
            "function mark_prompt_start --on-event fish_prompt",
            '    if test "$TERM" = "foot"',
            '        echo -en "\\e]133;A\\e\\\\"',
            "    end",
            "end",
            "",
            "function fish_greeting",
            "    echo -ne '\\x1b[38;5;16m'",
        ]
    )
    for line in greeting_lines:
        lines.append(f"    echo {quote(line)}")
    lines.extend(
        [
            "    set_color normal",
            "    ff --key-padding-left 5",
            "end",
            "",
            "if test -f ~/.config/caelestia/user-config.fish",
            "    source ~/.config/caelestia/user-config.fish",
            "end",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    write_file(ROOT / "zshrc" / "shared.zsh", render_zsh())
    write_file(ROOT / "fish" / "config.fish", render_fish())


if __name__ == "__main__":
    main()
