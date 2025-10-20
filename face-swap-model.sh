#!/bin/bash

# Face Swap + Caption Workflow Script with Dynamic Model Support
# Usage: ./face-swap-model.sh <model_name> <source_face.jpg> <target_body.jpg>

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

API_KEY="${API_KEY:-sk_blo63qa2epbwjq4tdgod}"
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
AWS_S3_BUCKET="${AWS_S3_BUCKET:-modelcrew}"
AWS_REGION="${AWS_REGION:-us-east-2}"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <model_name> <source_face.jpg> <target_body.jpg>"
    echo "Example: ./face-swap-model.sh blondie source/blondie-1.png targets/image1.jpg"
    echo ""
    echo "The model_name will be used for:"
    echo "  - Trigger token in captions"
    echo "  - Folder structure: {model_name}/outputs/, dataset/{model_name}/captions/, etc."
    echo "  - S3 structure: s3://bucket/{model_name}/"
    exit 1
fi

MODEL_NAME="$1"
SOURCE_FACE="$2"
TARGET_BODY="$3"

# Convert model name to lowercase for consistency
MODEL_NAME_LOWER=$(echo "$MODEL_NAME" | tr '[:upper:]' '[:lower:]')

# Set trigger token from model name (default to model name)
TRIGGER_TOKEN="${TRIGGER_TOKEN:-$MODEL_NAME_LOWER}"
CLASS_TOKEN="${CLASS_TOKEN:-woman}"

# Generate output filename
TARGET_BASENAME=$(basename "$TARGET_BODY" | sed 's/\.[^.]*$//')
OUTPUT_FILE="${MODEL_NAME}/outputs/faceswapped/${TARGET_BASENAME}_swapped.jpg"

echo "=== MaxStudio Face Swap + Caption Workflow ==="
echo "Model: $MODEL_NAME (trigger: $TRIGGER_TOKEN)"
echo "Source Face: $SOURCE_FACE"
echo "Target Body: $TARGET_BODY"
echo "Output: $OUTPUT_FILE"
echo ""

# Check files exist
if [ ! -f "$SOURCE_FACE" ]; then
    echo "Error: Source face file not found: $SOURCE_FACE"
    exit 1
fi

if [ ! -f "$TARGET_BODY" ]; then
    echo "Error: Target body file not found: $TARGET_BODY"
    exit 1
fi

# Check if output already exists (resume capability)
if [ -f "$OUTPUT_FILE" ]; then
    echo "⚠️  Output file already exists: $OUTPUT_FILE"
    echo "Skipping (resume mode). Delete file to reprocess."
    exit 0
fi

# Create output directories
mkdir -p "${MODEL_NAME}/outputs/faceswapped"
mkdir -p "dataset/${MODEL_NAME}/captions"
mkdir -p "dataset/${MODEL_NAME}/prompts"
mkdir -p "dataset/${MODEL_NAME}/meta"

# Use Python for the entire workflow
python3 << PYEOF
import base64
import json
import requests
import time
import sys
import os
from pathlib import Path
import boto3
from datetime import datetime

API_KEY = "$API_KEY"
ANTHROPIC_API_KEY = "$ANTHROPIC_API_KEY"
MODEL_NAME = "$MODEL_NAME"
TRIGGER_TOKEN = "$TRIGGER_TOKEN"
CLASS_TOKEN = "$CLASS_TOKEN"
SOURCE_FACE = "$SOURCE_FACE"
TARGET_BODY = "$TARGET_BODY"
OUTPUT_FILE = "$OUTPUT_FILE"
AWS_ACCESS_KEY_ID = "$AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY = "$AWS_SECRET_ACCESS_KEY"
AWS_S3_BUCKET = "$AWS_S3_BUCKET"
AWS_REGION = "$AWS_REGION"

# Initialize S3 client
s3_client = boto3.client(
    's3',
    aws_access_key_id=AWS_ACCESS_KEY_ID,
    aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    region_name=AWS_REGION
)

