#!/bin/bash

# Batch Face Swap for AI Model Training
# Usage: ./face-swap-batch.sh ModelName
# Example: ./face-swap-batch.sh Paris

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <ModelName>"
    echo "Example: $0 Paris"
    echo ""
    echo "Folder structure required:"
    echo "  ModelName/"
    echo "    source.jpg          # The AI model's face"
    echo "    targets/            # Body images to swap onto"
    echo "    output/             # Results will be saved here"
    exit 1
fi

MODEL_NAME="$1"
API_KEY="sk_blo63qa2epbwjq4tdgod"

SOURCE_DIR="${MODEL_NAME}"
SOURCE_FACE="${SOURCE_DIR}/source.jpg"
TARGETS_DIR="${SOURCE_DIR}/targets"
OUTPUT_DIR="${MODEL_NAME}_Training"

# Validate structure
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Folder '$SOURCE_DIR' not found"
    exit 1
fi

if [ ! -f "$SOURCE_FACE" ]; then
    echo "Error: Source face not found: $SOURCE_FACE"
    exit 1
fi

if [ ! -d "$TARGETS_DIR" ]; then
    echo "Error: Targets folder not found: $TARGETS_DIR"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "======================================"
echo "AI Model Training Image Generator"
echo "======================================"
echo "Model: $MODEL_NAME"
echo "Source Face: $SOURCE_FACE"
echo "Targets: $TARGETS_DIR"
echo "Output: $OUTPUT_DIR"
echo ""

