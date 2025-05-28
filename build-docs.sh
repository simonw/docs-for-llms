#!/bin/bash

# --- Configuration ---
DEFAULT_DOCS_DIR="docs" # Default directory to look for docs if -f is not used
DEFAULT_EXTENSIONS=("md" "rst") # Default extensions if -f is not used

# --- Functions ---

# Print usage instructions
print_usage() {
    echo "Usage: $0 <git-repository-url> <output-directory-name> [-f file_path] [-f file_path] ..."
    echo
    echo "Example: $0 https://github.com/simonw/sqlite-utils sqlite-utils"
    echo "Example with specific files: $0 https://github.com/simonw/sqlite-utils sqlite-utils -f docs/readme.md -f docs/installation.rst"
    echo
    echo "This script:"
    echo "  1. Creates a temporary directory for cloning the repository."
    echo "  2. Clones the specified repository."
    echo "  3. For each git tag:"
    echo "     - Checks out the tag."
    echo "     - If -f options are used, processes only the specified files *that exist* for that tag."
    echo "     - If -f options are *not* used, processes all files with default extensions (e.g., .md, .rst) in the default docs directory (e.g., docs/)."
    echo "     - Creates a text file containing the processed content using 'files-to-prompt'."
    echo "  4. Stores all output files in ./<output-directory-name>/."
    echo "  5. Cleans up the temporary directory."
}

# Error handling: Print message and trigger cleanup
handle_error() {
    local lineno="$1"
    local msg="${2:-"Command failed"}"
    echo "Error: $msg at line $lineno."
    cleanup >/dev/null 2>&1 # Suppress cleanup messages during error handling
    exit 1
}

# Cleanup temporary directory
cleanup() {
    echo "Cleaning up..."
    # Return to original directory if we changed
    if [[ -n "$CURRENT_DIR" && "$PWD" != "$CURRENT_DIR" ]]; then
        cd "$CURRENT_DIR" || echo "Warning: Failed to return to original directory '$CURRENT_DIR'."
    fi
    # Remove temporary directory if it exists and was created by us
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" && "$TMP_DIR" =~ ^/tmp/.* || "$TMP_DIR" =~ ^"$TMPDIR"/.* ]]; then
        echo "Removing temporary directory '$TMP_DIR'."
        rm -rf "$TMP_DIR"
    elif [[ -n "$TMP_DIR" ]]; then
        echo "Warning: Temporary directory '$TMP_DIR' not removed (path doesn't look standard or variable not set)."
    fi
}

# --- Main Script ---

# Enable strict error checking and set traps
set -eEo pipefail
trap 'handle_error $LINENO' ERR
trap cleanup EXIT INT TERM

# Check for minimum required arguments
if [ "$#" -lt 2 ]; then
    print_usage
    exit 1
fi

REPO_URL="$1"
OUTPUT_DIR_NAME="$2"
shift 2 # Remove the first two arguments

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
                handle_error "$LINENO" "-f option requires a file path argument"
            fi
            ;;
        *)
            handle_error "$LINENO" "Unknown option: $1"
            ;;
    esac
done

CURRENT_DIR="$PWD"
OUTPUT_DIR="$CURRENT_DIR/$OUTPUT_DIR_NAME"
TMP_DIR="" # Initialize TMP_DIR

