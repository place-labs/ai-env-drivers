#!/bin/sh

# target directory for the repo
TARGET_DIR="drivers"
REPO_URL="https://github.com/PlaceOS/drivers.git"

git submodule update --init --recursive

if [ -d "$TARGET_DIR/.git" ]; then
    echo "Repository already exists. Pulling latest changes..."
    cd "$TARGET_DIR" && git pull --ff-only
else
    echo "Cloning repository..."
    git clone --depth 1 "$REPO_URL" "$TARGET_DIR"
fi

shards install

echo '░░░ Setup complete...'