# Count target images
TARGET_COUNT=$(ls -1 "$TARGETS_DIR"/*.{jpg,jpeg,png,JPG,JPEG,PNG} 2>/dev/null | wc -l)
echo "Found $TARGET_COUNT target image(s)"
echo ""

if [ "$TARGET_COUNT" -eq 0 ]; then
    echo "Error: No images found in $TARGETS_DIR"
    exit 1
fi

# Process with Python
python3 << PYEOF
import base64
import requests
import time
import os
import sys
from pathlib import Path

API_KEY = "$API_KEY"
MODEL_NAME = "$MODEL_NAME"
SOURCE_FACE = "$SOURCE_FACE"
TARGETS_DIR = "$TARGETS_DIR"
OUTPUT_DIR = "$OUTPUT_DIR"

def upload_image(file_path):
    """Upload image to AWS S3 and return public URL"""
    import boto3
    from pathlib import Path

    # AWS credentials - load from environment or .aws-credentials file
    import os
    aws_key = os.getenv('AWS_ACCESS_KEY_ID', 'YOUR_AWS_ACCESS_KEY')
    aws_secret = os.getenv('AWS_SECRET_ACCESS_KEY', 'YOUR_AWS_SECRET_KEY')
    aws_region = os.getenv('AWS_REGION', 'us-east-2')
    bucket_name = os.getenv('AWS_BUCKET_NAME', 'modelcrew')

    s3_client = boto3.client(
        's3',
        aws_access_key_id=aws_key,
        aws_secret_access_key=aws_secret,
        region_name=aws_region
    )
    file_name = Path(file_path).name

    try:
        # Upload with public-read ACL
        s3_client.upload_file(
            file_path,
            bucket_name,
            file_name,
            ExtraArgs={'ACL': 'public-read', 'ContentType': 'image/jpeg'}
        )

        # Return public URL
        url = f"https://{bucket_name}.s3.us-east-2.amazonaws.com/{file_name}"
        return url
    except Exception as e:
        print(f"    Upload error: {e}")
        return None

def enhance_image(base64_image):
    """Enhance image and return base64 result"""
    resp = requests.post(
        'https://api.maxstudio.ai/image-enhancer',
        headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
        json={'image': base64_image}
    )

    if resp.status_code != 200:
        return None

    job_id = resp.json()['jobId']

    # Poll for completion
    for i in range(60):
        time.sleep(2)
        status_resp = requests.get(
            f'https://api.maxstudio.ai/image-enhancer/{job_id}',
            headers={'x-api-key': API_KEY}
        )

        if status_resp.status_code == 200:
            data = status_resp.json()
            if data['status'] == 'completed':
                return data['result']
            elif data['status'] == 'failed':
                return None

    return None

def detect_faces(image_url):
    """Detect faces and return coordinates"""
    resp = requests.post(
        'https://api.maxstudio.ai/detect-face-image',
        headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
        json={'imageUrl': image_url}
    )

    if resp.status_code == 200:
        return resp.json().get('detectedFaces', [])
    return []

def face_swap(target_url, source_url, face_coords):
    """Perform face swap"""
    resp = requests.post(
        'https://api.maxstudio.ai/swap-image',
        headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
        json={
            'mediaUrl': target_url,
            'faces': [{
                'newFace': source_url,
                'originalFace': face_coords
            }]
        }
    )

    if resp.status_code != 200:
        return None

    job_id = resp.json()['jobId']

    # Poll for completion
    for i in range(90):
        time.sleep(3)
        status_resp = requests.get(
            f'https://api.maxstudio.ai/swap-image/{job_id}',
            headers={'x-api-key': API_KEY}
        )

        if status_resp.status_code == 200:
            data = status_resp.json()
            if data['status'] == 'completed':
                return data['result']['mediaUrl']
            elif data['status'] == 'failed':
                return None

    return None

# Upload source face once
print(f"[0/4] Uploading source face: {SOURCE_FACE}")
source_url = upload_image(SOURCE_FACE)
if not source_url:
    print("  ✗ Failed to upload source face")
    sys.exit(1)
print(f"  ✓ {source_url}")

# Get all target images
target_files = []
for ext in ['jpg', 'jpeg', 'png', 'JPG', 'JPEG', 'PNG']:
    target_files.extend(Path(TARGETS_DIR).glob(f'*.{ext}'))

total = len(target_files)
success_count = 0
failed_count = 0

for idx, target_file in enumerate(target_files, 1):
    print(f"\n{'='*60}")
    print(f"Processing {idx}/{total}: {target_file.name}")
    print(f"{'='*60}")

    try:
        # Step 1: Enhance target
        print("[1/4] Enhancing target image...")
        with open(target_file, 'rb') as f:
            target_base64 = base64.b64encode(f.read()).decode('utf-8')

        enhanced_base64 = enhance_image(target_base64)
        if not enhanced_base64:
            print("  ✗ Enhancement failed")
            failed_count += 1
            continue
        print("  ✓ Enhanced")

        # Step 2: Upload enhanced target
        print("[2/4] Uploading enhanced target...")
        # Save to temp file and upload
        temp_path = f'/tmp/enhanced_{idx}.jpg'
        with open(temp_path, 'wb') as f:
            f.write(base64.b64decode(enhanced_base64))

        enhanced_url = upload_image(temp_path)
        os.remove(temp_path)

        if not enhanced_url:
            print("  ✗ Upload failed")
            failed_count += 1
            continue
        print(f"  ✓ {enhanced_url}")

        # Step 3: Detect faces
        print("[3/4] Detecting faces...")
        faces = detect_faces(enhanced_url)
        if not faces:
            print("  ✗ No faces detected")
            failed_count += 1
            continue
        print(f"  ✓ Found {len(faces)} face(s)")

        # Step 4: Face swap
        print("[4/4] Swapping faces...")
        swapped_url = face_swap(enhanced_url, source_url, faces[0])
        if not swapped_url:
            print("  ✗ Face swap failed")
            failed_count += 1
            continue
        print(f"  ✓ Swapped: {swapped_url}")

        # Step 5: Final enhancement
        print("[5/5] Final enhancement...")
        swapped_img = requests.get(swapped_url).content
        swapped_base64 = base64.b64encode(swapped_img).decode('utf-8')

        final_base64 = enhance_image(swapped_base64)
        if not final_base64:
            print("  ⚠ Final enhancement failed, using swapped image")
            final_bytes = swapped_img
        else:
            final_bytes = base64.b64decode(final_base64)
            print("  ✓ Final enhanced")

        # Save result with model naming: paris1final.jpg, paris2final.jpg, etc.
        output_filename = f"{MODEL_NAME.lower()}{idx}final.jpg"
        output_path = Path(OUTPUT_DIR) / output_filename
        with open(output_path, 'wb') as f:
            f.write(final_bytes)

        print(f"  ✓✓✓ SAVED: {output_path} ({len(final_bytes)} bytes)")
        success_count += 1

    except Exception as e:
        print(f"  ✗ ERROR: {str(e)}")
        failed_count += 1
        continue

print(f"\n{'='*60}")
print(f"COMPLETE")
print(f"{'='*60}")
print(f"Total: {total}")
print(f"Success: {success_count}")
print(f"Failed: {failed_count}")
print(f"Output: {OUTPUT_DIR}")

# Create README in output folder
readme_path = Path(OUTPUT_DIR) / 'README.txt'
with open(readme_path, 'w') as f:
    f.write(f"{'='*60}\n")
    f.write(f"{MODEL_NAME} - AI Training Dataset\n")
    f.write(f"{'='*60}\n\n")
    f.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
    f.write(f"Source Face: {SOURCE_FACE}\n")
    f.write(f"Total Images Processed: {total}\n")
    f.write(f"Successfully Created: {success_count}\n")
    f.write(f"Failed: {failed_count}\n\n")
    f.write(f"These images are ready for AI model training.\n")
    f.write(f"Each image has been:\n")
    f.write(f"  1. Enhanced for quality\n")
    f.write(f"  2. Face swapped with {MODEL_NAME}'s face\n")
    f.write(f"  3. Enhanced again for final quality\n\n")
    f.write(f"{'='*60}\n")

print(f"\n✓ Created README: {readme_path}")

PYEOF

echo ""
echo "======================================"
echo "✓✓✓ PROCESSING COMPLETE ✓✓✓"
echo "======================================"
echo "Model: $MODEL_NAME"
echo "Training images saved to: $OUTPUT_DIR"
echo ""
echo "You can now use these images to train your AI model!"
echo "===================================="
