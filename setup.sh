#!/bin/sh

# target directory for the repo
TARGET_DIR="drivers"
REPO_URL="https://github.com/PlaceOS/drivers.git"

# ensure the code we need is available
git submodule update --init --recursive

# ensure markitdown is available
cd markitdown/packages/markitdown-mcp
docker build -t markitdown-mcp:latest .
cd ../../../

# ensure the drivers repo is available
if [ -d "$TARGET_DIR/.git" ]; then
    echo "Repository already exists. Pulling latest changes..."
    cd "$TARGET_DIR" && git pull --ff-only
else
    echo "Cloning repository..."
    git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

# ensure shards are up to date and available
shards install
echo '░░░ Setup complete...'
