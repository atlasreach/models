#!/bin/bash

# Test Multiple Face Options on Sample Bodies
# Usage: ./test-faces.sh

API_KEY="sk_blo63qa2epbwjq4tdgod"

echo "======================================"
echo "Face Swap Test - Compare Face Options"
echo "======================================"
echo ""
echo "Testing 3 Paris faces on 3 body images"
echo "Total combinations: 9 test images"
echo ""

# Create test output folder
mkdir -p Paris_Test_Results

python3 << PYEOF
import base64
import requests
import time
import os
from pathlib import Path

API_KEY = "$API_KEY"
OUTPUT_DIR = "Paris_Test_Results"

# Paris face options (3 source faces to test)
FACES = [
    ("generated-image (3).png", "ParisA"),
    ("generated-image (1).png", "ParisB"),
    ("generated-image (1).png", "ParisC")  # Note: duplicate filename, using different label
]

# Test body images (3 bodies to swap Paris faces onto)
BODIES = [
    ("max-studio-creation-1760638392560.jpeg", "Body1"),
    ("max-studio-creation-1760638603307.jpeg", "Body2"),
    ("max-studio-creation-1760638490128.jpeg", "Body3")
]

def upload_image(file_path):
    """Upload image to AWS S3 and return public URL"""
    import boto3
    from pathlib import Path

    # AWS credentials - load from environment
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
    """Enhance image"""
    resp = requests.post(
        'https://api.maxstudio.ai/image-enhancer',
        headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
        json={'image': base64_image}
    )
    if resp.status_code != 200:
        return None
    job_id = resp.json()['jobId']

    for i in range(60):
        time.sleep(2)
        status = requests.get(f'https://api.maxstudio.ai/image-enhancer/{job_id}', headers={'x-api-key': API_KEY}).json()
        if status['status'] == 'completed':
            return status['result']
        elif status['status'] == 'failed':
            return None
    return None

def detect_faces(image_url):
    """Detect faces"""
    resp = requests.post(
        'https://api.maxstudio.ai/detect-face-image',
        headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
        json={'imageUrl': image_url}
    )
    if resp.status_code == 200:
        return resp.json().get('detectedFaces', [])
    return []

def face_swap(target_url, source_url, face_coords):
    """Face swap"""
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
        print(f"    API Error: {resp.status_code} - {resp.text}")
        return None
    job_id = resp.json()['jobId']

    for i in range(90):
        time.sleep(3)
        status_resp = requests.get(f'https://api.maxstudio.ai/swap-image/{job_id}', headers={'x-api-key': API_KEY})
        if status_resp.status_code != 200:
            continue
        status = status_resp.json()
        if status.get('status') == 'completed':
            return status['result']['mediaUrl']
        elif status.get('status') == 'failed':
            print(f"    Job failed: {status}")
            return None
    return None

# Cache uploaded body URLs to save time
body_cache = {}

test_num = 0
total_tests = len(FACES) * len(BODIES)

for body_file, body_label in BODIES:
    # Upload body once (skip enhancement for testing speed)
    if body_file not in body_cache:
        print(f"\n{'='*60}")
        print(f"Preparing {body_label}: {body_file}")
        print(f"{'='*60}")

        print("  [1/2] Uploading...")
        body_url = upload_image(body_file)
        if not body_url:
            print("  ✗ Upload failed, skipping this body")
            continue
        print(f"  ✓ {body_url}")

        print("  [2/2] Detecting faces...")
        faces = detect_faces(body_url)
        if not faces:
            print("  ⚠ API detection failed, using estimated coordinates")
            # Use estimated face coordinates for portrait photos
            # Assuming ~920x1380 image, face typically in upper center
            faces = [{'x': 300, 'y': 100, 'width': 350, 'height': 450}]
        else:
            print(f"  ✓ Found {len(faces)} face(s)")

        body_cache[body_file] = {'url': body_url, 'face': faces[0], 'label': body_label}

    # Test each Paris face on this body
    for face_file, face_label in FACES:
        test_num += 1

        print(f"\n{'='*60}")
        print(f"Test {test_num}/{total_tests}: {face_label} on {body_cache[body_file]['label']}")
        print(f"{'='*60}")

        try:
            # Upload Paris face
            print(f"  [1/2] Uploading {face_file}...")
            paris_url = upload_image(face_file)
            if not paris_url:
                print("  ✗ Upload failed")
                continue
            print(f"  ✓ {paris_url}")

            # Swap
            print("  [2/2] Swapping faces...")
            swapped_url = face_swap(body_cache[body_file]['url'], paris_url, body_cache[body_file]['face'])
            if not swapped_url:
                print("  ✗ Swap failed")
                continue
            print(f"  ✓ Swapped")

            # Download result with clear naming: FaceLabel_BodyLabel.jpg
            img = requests.get(swapped_url).content
            output_name = f"{face_label}_on_{body_cache[body_file]['label']}.jpg"
            output_path = Path(OUTPUT_DIR) / output_name

            with open(output_path, 'wb') as f:
                f.write(img)

            print(f"  ✓✓✓ SAVED: {output_path} ({len(img)} bytes)")

        except Exception as e:
            print(f"  ✗ ERROR: {str(e)}")
            continue

print(f"\n{'='*60}")
print(f"TESTING COMPLETE")
print(f"{'='*60}")
print(f"Check results in: {OUTPUT_DIR}/")
print(f"Compare the images to pick your favorite Paris face!")
print(f"{'='*60}")

PYEOF

echo ""
echo "======================================"
echo "✓ Test Complete!"
echo "======================================"
echo "Results in: Paris_Test_Results/"
echo ""
echo "Review the images and pick which Paris face looks best."
echo "Then run the full batch with that face!"
echo "======================================"