def upload_to_s3(image_data, filename):
    """Upload image to S3 and return public URL"""
    try:
        key = f"{MODEL_NAME}/temp/{datetime.now().strftime('%Y%m%d')}/{filename}"
        s3_client.put_object(
            Bucket=AWS_S3_BUCKET,
            Key=key,
            Body=image_data,
            ContentType='image/jpeg',
            ACL='public-read'
        )
        url = f"https://{AWS_S3_BUCKET}.s3.{AWS_REGION}.amazonaws.com/{key}"
        return url
    except Exception as e:
        print(f"  Error uploading to S3: {e}")
        return None

print("Step 1: Enhancing target image...")
with open(TARGET_BODY, 'rb') as f:
    target_base64 = base64.b64encode(f.read()).decode('utf-8')

response = requests.post(
    'https://api.maxstudio.ai/image-enhancer',
    headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
    json={'image': target_base64}
)

if response.status_code != 200:
    print(f"Error enhancing image: {response.status_code} - {response.text}")
    sys.exit(1)

job_id = response.json()['jobId']
print(f"  Job ID: {job_id}")

# Poll for completion
print("  Polling for completion...")
for i in range(60):
    time.sleep(2)
    status_resp = requests.get(
        f'https://api.maxstudio.ai/image-enhancer/{job_id}',
        headers={'x-api-key': API_KEY}
    )

    if status_resp.status_code == 200:
        data = status_resp.json()
        if data['status'] == 'completed':
            enhanced_base64 = data['result']
            enhanced_bytes = base64.b64decode(enhanced_base64)
            print(f"  ✓ Enhanced ({len(enhanced_bytes)} bytes)")
            break
        elif data['status'] == 'failed':
            print("  ✗ Enhancement failed")
            sys.exit(1)
    else:
        print(f"  Error checking status: {status_resp.status_code}")
        sys.exit(1)
else:
    print("  ✗ Timeout")
    sys.exit(1)

# Upload enhanced image to S3
print("\nStep 1.5: Uploading enhanced image to S3...")
enhanced_url = upload_to_s3(enhanced_bytes, 'enhanced_target.jpg')
if not enhanced_url:
    print("  ✗ Failed to upload to S3")
    sys.exit(1)
print(f"  ✓ Uploaded: {enhanced_url}")

print("\nStep 2: Detecting faces in enhanced image...")
detect_resp = requests.post(
    'https://api.maxstudio.ai/detect-face-image',
    headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
    json={'imageUrl': enhanced_url}
)

if detect_resp.status_code != 200:
    print(f"  Error: {detect_resp.status_code} - {detect_resp.text}")
    sys.exit(1)

detect_data = detect_resp.json()
faces = detect_data.get('detectedFaces', [])
print(f"  ✓ Detected {len(faces)} face(s)")

if not faces:
    print("  ✗ No faces found in target image!")
    sys.exit(1)

face = faces[0]
print(f"  Using face at ({face['x']}, {face['y']}) size {face['width']}x{face['height']}")

# Load and upload source face to S3
print("\nStep 3: Uploading source face to S3...")
with open(SOURCE_FACE, 'rb') as f:
    source_bytes = f.read()
    source_base64 = base64.b64encode(source_bytes).decode('utf-8')

source_url = upload_to_s3(source_bytes, 'source_face.jpg')
if not source_url:
    print(f"  Upload failed, using data URL")
    source_url = f'data:image/jpeg;base64,{source_base64}'
else:
    print(f"  ✓ Uploaded: {source_url}")

print("\nStep 4: Face swapping...")
swap_resp = requests.post(
    'https://api.maxstudio.ai/swap-image',
    headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
    json={
        'mediaUrl': enhanced_url,
        'faces': [{
            'newFace': source_url,
            'originalFace': face
        }]
    }
)

if swap_resp.status_code != 200:
    print(f"  Error: {swap_resp.status_code} - {swap_resp.text}")
    sys.exit(1)

