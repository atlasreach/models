#!/usr/bin/env python3
import requests
import json
import time

# Test prompts
prompts = [
    "blondie woman, black leather jacket, city street at night, neon lights, professional photo, cinematic",
    "blondie woman, business suit, office, confident pose, professional headshot, studio lighting",
    "blondie woman, white summer dress, flower garden, natural lighting, happy smile, professional photo",
    "blondie woman, elegant evening gown, luxury ballroom, glamorous, professional fashion photography"
]

# Load base workflow
with open('/workspace/comfyui_workflow_blondie.json', 'r') as f:
    workflow = json.load(f)

for i, prompt in enumerate(prompts, 2):
    print(f"\n{'='*60}")
    print(f"[{i}/5] Generating image...")
    print(f"Prompt: {prompt[:60]}...")
    print('='*60)

    # Update prompt
    workflow["3"]["inputs"]["text"] = prompt
    workflow["8"]["inputs"]["filename_prefix"] = f"blondie_test_{i:05d}"

    # Queue
    payload = {"prompt": workflow, "client_id": f"blondie_test_{i:03d}"}
    response = requests.post("http://127.0.0.1:8188/prompt", json=payload)

    if response.status_code == 200:
        prompt_id = response.json().get('prompt_id')
        print(f"✅ Queued: {prompt_id}")
    else:
        print(f"❌ Failed: {response.status_code}")

    # Wait for generation
    time.sleep(60)

print(f"\n{'='*60}")
print("✅ All done! Check /workspace/ComfyUI/output/")
print('='*60)
