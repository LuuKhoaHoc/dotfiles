# PowerShell Profile Configuration
# This file customizes the PowerShell environment with tools, aliases, and path configurations

# =============================================================================
# ENVIRONMENT PATH CONFIGURATION
# =============================================================================
# Add custom tools and applications to PATH
$env:Path += ";C:\msys64\mingw64\bin"                         # MSYS2 MinGW tools
$env:Path += ";C:\Program Files\ImageMagick-7.1.1-Q16-HDRI"  # ImageMagick image processing
$env:Path += ";C:\Users\$env:USERNAME\AppData\Roaming\npm"          # Node.js global packages
$env:Path += ";C:\Users\$env:USERNAME\AppData\Local\Programs\lazygit"  # LazyGit TUI
$env:Path += ";C:\Users\$env:USERNAME\AppData\Local\Programs\ripgrep"  # ripgrep search tool
$env:Path += ";C:\Users\$env:USERNAME\AppData\Local\Programs\fd"       # fd file finder
$env:Path += ";C:\Users\$env:USERNAME\AppData\Local\Programs\bun"      # Bun JavaScript runtime


# =============================================================================
# ZOXIDE SETUP
# =============================================================================
# Add zoxide to PATH if installed via winget
$zoxidePath = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\ajeetdsouza.zoxide_Microsoft.Winget.Source_8wekyb3d8bbwe"
if (Test-Path $zoxidePath) {
    $env:PATH = "$zoxidePath;$env:PATH"
}

# Initialize zoxide if available
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& {(zoxide init powershell) -join "`n"})
} else {
    Write-Host "Warning: zoxide not found. Install it with: winget install ajeetdsouza.zoxide" -ForegroundColor Yellow
}

# =============================================================================
# PROMPT AND THEME CONFIGURATION
# =============================================================================
# Initialize Oh My Posh with custom theme
$themePath = "C:/Users/$env:USERNAME/dotfiles/ohmyposh/EDM115-newline.omp.json"
if (Test-Path $themePath) {
    oh-my-posh init pwsh --config $themePath | Invoke-Expression
} elseif ($env:POSH_THEMES_PATH) {
    $fallbackTheme = "$env:POSH_THEMES_PATH\catppuccin.omp.json"
    if (Test-Path $fallbackTheme) {
        oh-my-posh init pwsh --config $fallbackTheme | Invoke-Expression
    }
}

# Enable command history-based predictions
Set-PSReadLineOption -PredictionSource History

# =============================================================================
# FILE SYSTEM ALIASES
# =============================================================================
# Enhanced directory listing commands
Set-Alias -Name ll -Value dir
function ls { Get-ChildItem -Force | Format-Table -AutoSize }

# =============================================================================
# GIT ALIASES AND FUNCTIONS
# =============================================================================

# Status and basic operations
Set-Alias -Name gst -Value git_status
function git_status { git status -s }

Set-Alias -Name ga -Value git_add
function git_add { git add $args }

Set-Alias -Name gitc -Value git_commit
function git_commit { git commit $args }

Set-Alias -Name gcmsg -Value git_commit_message
function git_commit_message { git commit -m $args }

# Branch operations
Set-Alias -Name gco -Value git_checkout
function git_checkout { git checkout $args }

Set-Alias -Name gcb -Value git_checkout_branch
function git_checkout_branch { git checkout -b $args }

Set-Alias -Name gb -Value git_branch
function git_branch { git branch $args }

# Diff and log operations
Set-Alias -Name gd -Value git_diff
function git_diff { git diff --word-diff $args }

Set-Alias -Name glog -Value git_log
function git_log { git log $args }

# Remote operations
Set-Alias -Name gitp -Value git_push
function git_push { git push $args }

Set-Alias -Name gitl -Value git_pull
function git_pull { git pull $args }

Set-Alias -Name gcl -Value git_clone
function git_clone { git clone $args }

# Advanced operations
Set-Alias -Name grb -Value git_rebase
function git_rebase { git rebase $args }

Set-Alias -Name gitm -Value git_merge
function git_merge { git merge $args }

Set-Alias -Name gcp -Value git_cherry_pick
function git_cherry_pick { git cherry-pick $args }

Set-Alias -Name grh -Value git_reset
function git_reset { git reset $args }

# Stash operations
Set-Alias -Name gsl -Value git_stash_list
function git_stash_list { git stash list $args }

Set-Alias -Name gsa -Value git_stash_apply
function git_stash_apply { git stash apply $args }

Set-Alias -Name gss -Value git_stash_save
function git_stash_save { git stash save $args }

Set-Alias -Name gsu -Value git_stash_untracked
function git_stash_untracked { git stash -u $args }

# Yarn operations
Set-Alias -Name yd -Value yarn_dev
function yarn_dev { yarn dev $args }

Set-Alias -Name yb -Value yarn_build
function yarn_build { yarn build $args }

Set-Alias -Name ya -Value yarn_add
function yarn_add { yarn add $args }

Set-Alias -Name yrm -Value yarn_remove
function yarn_remove { yarn remove $args }

Set-Alias -Name yf -Value yarn_format
function yarn_format { yarn format $args }
