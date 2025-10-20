#!/usr/bin/env python3
"""
Load workflow into RunPod ComfyUI via API and generate image
"""
import requests
import json
import time

# RunPod ComfyUI URL
COMFYUI_URL = "https://w08uzdoduk1wd5-8188.proxy.runpod.net"

# Load workflow
with open('/workspace/comfyui_workflow_blondie.json', 'r') as f:
    workflow = json.load(f)

# Update to use 750-step checkpoint with better settings
workflow["2"]["inputs"]["lora_name"] = "blondie_lora-step00000750.safetensors"
workflow["2"]["inputs"]["strength_model"] = 0.7
workflow["2"]["inputs"]["strength_clip"] = 0.7

# Better photorealistic prompt
workflow["3"]["inputs"]["text"] = "blondie woman, professional portrait photo, natural lighting, photorealistic, 8k uhd, dslr, soft lighting, high quality, detailed face, film grain, Fujifilm XT3"

# Queue the workflow
payload = {
    "prompt": workflow,
    "client_id": "runpod_test_001"
}

print("🚀 Loading workflow into RunPod ComfyUI...")
print(f"   URL: {COMFYUI_URL}")
print()

try:
    response = requests.post(f"{COMFYUI_URL}/prompt", json=payload, timeout=30)

    if response.status_code == 200:
        result = response.json()
        prompt_id = result.get('prompt_id')
        print(f"✅ Workflow loaded and queued!")
        print(f"   Prompt ID: {prompt_id}")
        print()
        print("⏳ Generating image... (this takes ~60 seconds)")
        print()
        print("📱 Open in browser to see progress:")
        print(f"   {COMFYUI_URL}")
        print()

        # Wait for generation
        time.sleep(65)

        print("✅ Generation should be complete!")
        print(f"   Check the ComfyUI interface: {COMFYUI_URL}")
        print("   Or SSH to RunPod: /workspace/ComfyUI/output/")

    else:
        print(f"❌ Error: {response.status_code}")
        print(response.text)

except requests.exceptions.RequestException as e:
    print(f"❌ Connection error: {e}")
    print()
    print("💡 Make sure ComfyUI is running on RunPod")
    print(f"   Try opening: {COMFYUI_URL}")
