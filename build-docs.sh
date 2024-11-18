#!/bin/bash
LLM_DOCS="$PWD/llm"
mkdir -p "$LLM_DOCS"

rm -rf /tmp/llm
git clone https://github.com/simonw/llm /tmp/llm
cd /tmp/llm || exit

# Loop through each tag in the repository
for TAG in $(git tag); do
    # Check if TAG.txt already exists, and skip if it does
    if [ -f "$LLM_DOCS/$TAG.txt" ]; then
        echo "Skipping $TAG, $TAG.txt already exists."
        continue
    fi

    if ! git checkout "$TAG" > /dev/null 2>&1; then
        echo "Warning: Failed to checkout tag $TAG, skipping..."
        continue
    fi

    # Check if any docs/*.md files exist
    if ls docs/*.md &>/dev/null; then
        # Run the command and output to TAG.txt
        files-to-prompt docs/*.md -c > "$LLM_DOCS/$TAG.txt"
    fi
done
