#!/bin/bash

# Usage function
print_usage() {
    echo "Usage: $0 <git-repository-url> <output-directory-name>"
    echo
    echo "Example: $0 https://github.com/simonw/sqlite-utils sqlite-utils"
    echo
    echo "This script:"
    echo "  1. Creates a temporary directory for cloning the repository"
    echo "  2. Clones the specified repository"
    echo "  3. For each git tag:"
    echo "     - Creates a text file containing the processed documentation"
    echo "     - Processes both .md and .rst files from the docs directory"
    echo "  4. Stores all output files in ./<output-directory-name>/"
}

# Error handling
set -e
trap 'echo "Error: Command failed at line $LINENO. Cleaning up..."; cleanup' ERR

# Cleanup function
cleanup() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
    exit 1
}

# Validate arguments
if [ "$#" -ne 2 ]; then
    print_usage
    exit 1
fi

REPO_URL="$1"
OUTPUT_DIR_NAME="$2"
CURRENT_DIR="$PWD"
OUTPUT_DIR="$CURRENT_DIR/$OUTPUT_DIR_NAME"

# Validate repository URL format
if ! echo "$REPO_URL" | grep -E '^https?://[^/]+/[^/]+/[^/]+/?$' >/dev/null; then
    echo "Error: Invalid repository URL format"
    print_usage
    exit 1
fi

# Check if files-to-prompt is installed
if ! command -v files-to-prompt >/dev/null; then
    echo "Error: files-to-prompt command not found"
    echo "Please install it first"
    exit 1
fi

# Create secure temporary directory
TMP_DIR=$(mktemp -d)
if [ ! -d "$TMP_DIR" ]; then
    echo "Error: Failed to create temporary directory"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Cloning repository..."
if ! git clone "$REPO_URL" "$TMP_DIR/repo" 2>/dev/null; then
    echo "Error: Failed to clone repository"
    cleanup
fi

cd "$TMP_DIR/repo" || cleanup

# Get and sort tags
TAGS=$(git tag | sort -V)
if [ -z "$TAGS" ]; then
    echo "Warning: No tags found in repository"
    cleanup
fi

# Process each tag
for TAG in $TAGS; do
    OUTPUT_FILE="$OUTPUT_DIR/$TAG.txt"

    # Skip if output file already exists
    if [ -f "$OUTPUT_FILE" ]; then
        echo "Skipping $TAG, $TAG.txt already exists."
        continue
    fi

    echo "Processing tag: $TAG"

    # Checkout tag
    if ! git checkout "$TAG" >/dev/null 2>&1; then
        echo "Warning: Failed to checkout tag $TAG, skipping..."
        continue
    fi

    # Check if docs directory exists
    if [ ! -d "docs" ]; then
        echo "Warning: No docs directory found for tag $TAG, skipping..."
        continue
    fi

    # Process documentation files
    if find docs/ -type f \( -name "*.md" -o -name "*.rst" \) -print -quit | grep -q .; then
        echo "Generating documentation for $TAG..."
        files-to-prompt docs/ -e md -e rst -c > "$OUTPUT_FILE"
        echo "Created $TAG.txt"
    else
        echo "Warning: No .md or .rst files found in docs/ for tag $TAG"
    fi
done

# Cleanup
cd "$CURRENT_DIR" || exit
rm -rf "$TMP_DIR"

echo "Documentation build complete. Files are in $OUTPUT_DIR/"