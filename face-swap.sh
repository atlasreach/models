#!/bin/bash

# Face Swap Workflow Script
# Usage: ./face-swap.sh paris_face.jpg target_body.jpg output_final.jpg

API_KEY="bae0c714-f708-4d00-99b3-b740d0af3fda"

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <paris_face.jpg> <target_body.jpg> <output_final.jpg>"
    echo "Example: ./face-swap.sh openart-image_pSzCYSeQ_1760591175637_raw.jpg IMG_0149.jpg result.jpg"
    exit 1
fi

PARIS_FACE="$1"
TARGET_BODY="$2"
OUTPUT_FILE="$3"

echo "=== MaxStudio Face Swap Workflow ==="
echo "Paris Face: $PARIS_FACE"
echo "Target Body: $TARGET_BODY"
echo "Output: $OUTPUT_FILE"
echo ""

# Check files exist
if [ ! -f "$PARIS_FACE" ]; then
    echo "Error: Paris face file not found: $PARIS_FACE"
    exit 1
fi

if [ ! -f "$TARGET_BODY" ]; then
    echo "Error: Target body file not found: $TARGET_BODY"
    exit 1
fi

# Use Python for the API calls
python3 << PYEOF
import base64
import json
import requests
import time
import sys

API_KEY = "$API_KEY"
PARIS_FACE = "$PARIS_FACE"
TARGET_BODY = "$TARGET_BODY"
OUTPUT_FILE = "$OUTPUT_FILE"

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

# Upload enhanced image to get public URL
print("\nStep 1.5: Uploading enhanced image to get public URL...")
upload_resp = requests.post(
    'https://freeimage.host/api/1/upload',
    data={'key': '6d207e02198a847aa98d0a2a901485a5', 'source': enhanced_base64, 'format': 'json'}
)

if upload_resp.status_code != 200:
    print(f"  Error uploading: {upload_resp.status_code}")
    sys.exit(1)

upload_data = upload_resp.json()
if upload_data['status_code'] != 200:
    print(f"  Upload failed: {upload_data}")
    sys.exit(1)

enhanced_url = upload_data['image']['url']
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

faces = detect_resp.json().get('faces', [])
print(f"  ✓ Detected {len(faces)} face(s)")

if not faces:
    print("  ✗ No faces found in target image!")
    sys.exit(1)

face = faces[0]
print(f"  Using face at ({face['x']}, {face['y']}) size {face['width']}x{face['height']}")

# Load and upload Paris face
print("\nStep 3: Uploading Paris face...")
with open(PARIS_FACE, 'rb') as f:
    paris_base64 = base64.b64encode(f.read()).decode('utf-8')

paris_upload_resp = requests.post(
    'https://freeimage.host/api/1/upload',
    data={'key': '6d207e02198a847aa98d0a2a901485a5', 'source': paris_base64, 'format': 'json'}
)

if paris_upload_resp.status_code == 200:
    paris_data = paris_upload_resp.json()
    if paris_data['status_code'] == 200:
        paris_url = paris_data['image']['url']
        print(f"  ✓ Uploaded: {paris_url}")
    else:
        print(f"  Upload failed, using data URL")
        paris_url = f'data:image/jpeg;base64,{paris_base64}'
else:
    print(f"  Upload failed, using data URL")
    paris_url = f'data:image/jpeg;base64,{paris_base64}'

print("\nStep 4: Face swapping...")
swap_resp = requests.post(
    'https://api.maxstudio.ai/faceswap',
    headers={'Content-Type': 'application/json', 'x-api-key': API_KEY},
    json={
        'mediaUrl': enhanced_url,
        'faces': [{
            'newFace': paris_url,
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
        f'https://api.maxstudio.ai/faceswap/{swap_job_id}',
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
            print("\n=== COMPLETE ===")
            sys.exit(0)
        elif data['status'] == 'failed':
            print("  ✗ Final enhancement failed")
            sys.exit(1)
else:
    print("  ✗ Timeout")
    sys.exit(1)

PYEOF
