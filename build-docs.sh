#!/bin/bash

# Usage function
print_usage() {
    echo "Usage: $0 <git-repository-url> <output-directory-name> [-f file_path] [-f file_path] ..."
    echo
    echo "Example: $0 https://github.com/simonw/sqlite-utils sqlite-utils"
    echo "Example with specific files: $0 https://github.com/simonw/sqlite-utils sqlite-utils -f docs/readme.md -f docs/installation.rst"
    echo
    echo "This script:"
    echo "  1. Creates a temporary directory for cloning the repository"
    echo "  2. Clones the specified repository"
    echo "  3. For each git tag:"
    echo "     - Creates a text file containing the processed documentation"
    echo "     - Processes either specific files (if -f is used) or all .md and .rst files from the docs directory"
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

# Check for minimum required arguments
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

REPO_URL="$1"
OUTPUT_DIR_NAME="$2"
shift 2  # Remove the first two arguments

# Initialize an array for specific files
SPECIFIC_FILES=()

# Parse remaining arguments for -f options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            if [[ -n "$2" && "$2" != -* ]]; then
                SPECIFIC_FILES+=("$2")
                shift 2
            else
                echo "Error: -f option requires a file path"
                print_usage
                exit 1
            fi
            ;;
        *)
            echo "Error: Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

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

echo "Cloning repository $REPO_URL"
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

    # Process specific files if provided, otherwise process all .md and .rst files
    if [ ${#SPECIFIC_FILES[@]} -gt 0 ]; then
        # Check if the specified files exist for this tag
        FILES_EXIST=true
        for FILE in "${SPECIFIC_FILES[@]}"; do
            if [ ! -f "$FILE" ]; then
                echo "Warning: File $FILE does not exist for tag $TAG"
                FILES_EXIST=false
                break
            fi
        done

        if [ "$FILES_EXIST" = true ]; then
            echo "Generating documentation for $TAG using specific files..."
            files-to-prompt "${SPECIFIC_FILES[@]}" -c > "$OUTPUT_FILE"
            echo "Created $TAG.txt"
        else
            echo "Warning: Skipping tag $TAG because one or more specified files do not exist"
        fi
    else
        # No specific files provided, use all .md and .rst files in docs/
        if find docs/ -type f \( -name "*.md" -o -name "*.rst" \) -print -quit | grep -q .; then
            echo "Generating documentation for $TAG using all .md and .rst files..."
            files-to-prompt docs/ -e md -e rst -c > "$OUTPUT_FILE"
            echo "Created $TAG.txt"
        else
            echo "Warning: No .md or .rst files found in docs/ for tag $TAG"
        fi
    fi
done

# Cleanup
cd "$CURRENT_DIR" || exit
rm -rf "$TMP_DIR"

echo "Documentation build complete. Files are in $OUTPUT_DIR/"