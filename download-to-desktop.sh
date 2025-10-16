#!/bin/bash

# Download Paris Training Images to Desktop
# Usage: ./download-to-desktop.sh

MODEL_NAME="Paris"
TRAINING_DIR="${MODEL_NAME}_Training"
DESKTOP_DIR="$HOME/Desktop/Paris"

echo "======================================"
echo "Download Training Images to Desktop"
echo "======================================"
echo "Source: $TRAINING_DIR"
echo "Destination: $DESKTOP_DIR"
echo ""

# Check if training folder exists
if [ ! -d "$TRAINING_DIR" ]; then
    echo "Error: Training folder not found: $TRAINING_DIR"
    echo "Run ./face-swap-batch.sh Paris first to generate training images"
    exit 1
fi

# Create desktop folder
mkdir -p "$DESKTOP_DIR"

# Count images
IMAGE_COUNT=$(ls -1 "$TRAINING_DIR"/*.jpg 2>/dev/null | wc -l)
echo "Found $IMAGE_COUNT training image(s)"
echo ""

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "Error: No images found in $TRAINING_DIR"
    exit 1
fi

# Copy and rename images
counter=1
for img in "$TRAINING_DIR"/*.jpg; do
    # Skip README
    if [[ "$img" == *"README"* ]]; then
        continue
    fi

    # New filename: paris1final.jpg, paris2final.jpg, etc.
    new_name="paris${counter}final.jpg"

    echo "[$counter/$IMAGE_COUNT] Copying: $(basename "$img") → $new_name"
    cp "$img" "$DESKTOP_DIR/$new_name"

    ((counter++))
done

echo ""
echo "======================================"
echo "✓ Download Complete!"
echo "======================================"
echo "Location: $DESKTOP_DIR"
echo "Files copied: $((counter-1))"
echo ""
echo "Your Paris training images are ready on your desktop!"
echo "===================================="