swap_job_id = swap_resp.json()['jobId']
print(f"  Job ID: {swap_job_id}")

print("  Polling for completion...")
for i in range(60):
    time.sleep(3)
    status_resp = requests.get(
        f'https://api.maxstudio.ai/swap-image/{swap_job_id}',
        headers={'x-api-key': API_KEY}
    )

    if status_resp.status_code == 200:
        data = status_resp.json()
        if data['status'] == 'completed':
            swapped_url = data['result']['mediaUrl']
            print(f"  ✓ Swapped: {swapped_url}")

            # Download swapped image
            img_resp = requests.get(swapped_url)
            swapped_bytes = img_resp.content
            break
        elif data['status'] == 'failed':
            print("  ✗ Face swap failed")
            sys.exit(1)
else:
    print("  ✗ Timeout")
    sys.exit(1)

print("\nStep 5: Final enhancement...")
final_base64 = base64.b64encode(swapped_bytes).decode('utf-8')

final_resp = requests.post(
    'https://api.maxstudio.ai/image-enhancer',
    headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
    json={'image': final_base64}
)

if final_resp.status_code != 200:
    print(f"  Error: {final_resp.status_code} - {final_resp.text}")
    sys.exit(1)

final_job_id = final_resp.json()['jobId']
print(f"  Job ID: {final_job_id}")

print("  Polling for completion...")
for i in range(60):
    time.sleep(2)
    status_resp = requests.get(
        f'https://api.maxstudio.ai/image-enhancer/{final_job_id}',
        headers={'x-api-key': API_KEY}
    )

    if status_resp.status_code == 200:
        data = status_resp.json()
        if data['status'] == 'completed':
            final_base64 = data['result']
            final_bytes = base64.b64decode(final_base64)

            # Save final result
            with open(OUTPUT_FILE, 'wb') as f:
                f.write(final_bytes)

            print(f"  ✓ Final image saved: {OUTPUT_FILE} ({len(final_bytes)} bytes)")
            break
        elif data['status'] == 'failed':
            print("  ✗ Final enhancement failed")
            sys.exit(1)
else:
    print("  ✗ Timeout")
    sys.exit(1)

# Step 6: Generate caption and prompt with Anthropic
print("\nStep 6: Generating caption and prompt with Anthropic...")

# Prepare output paths (model-specific)
captions_dir = Path(f'dataset/{MODEL_NAME}/captions')
prompts_dir = Path(f'dataset/{MODEL_NAME}/prompts')
meta_dir = Path(f'dataset/{MODEL_NAME}/meta')

captions_dir.mkdir(parents=True, exist_ok=True)
prompts_dir.mkdir(parents=True, exist_ok=True)
meta_dir.mkdir(parents=True, exist_ok=True)

output_path = Path(OUTPUT_FILE)
basename = output_path.stem

headers = {
    'x-api-key': ANTHROPIC_API_KEY,
    'anthropic-version': '2023-06-01',
    'content-type': 'application/json'
}

prompt_text = f"""Analyze this image and provide detailed information in JSON format.

Requirements:
1. caption: A concise caption (max 25 words) that MUST start with "{TRIGGER_TOKEN} {CLASS_TOKEN}, " followed by description of pose, expression, outfit, and setting.
2. recreation_prompt: A detailed prompt (40-80 words) describing the exact photography setup - camera angle, lens type, lighting (natural/artificial/golden hour/etc), mood, color grading, composition, depth of field, and any photographic techniques visible.
3. style: An array of 5-12 style keywords (e.g., ["portrait", "natural lighting", "bokeh", "warm tones"])
4. sfw: Boolean indicating if image is safe for work
5. ar: Aspect ratio as string (e.g., "1:1", "4:5", "3:4", "9:16", "16:9")

Return ONLY valid JSON with these exact keys: caption, recreation_prompt, style, sfw, ar

Example:
{{
  "caption": "{TRIGGER_TOKEN} {CLASS_TOKEN}, sitting in car, casual blue top, soft smile, natural daylight",
  "recreation_prompt": "Portrait photograph taken in car interior with natural window light from left side. Shot with 50mm lens at f/1.8 creating soft bokeh background. Soft, diffused daylight creates gentle shadows. Warm color temperature around 5500K. Shallow depth of field isolates subject. Natural, candid pose looking at camera. Instagram-style color grading with lifted shadows and slightly desaturated tones.",
  "style": ["portrait", "natural light", "bokeh", "warm tones", "car interior", "candid", "shallow dof", "soft lighting"],
  "sfw": true,
  "ar": "4:5"
}}"""

