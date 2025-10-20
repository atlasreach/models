#!/usr/bin/env python3
"""
Post face-swap captioning script using Anthropic Claude API.
Generates captions and detailed recreation prompts for LoRA training.
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Dict, Optional
import base64

try:
    from PIL import Image
    import imagehash
    import requests
except ImportError:
    print("Error: Missing dependencies. Run: pip install Pillow imagehash requests")
    sys.exit(1)


def get_phash(image_path: Path) -> str:
    """Generate perceptual hash for image deduplication."""
    img = Image.open(image_path)
    return str(imagehash.phash(img, hash_size=8))


def normalize_image(input_path: Path, output_path: Path, quality: int = 92):
    """Convert image to JPEG format with specified quality."""
    img = Image.open(input_path)

    # Convert RGBA to RGB if necessary
    if img.mode in ('RGBA', 'LA', 'P'):
        background = Image.new('RGB', img.size, (255, 255, 255))
        if img.mode == 'P':
            img = img.convert('RGBA')
        background.paste(img, mask=img.split()[-1] if img.mode in ('RGBA', 'LA') else None)
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')

    img.save(output_path, 'JPEG', quality=quality)
    return output_path


def call_anthropic_api(image_path: Path, api_key: str, trigger_token: str, class_token: str) -> Optional[Dict]:
    """Call Anthropic API to generate caption and recreation prompt."""

    # Read and encode image
    with open(image_path, 'rb') as f:
        image_data = base64.standard_b64encode(f.read()).decode('utf-8')

    # Determine media type
    ext = image_path.suffix.lower()
    media_type_map = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.webp': 'image/webp'
    }
    media_type = media_type_map.get(ext, 'image/jpeg')

    # Construct API request
    headers = {
        'x-api-key': api_key,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json'
    }

    prompt = f"""Analyze this image and provide detailed information in JSON format.

Requirements:
1. caption: A concise caption (max 25 words) that MUST start with "{trigger_token} {class_token}, " followed by description of pose, expression, outfit, and setting.
2. recreation_prompt: A detailed prompt (40-80 words) describing the exact photography setup - camera angle, lens type, lighting (natural/artificial/golden hour/etc), mood, color grading, composition, depth of field, and any photographic techniques visible.
3. style: An array of 5-12 style keywords (e.g., ["portrait", "natural lighting", "bokeh", "warm tones"])
4. sfw: Boolean indicating if image is safe for work
5. ar: Aspect ratio as string (e.g., "1:1", "4:5", "3:4", "9:16", "16:9")

Return ONLY valid JSON with these exact keys: caption, recreation_prompt, style, sfw, ar