# Validate repository URL format (simple check)
# Allows http, https, git, ssh protocols
if ! [[ "$REPO_URL" =~ ^(https?|git|ssh)://.+/.+ ]]; then
    handle_error "$LINENO" "Invalid repository URL format: $REPO_URL"
fi

# Check if files-to-prompt is installed
if ! command -v files-to-prompt >/dev/null; then
    handle_error "$LINENO" "'files-to-prompt' command not found. Please install it (e.g., 'pip install files-to-prompt')."
fi

# Create secure temporary directory
TMP_DIR=$(mktemp -d -t files-to-prompt-clone-XXXXXX)
if [ ! -d "$TMP_DIR" ]; then
    handle_error "$LINENO" "Failed to create temporary directory"
fi
echo "Created temporary directory: $TMP_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo "Output will be stored in: $OUTPUT_DIR"

echo "Cloning repository '$REPO_URL'..."
# Clone quietly, but check exit code
if ! git clone --quiet "$REPO_URL" "$TMP_DIR/repo"; then
    handle_error "$LINENO" "Failed to clone repository '$REPO_URL'"
fi
echo "Repository cloned successfully."

cd "$TMP_DIR/repo" # Change directory, trap will handle cleanup

# Get and sort tags using version sort
TAGS=$(git tag | sort -V)
if [ -z "$TAGS" ]; then
    echo "Warning: No tags found in repository. Exiting."
    # No error, just nothing to do. Cleanup will run on exit.
    exit 0
fi
echo "Found tags: $(echo $TAGS | wc -w)" # Count tags

# Process each tag
for TAG in $TAGS; do
    OUTPUT_FILE="$OUTPUT_DIR/$TAG.txt"

    # Sanitize tag name slightly for filename (replace slashes) - less common but possible
    SANITIZED_TAG_NAME=$(echo "$TAG" | tr '/' '_')
    OUTPUT_FILE="$OUTPUT_DIR/$SANITIZED_TAG_NAME.txt"


    # Skip if output file already exists
    if [ -f "$OUTPUT_FILE" ]; then
        echo "Skipping tag '$TAG': Output file '$OUTPUT_FILE' already exists."
        continue
    fi

    echo "--- Processing tag: $TAG ---"

    # Checkout tag quietly
    if ! git checkout --quiet "$TAG"; then
        echo "Warning: Failed to checkout tag '$TAG', skipping..."
        # Potentially log this failure if needed, but continue to next tag
        continue
    fi
    echo "Checked out tag '$TAG'."

    # Determine files to process
    FILES_TO_PROCESS=()
    if [ ${#SPECIFIC_FILES[@]} -gt 0 ]; then
        # --- Specific files requested (-f option used) ---
        echo "Checking for specified files..."
        EXISTING_SPECIFIC_FILES=()
        for FILE_PATH in "${SPECIFIC_FILES[@]}"; do
            if [ -f "$FILE_PATH" ]; then
                EXISTING_SPECIFIC_FILES+=("$FILE_PATH")
                echo "  Found: '$FILE_PATH'"
            else
                # File specified with -f does not exist for this tag - WARN AND OMIT
                echo "  Warning: Specified file '$FILE_PATH' not found for tag '$TAG'. Omitting."
            fi
        done

        if [ ${#EXISTING_SPECIFIC_FILES[@]} -gt 0 ]; then
            # If at least one specified file exists, use them
            FILES_TO_PROCESS=("${EXISTING_SPECIFIC_FILES[@]}")
            echo "Using ${#FILES_TO_PROCESS[@]} existing specified file(s) for tag '$TAG'."
        else
             # If *none* of the specified files exist for this tag
            echo "Warning: None of the files specified with -f exist for tag '$TAG'. Skipping generation for this tag."
            continue # Skip to the next tag
        fi

    else
        # --- No specific files requested (-f not used) ---
        # Check if default docs directory exists
        if [ ! -d "$DEFAULT_DOCS_DIR" ]; then
            echo "Warning: Default docs directory '$DEFAULT_DOCS_DIR' not found for tag '$TAG', skipping..."
            continue
        fi

        # Find files with default extensions in the default directory
        echo "Searching for files in '$DEFAULT_DOCS_DIR' with extensions: ${DEFAULT_EXTENSIONS[*]}..."
        FOUND_FILES=()
        find_args=()
        for ext in "${DEFAULT_EXTENSIONS[@]}"; do
          find_args+=(-o -name "*.$ext")
        done
        # Remove the initial -o
        find_args=("${find_args[@]:1}")

        # Use zero-terminated file names in case there are any special characters
        FOUND_FILES=()
        while IFS= read -r -d '' file; do
            FOUND_FILES+=("$file")
        done < <(find "$DEFAULT_DOCS_DIR/" -maxdepth 10 -type f \( "${find_args[@]}" \) -print0 | sort -zV) || true # Handle potential find errors, don't exit

        # Check if we had issues or no files found
        if [ ${#FOUND_FILES[@]} -eq 0 ]; then
             # Check if find command actually failed vs just finding nothing
             if [[ ${PIPESTATUS[0]} -ne 0 && ${PIPESTATUS[0]} -ne 1 ]]; then # find returns 1 if no files match sometimes
                 echo "Warning: Error running 'find' command in '$DEFAULT_DOCS_DIR' for tag '$TAG'."
             else
                 echo "Warning: No files with extensions (${DEFAULT_EXTENSIONS[*]}) found in '$DEFAULT_DOCS_DIR' for tag '$TAG'."
             fi
             continue # Skip to the next tag
        fi

        FILES_TO_PROCESS=("${FOUND_FILES[@]}")
        echo "Found ${#FILES_TO_PROCESS[@]} file(s) to process in '$DEFAULT_DOCS_DIR'."
        # Print found files for clarity if needed (can be verbose)
        # printf "  - %s\n" "${FILES_TO_PROCESS[@]}"

    fi

    # --- Generate documentation using files-to-prompt ---
    if [ ${#FILES_TO_PROCESS[@]} -gt 0 ]; then
        echo "Generating documentation for tag '$TAG' into '$OUTPUT_FILE'..."
        # Pass the collected files (either specific existing or found default files)
        # Use null delimiter with xargs for safety with complex filenames
        printf "%s\0" "${FILES_TO_PROCESS[@]}" | xargs -0 files-to-prompt -c > "$OUTPUT_FILE"
        # Alternative without xargs (might hit arg limits for huge numbers of files):
        # files-to-prompt "${FILES_TO_PROCESS[@]}" -c > "$OUTPUT_FILE"

        # Check if the output file was created and is not empty
        if [ -s "$OUTPUT_FILE" ]; then
             echo "Successfully created '$OUTPUT_FILE'."
        elif [ -f "$OUTPUT_FILE" ]; then
             echo "Warning: Created '$OUTPUT_FILE' but it is empty."
        else
             echo "Error: Failed to create '$OUTPUT_FILE' for tag '$TAG'."
             # Consider whether to continue or exit here depending on severity
        fi
    else
        # This case should ideally not be reached due to checks above, but included for safety
        echo "Info: No files determined for processing for tag '$TAG'. Skipping generation."
    fi

done

echo "--- Documentation build process complete ---"
# Cleanup is handled by the EXIT trap

exit 0


