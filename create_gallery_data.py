#!/usr/bin/env python3
"""
Scan generated images and create gallery data JSON
Run this after generating images to populate the gallery viewer
"""

import os
import json
from pathlib import Path
import re

def scan_images(output_dir="/workspace/ComfyUI/output"):
    """Scan output directory for generated images"""
    images = []

    image_files = list(Path(output_dir).glob("blondie*.png"))

    for img_path in image_files:
        filename = img_path.name

        # Parse metadata from filename
        data = {
            "filename": filename,
            "path": str(img_path),
            "checkpoint": None,
            "strength": None,
            "prompt": None,
            "category": "unknown"
        }

        # Extract checkpoint from filename
        if "checkpoint_" in filename:
            match = re.search(r'checkpoint_(\d+)', filename)
            if match:
                data["checkpoint"] = match.group(1)
                data["category"] = "checkpoint"

        # Extract strength from filename
        if "strength_" in filename:
            match = re.search(r'strength_(\d+)', filename)
            if match:
                data["strength"] = int(match.group(1)) / 10
                data["category"] = "strength"

        # Extract prompt category from filename
        if "prompt_" in filename:
            match = re.search(r'prompt_(\w+)', filename)
            if match:
                data["prompt"] = match.group(1)
                data["category"] = "prompt"

        # Batch generation
        if "_p" in filename and "_v" in filename:
            match = re.search(r'_p(\d+)_v(\d+)', filename)
            if match:
                data["prompt"] = f"Prompt {match.group(1)}"
                data["category"] = "batch"

        images.append(data)

    return images

def main():
    print("🔍 Scanning for generated images...")

    images = scan_images()

    print(f"✅ Found {len(images)} images")

    # Save to JSON
    output_file = "image_data.json"
    with open(output_file, 'w') as f:
        json.dump(images, f, indent=2)

    print(f"📊 Gallery data saved to: {output_file}")
    print(f"\n🌐 Now open gallery_viewer.html in your browser!")

    # Print summary
    categories = {}
    for img in images:
        cat = img.get("category", "unknown")
        categories[cat] = categories.get(cat, 0) + 1

    print("\n📈 Summary:")
    for cat, count in categories.items():
        print(f"   {cat}: {count} images")

if __name__ == "__main__":
    main()