payload = {
    'model': 'claude-3-5-sonnet-20241022',
    'max_tokens': 1024,
    'messages': [{
        'role': 'user',
        'content': [{
            'type': 'image',
            'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': final_base64
            }
        }, {
            'type': 'text',
            'text': prompt_text
        }]
    }]
}

try:
    caption_resp = requests.post(
        'https://api.anthropic.com/v1/messages',
        headers=headers,
        json=payload,
        timeout=60
    )

    if caption_resp.status_code == 200:
        result = caption_resp.json()
        content = result['content'][0]['text']

        # Parse JSON from response (remove markdown code blocks if present)
        if '```json' in content:
            content = content.split('```json')[1].split('```')[0].strip()
        elif content.startswith('{'):
            pass  # Already JSON
        else:
            # Try to extract JSON from markdown
            import re
            match = re.search(r'\{[^}]+\}', content, re.DOTALL)
            if match:
                content = match.group(0)

        metadata = json.loads(content)
        print(f"  ✓ Caption: {metadata['caption'][:50]}...")
        print(f"  ✓ Style: {', '.join(metadata['style'][:3])}...")
    else:
        print(f"  ⚠ API error {caption_resp.status_code}, using fallback")
        metadata = {
            'caption': f'{TRIGGER_TOKEN} {CLASS_TOKEN}, portrait photograph',
            'recreation_prompt': 'Professional portrait photograph with natural lighting and shallow depth of field.',
            'style': ['portrait', 'natural lighting'],
            'sfw': True,
            'ar': '4:5'
        }
except Exception as e:
    print(f"  ⚠ Error generating caption: {e}, using fallback and continuing...")
    metadata = {
        'caption': f'{TRIGGER_TOKEN} {CLASS_TOKEN}, portrait photograph',
        'recreation_prompt': 'Professional portrait photograph with natural lighting and shallow depth of field.',
        'style': ['portrait', 'natural lighting'],
        'sfw': True,
        'ar': '4:5'
    }

# Save caption and prompt
caption_path = captions_dir / f"{basename}.txt"
caption_path.write_text(metadata['caption'])
print(f"  ✓ Saved caption: {caption_path}")

prompt_path = prompts_dir / f"{basename}.prompt.txt"
prompt_path.write_text(metadata['recreation_prompt'])
print(f"  ✓ Saved prompt: {prompt_path}")

# Save metadata
meta_path = meta_dir / 'meta.jsonl'
meta_entry = {
    'model': MODEL_NAME,
    'path': OUTPUT_FILE,
    'caption': metadata['caption'],
    'prompt': metadata['recreation_prompt'],
    'style': metadata['style'],
    'ar': metadata['ar'],
    'source_face': SOURCE_FACE,
    'target_body': TARGET_BODY,
    'notes': 'faceswap + enhance + caption v2'
}

with open(meta_path, 'a') as f:
    f.write(json.dumps(meta_entry) + '\n')

print(f"  ✓ Saved metadata: {meta_path}")

print("\n=== COMPLETE ===")
print(f"Model: {MODEL_NAME}")
print(f"Swapped image: {OUTPUT_FILE}")
print(f"Caption: {metadata['caption']}")
sys.exit(0)

PYEOF