Example:
{{
  "caption": "{trigger_token} {class_token}, sitting in car, casual blue top, soft smile, natural daylight",
  "recreation_prompt": "Portrait photograph taken in car interior with natural window light from left side. Shot with 50mm lens at f/1.8 creating soft bokeh background. Soft, diffused daylight creates gentle shadows. Warm color temperature around 5500K. Shallow depth of field isolates subject. Natural, candid pose looking at camera. Instagram-style color grading with lifted shadows and slightly desaturated tones.",
  "style": ["portrait", "natural light", "bokeh", "warm tones", "car interior", "candid", "shallow dof", "soft lighting"],
  "sfw": true,
  "ar": "4:5"
}}"""

    payload = {
        'model': 'claude-3-5-sonnet-20241022',
        'max_tokens': 1024,
        'messages': [
            {
                'role': 'user',
                'content': [
                    {
                        'type': 'image',
                        'source': {
                            'type': 'base64',
                            'media_type': media_type,
                            'data': image_data
                        }
                    },
                    {
                        'type': 'text',
                        'text': prompt
                    }
                ]
            }
        ]
    }

    try:
        response = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers=headers,
            json=payload,
            timeout=60
        )
        print(f"  → Response status: {response.status_code}")

        # Debug: print status and response
        if response.status_code != 200:
            print(f"  ✗ API Error {response.status_code}: {response.text[:500]}")
            return None

        response.raise_for_status()

        # Check if response is empty
        if not response.text:
            print(f"  ✗ Empty response from API")
            return None

        print(f"  → Response text length: {len(response.text)}")
        if len(response.text) > 0:
            print(f"  → First 200 chars: {response.text[:200]}")

        try:
            result = response.json()
        except json.JSONDecodeError as e:
            print(f"  ✗ Failed to parse JSON: {e}")
            print(f"  ✗ Response text: {response.text[:500]}")
            return None

        content = result['content'][0]['text']

        # Try to parse JSON from response
        # Sometimes Claude wraps JSON in markdown code blocks
        if '```json' in content:
            content = content.split('```json')[1].split('```')[0].strip()
        elif '```' in content:
            content = content.split('```')[1].split('```')[0].strip()

        data = json.loads(content)

        # Validate required keys
        required = ['caption', 'recreation_prompt', 'style', 'sfw', 'ar']
        if all(k in data for k in required):
            return data
        else:
            print(f"Warning: API response missing required keys: {data}")
            return None

    except Exception as e:
        print(f"Error calling Anthropic API: {e}")
        return None


def fallback_caption(image_path: Path, trigger_token: str, class_token: str) -> Dict:
    """Generate rule-based caption when API is unavailable."""
    img = Image.open(image_path)
    width, height = img.size

    # Determine aspect ratio
    ratio = width / height
    if ratio > 1.1:
        ar = "16:9"
    elif ratio < 0.9:
        ar = "9:16"
    else:
        ar = "1:1"

    return {
        'caption': f'{trigger_token} {class_token}, portrait photograph',
        'recreation_prompt': 'Professional portrait photograph with natural lighting and shallow depth of field.',
        'style': ['portrait', 'natural lighting'],
        'sfw': True,
        'ar': ar
    }


def process_image(
    input_path: Path,
    clean_dir: Path,
    captions_dir: Path,
    prompts_dir: Path,
    meta_path: Path,
    api_key: Optional[str],
    trigger_token: str,
    class_token: str
):
    """Process a single image: normalize, caption, and save metadata."""

    print(f"Processing: {input_path.name}")

    # Generate phash for deduplication
    phash = get_phash(input_path)

    # Create clean image filename
    stem = input_path.stem
    clean_filename = f"{stem}-{phash}.jpg"
    clean_path = clean_dir / clean_filename

    # Normalize to JPEG
    normalize_image(input_path, clean_path)
    print(f"  ✓ Normalized to: {clean_path}")

    # Generate caption and prompt (use normalized image for API)
    if api_key:
        print(f"  → Calling Anthropic API...")
        metadata = call_anthropic_api(clean_path, api_key, trigger_token, class_token)
        if not metadata:
            print(f"  ⚠ API failed, using fallback caption")
            metadata = fallback_caption(input_path, trigger_token, class_token)
    else:
        print(f"  ⚠ No API key, using fallback caption")
        metadata = fallback_caption(input_path, trigger_token, class_token)

    # Write caption file
    caption_path = captions_dir / f"{clean_path.stem}.txt"
    caption_path.write_text(metadata['caption'])
    print(f"  ✓ Caption: {caption_path}")

    # Write prompt file
    prompt_path = prompts_dir / f"{clean_path.stem}.prompt.txt"
    prompt_path.write_text(metadata['recreation_prompt'])
    print(f"  ✓ Prompt: {prompt_path}")

    # Append to meta.jsonl
    meta_entry = {
        'path': str(clean_path.relative_to(clean_dir.parent)),
        'caption': metadata['caption'],
        'prompt': metadata['recreation_prompt'],
        'style': metadata['style'],
        'ar': metadata['ar'],
        'phash': phash,
        'source': str(input_path),
        'notes': 'faceswap output v1'
    }

    with open(meta_path, 'a') as f:
        f.write(json.dumps(meta_entry) + '\n')

    print(f"  ✓ Metadata saved\n")


def main():
    parser = argparse.ArgumentParser(description='Generate captions and prompts for face-swapped images')
    parser.add_argument('--images-dir', type=str, required=True, help='Directory containing images to process')
    parser.add_argument('--trigger', type=str, help='Trigger token (default: from env TRIGGER_TOKEN)')
    parser.add_argument('--class-token', type=str, help='Class token (default: from env CLASS_TOKEN)')
    parser.add_argument('--limit', type=int, help='Limit processing to N images (for testing)')

    args = parser.parse_args()

    # Get configuration
    api_key = os.getenv('ANTHROPIC_API_KEY')
    trigger_token = args.trigger or os.getenv('TRIGGER_TOKEN', 'blondie')
    class_token = args.class_token or os.getenv('CLASS_TOKEN', 'woman')

    if not api_key:
        print("Warning: ANTHROPIC_API_KEY not set. Using fallback captions.")

    # Set up directories
    images_dir = Path(args.images_dir)
    if not images_dir.exists():
        print(f"Error: Images directory not found: {images_dir}")
        sys.exit(1)

    clean_dir = Path('dataset/clean')
    captions_dir = Path('dataset/captions')
    prompts_dir = Path('dataset/prompts')
    meta_dir = Path('dataset/meta')

    # Create directories
    clean_dir.mkdir(parents=True, exist_ok=True)
    captions_dir.mkdir(parents=True, exist_ok=True)
    prompts_dir.mkdir(parents=True, exist_ok=True)
    meta_dir.mkdir(parents=True, exist_ok=True)

    meta_path = meta_dir / 'meta.jsonl'

    # Find all images
    image_extensions = {'.jpg', '.jpeg', '.png', '.webp'}
    image_files = [
        f for f in images_dir.iterdir()
        if f.is_file() and f.suffix.lower() in image_extensions
    ]

    if args.limit:
        image_files = image_files[:args.limit]

    print(f"\n{'='*60}")
    print(f"Post-Swap Captioning Pipeline")
    print(f"{'='*60}")
    print(f"Images directory: {images_dir}")
    print(f"Found {len(image_files)} images")
    print(f"Trigger token: {trigger_token}")
    print(f"Class token: {class_token}")
    print(f"API key: {'✓ Set' if api_key else '✗ Not set'}")
    print(f"{'='*60}\n")

    # Process each image
    for image_path in image_files:
        try:
            process_image(
                image_path,
                clean_dir,
                captions_dir,
                prompts_dir,
                meta_path,
                api_key,
                trigger_token,
                class_token
            )
        except Exception as e:
            print(f"Error processing {image_path}: {e}\n")
            continue

    print(f"\n{'='*60}")
    print(f"Processing complete!")
    print(f"Clean images: {clean_dir}")
    print(f"Captions: {captions_dir}")
    print(f"Prompts: {prompts_dir}")
    print(f"Metadata: {meta_path}")
    print(f"{'='*60}\n")


if __name__ == '__main__':
    main()
