#!/bin/bash

SOURCE="Blondie/source/blondie-source-1.png"
TARGET_DIR="Blondie/targets"

echo "=== Batch Face Swap Processing ==="
echo "Source: $SOURCE"
echo ""

# Count total images
total=$(ls "$TARGET_DIR"/*.jpg 2>/dev/null | wc -l)
count=0
success=0
failed=0

echo "Found $total images to process"
echo "Started: $(date)"
echo ""

# Process each image
for img in "$TARGET_DIR"/*.jpg; do
    count=$((count + 1))
    basename=$(basename "$img")
    output_file="Blondie/outputs/faceswapped/${basename%.jpg}_swapped.jpg"

    # Skip if already processed
    if [ -f "$output_file" ]; then
        echo "[$count/$total] SKIP: Already processed $basename"
        success=$((success + 1))
        continue
    fi

    echo "[$count/$total] Processing: $basename"

    # Run the face-swap workflow
    if ./face-swap-with-caption.sh "$SOURCE" "$img"; then
        success=$((success + 1))
        echo "  ✓ Success"
    else
        failed=$((failed + 1))
        echo "  ✗ Failed"
    fi
    echo ""
done

echo ""
echo "=== BATCH COMPLETE ==="
echo "Finished: $(date)"
echo "Total: $total"
echo "Success: $success"
echo "Failed: $failed"
