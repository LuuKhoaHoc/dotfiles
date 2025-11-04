# AGENTS.md - Development Guidelines for Neovim Configuration

## Build/Lint/Test Commands

### Lua (Primary Language)
- **Format**: `stylua --config-path .stylua.toml .`
- **Lint**: `lua-language-server` (via LSP)
- **Single file format**: `stylua lua/config/options.lua`

### JavaScript/TypeScript
- **Lint**: `biome check .` or `oxlint .`
- **Format**: `prettier --write .` or `biome format --write .`
- **Single test**: `biome check lua/plugins/coding.lua`

### Python
- **Lint/Format**: `ruff check .` and `ruff format .`
- **Type check**: `pyright` (via LSP)
- **Format**: `black .`

### Go
- **Lint**: `revive .` or `gopls` (via LSP)
- **Format**: `shfmt -w .`

### Shell Scripts
- **Format**: `shfmt -w scripts/install-tools.sh`

### General
- **Spell check**: `cspell .`
- **All checks**: Run `stylua . && biome check . && ruff check .`

## Code Style Guidelines

### Lua Style
- **Indentation**: 2 spaces
- **Line endings**: Unix (LF)
- **Column width**: 120 characters
- **Quotes**: Auto-prefer double quotes
- **Naming**: snake_case for variables, PascalCase for modules
- **Imports**: Use `local` for all imports, group related imports
- **Tables**: Use consistent formatting with proper alignment

### JavaScript/TypeScript Style
- **No explicit any**: Use proper typing instead of `any`
- **Const assertions**: Use `as const` for literal types
- **Self-closing elements**: Always use self-closing tags when possible
- **Parameter assignment**: Error on parameter reassignment
- **Default parameters**: Place at end of parameter list

### General Patterns
- **Error handling**: Use `vim.diagnostic.config` for consistent error display
- **Plugin configuration**: Follow the `opts = {}` pattern for plugin setup
- **Keymaps**: Use `vim.keymap.set` with descriptive options
- **Options**: Use `vim.opt` for setting Vim options
- **Functional style**: Prefer functional programming patterns

### File Organization
- **Config files**: `lua/config/` for core Neovim settings
- **Language support**: `lua/langs/` for language-specific configurations
- **Plugins**: `lua/plugins/` for plugin configurations
- **Utilities**: `lua/utils/` for shared utilities

## Development Workflow

1. **Before committing**: Run formatters and linters
2. **Test changes**: Use Neovim with the configuration loaded
3. **Documentation**: Update README.md for significant changes
4. **Dependencies**: Check lazy-lock.json for plugin updates

## Tool Installation

Run `scripts/install-tools.sh` to install all required development tools:
- mise (version manager)
- stylua, biome, ruff, black, pyright
- lua-language-server, gopls, typescript-language-server
- prettier, cspell, shfmt

## No Cursor/Copilot Rules Found

This repository does not contain Cursor rules (`.cursor/rules/`) or Copilot instructions (`.github/copilot-instructions.md`). Follow the style guidelines above for consistency.
