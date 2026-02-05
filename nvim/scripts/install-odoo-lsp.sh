#!/bin/bash

set -e

ODOO_LS_DIR="$HOME/.local/share/nvim/odoo"
ODOO_LS_BIN="$ODOO_LS_DIR/odoo_ls_server"
ODOO_LS_VERSION="1.0.4"

echo "=========================================="
echo "  Odoo LSP Installation Script"
echo "=========================================="
echo ""

# Create directory
mkdir -p "$ODOO_LS_DIR"
mkdir -p "$ODOO_LS_DIR/typeshed"

# Download binary
echo "[1/4] Downloading Odoo LS binary v$ODOO_LS_VERSION..."
cd "$ODOO_LS_DIR"
if command -v wget &> /dev/null; then
    wget -q -O odoo_ls_server_temp "https://github.com/odoo/odoo-ls/releases/download/$ODOO_LS_VERSION/odoo-linux-x86_64-$ODOO_LS_VERSION.tar.gz"
    tar -xzf odoo_ls_server_temp odoo_ls_server
    rm odoo_ls_server_temp
elif command -v curl &> /dev/null; then
    curl -sL "https://github.com/odoo/odoo-ls/releases/download/$ODOO_LS_VERSION/odoo-linux-x86_64-$ODOO_LS_VERSION.tar.gz" -o odoo_ls_temp.tar.gz
    tar -xzf odoo_ls_temp.tar.gz
    rm odoo_ls_temp.tar.gz
else
    echo "Error: wget or curl is required"
    exit 1
fi

chmod +x odoo_ls_server
echo "   Binary installed: $ODOO_LS_BIN"

# Setup typeshed stubs
echo ""
echo "[2/4] Setting up typeshed stubs..."

# Clone odoo-ls repo for stubs
cd "$ODOO_LS_DIR/typeshed"
if [ -d "odoo-ls-temp" ]; then
    rm -rf odoo-ls-temp
fi

echo "   Cloning odoo-ls repo..."
git clone --depth 1 https://github.com/odoo/odoo-ls.git odoo-ls-temp

# Initialize submodules (for typeshed)
echo "   Initializing typeshed submodule..."
cd odoo-ls-temp
git submodule update --init --recursive

# Copy stdlib stubs
echo "   Setting up stdlib stubs..."
mkdir -p stubs
if [ -d "server/typeshed/stubs" ]; then
    cp -r server/typeshed/stubs/* stubs/
fi

# Cleanup
cd "$ODOO_LS_DIR/typeshed"
rm -rf odoo-ls-temp

echo "   Typeshed stubs installed"

# Create example config
echo ""
echo "[3/4] Creating example .odoo_lsp.json..."
cat > "$HOME/.odoo_lsp.json.example" << 'EOF'
{
    "odoo_path": "/path/to/your/odoo",
    "python_path": "/usr/bin/python3",
    "addons_paths": [
        "/path/to/your/odoo/addons",
        "/path/to/your/odoo/custom_addons"
    ],
    "stubs": [
        "/home/user/.local/share/nvim/odoo/typeshed/stubs"
    ],
    "diagnostic_filters": [
        {
            "paths": ["addons", "odoo"],
            "path_type": "out",
            "types": ["Disabled"]
        }
    ]
}
EOF

echo "   Example config: $HOME/.odoo_lsp.json.example"

# Verify installation
echo ""
echo "[4/4] Verifying installation..."
"$ODOO_LS_BIN" --version

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Copy example config to your project:"
echo "   cp ~/.odoo_lsp.json.example /your/project/.odoo_lsp.json"
echo ""
echo "2. Edit .odoo_lsp.json with your paths:"
echo "   - odoo_path: Path to Odoo source"
echo "   - addons_paths: Your custom addons"
echo ""
echo "3. Restart Neovim"
echo ""
