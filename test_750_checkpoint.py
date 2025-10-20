#!/usr/bin/env python3
import requests
import json

# Load workflow
with open('/workspace/comfyui_workflow_blondie.json', 'r') as f:
    workflow = json.load(f)

# Update to use 750-step checkpoint
workflow["2"]["inputs"]["lora_name"] = "blondie_lora_750.safetensors"
workflow["2"]["inputs"]["strength_model"] = 0.7  # Lower strength
workflow["8"]["inputs"]["filename_prefix"] = "blondie_750_test"

# Better prompt for photorealism
workflow["3"]["inputs"]["text"] = "blondie woman, professional portrait, natural lighting, photorealistic, 8k uhd, dslr, soft lighting, high quality, film grain"

payload = {"prompt": workflow, "client_id": "test_750"}

print("🚀 Testing 750-step checkpoint with better settings...")
response = requests.post("http://127.0.0.1:8188/prompt", json=payload)

if response.status_code == 200:
    print(f"✅ Queued! Prompt ID: {response.json().get('prompt_id')}")
    print("⏳ Generating... (60 seconds)")
    import time
    time.sleep(60)
    print("✅ Check: /workspace/ComfyUI/output/blondie_750_test_*.png")
else:
    print(f"❌ Error: {response.status_code}")
