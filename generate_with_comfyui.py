#!/usr/bin/env python3
"""
Generate images using ComfyUI API with trained LoRA
"""
import json
import requests
import time
import uuid
import os
from pathlib import Path

# ComfyUI server URL (adjust if different)
COMFYUI_URL = "http://127.0.0.1:8188"

# Test prompts to generate
TEST_PROMPTS = [
    "blondie woman, red dress, beach sunset, professional photography, high quality, detailed face, soft lighting, golden hour",
    "blondie woman, black leather jacket, city street at night, neon lights, professional photo, cinematic",
    "blondie woman, business suit, office, confident pose, professional headshot, studio lighting",
    "blondie woman, white summer dress, flower garden, natural lighting, happy smile, professional photo",
    "blondie woman, elegant evening gown, luxury ballroom, glamorous, professional fashion photography"
]

def load_workflow(workflow_path):
    """Load workflow JSON"""
    with open(workflow_path, 'r') as f:
        return json.load(f)

def queue_prompt(workflow):
    """Queue a prompt for generation"""
    prompt_id = str(uuid.uuid4())
    data = {
        "prompt": workflow,
        "client_id": prompt_id
    }

    response = requests.post(f"{COMFYUI_URL}/prompt", json=data)

    if response.status_code == 200:
        result = response.json()
        return result.get('prompt_id'), prompt_id
    else:
        print(f"❌ Error queuing prompt: {response.status_code}")
        print(response.text)
        return None, None

def check_status(prompt_id):
    """Check generation status"""
    response = requests.get(f"{COMFYUI_URL}/history/{prompt_id}")

    if response.status_code == 200:
        history = response.json()
        if prompt_id in history:
            return history[prompt_id].get('status', {})

    return None

def wait_for_completion(prompt_id, timeout=300):
    """Wait for generation to complete"""
    start_time = time.time()

    while time.time() - start_time < timeout:
        status = check_status(prompt_id)

        if status and status.get('status_str') == 'success':
            print("✅ Generation complete!")
            return True
        elif status and status.get('status_str') == 'error':
            print(f"❌ Generation failed: {status.get('messages', [])}")
            return False

        print("⏳ Generating...", end='\r')
        time.sleep(2)

    print(f"❌ Timeout after {timeout}s")
    return False

def generate_images(workflow_path, output_dir):
    """Generate test images with different prompts"""

    # Create output directory
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    print(f"🚀 Starting image generation...")
    print(f"   Workflow: {workflow_path}")
    print(f"   Output: {output_dir}")
    print(f"   Test prompts: {len(TEST_PROMPTS)}\n")

    # Load base workflow
    workflow = load_workflow(workflow_path)

    for i, prompt in enumerate(TEST_PROMPTS, 1):
        print(f"\n{'='*60}")
        print(f"[{i}/{len(TEST_PROMPTS)}] Generating image...")
        print(f"Prompt: {prompt[:80]}...")
        print('='*60)

        # Update prompt in workflow
        workflow["3"]["inputs"]["text"] = prompt

        # Update seed for variation
        workflow["6"]["inputs"]["seed"] = int(time.time()) + i

        # Update output filename
        workflow["8"]["inputs"]["filename_prefix"] = f"blondie_test_{i:02d}"

        # Queue the prompt
        prompt_id, client_id = queue_prompt(workflow)

        if not prompt_id:
            print(f"❌ Failed to queue prompt {i}")
            continue

        print(f"✅ Queued (ID: {prompt_id})")

        # Wait for completion
        if wait_for_completion(prompt_id):
            print(f"✅ Image {i} generated successfully!")
        else:
            print(f"❌ Image {i} generation failed")

        # Small delay between generations
        time.sleep(1)

    print(f"\n{'='*60}")
    print(f"📊 Generation Complete!")
    print(f"{'='*60}")
    print(f"Check ComfyUI output folder for generated images:")
    print(f"/workspace/ComfyUI/output/")
    print('='*60)

if __name__ == "__main__":
    workflow_path = "/workspace/comfyui_workflow_blondie.json"
    output_dir = "/workspace/ComfyUI/output"

    # Check if ComfyUI is running
    try:
        response = requests.get(f"{COMFYUI_URL}/system_stats")
        if response.status_code == 200:
            print("✅ ComfyUI is running")
        else:
            print("❌ ComfyUI is not responding properly")
            exit(1)
    except requests.exceptions.ConnectionError:
        print("❌ Cannot connect to ComfyUI. Is it running?")
        print("   Start ComfyUI first: cd /workspace/ComfyUI && python main.py")
        exit(1)

    generate_images(workflow_path, output_dir)
