#!/usr/bin/env python3
import requests
import json
import time
import sys

# Load workflow
with open('/workspace/comfyui_workflow_blondie.json', 'r') as f:
    workflow = json.load(f)

# Wrap in proper API format
payload = {
    "prompt": workflow,
    "client_id": "blondie_test_001"
}

print("🚀 Queueing workflow in ComfyUI...")
response = requests.post("http://127.0.0.1:8188/prompt", json=payload)

if response.status_code == 200:
    result = response.json()
    prompt_id = result.get('prompt_id')
    print(f"✅ Queued! Prompt ID: {prompt_id}")
    print("⏳ Generating image (this will take ~30-60 seconds)...")

    # Wait for completion
    time.sleep(60)

    print("✅ Generation should be complete!")
    print("📁 Check: /workspace/ComfyUI/output/")
else:
    print(f"❌ Error: {response.status_code}")
    print(response.text)
    sys.exit(1)
