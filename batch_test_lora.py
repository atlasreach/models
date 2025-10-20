#!/usr/bin/env python3
"""
Systematic LoRA Testing and Batch Generation

Usage:
  Phase 1: python3 batch_test_lora.py --test-checkpoints
  Phase 2: python3 batch_test_lora.py --test-strengths --checkpoint 750
  Phase 3: python3 batch_test_lora.py --test-prompts --checkpoint 750 --strength 0.7
  Phase 4: python3 batch_test_lora.py --mass-generate --checkpoint 750 --strength 0.7
"""

import requests
import json
import time
import argparse
from pathlib import Path

COMFYUI_URL = "http://127.0.0.1:8188"  # Local or change to RunPod URL

# Test prompts for different scenarios
TEST_PROMPTS = {
    "portrait": "blondie woman, professional portrait, photorealistic, 8k uhd, dslr, soft lighting, detailed face",
    "casual": "blondie woman, casual outfit, coffee shop, natural lighting, candid photo",
    "fashion": "blondie woman, elegant dress, fashion photography, studio lighting, high fashion",
    "outdoor": "blondie woman, outdoor setting, natural sunlight, golden hour, professional photo",
    "business": "blondie woman, business attire, office setting, professional headshot",
}

MASS_GENERATION_PROMPTS = [
    "blondie woman, red dress, beach sunset, golden hour, professional photography",
    "blondie woman, black leather jacket, city street, night, neon lights, cinematic",
    "blondie woman, white summer dress, flower garden, soft natural lighting",
    "blondie woman, elegant evening gown, luxury ballroom, dramatic lighting",
    "blondie woman, casual jeans and t-shirt, urban park, sunny day",
    "blondie woman, professional suit, corporate office, confident pose",
    "blondie woman, boho style dress, desert landscape, warm tones",
    "blondie woman, workout clothes, gym setting, energetic, dynamic",
    "blondie woman, winter coat, snowy street, soft diffused light",
    "blondie woman, bikini, tropical beach, turquoise water, vacation vibes",
    "blondie woman, cocktail dress, rooftop bar, city skyline, evening",
    "blondie woman, vintage 1950s style, retro diner, classic photography",
    "blondie woman, leather pants, rock concert, stage lighting, edgy",
    "blondie woman, floral sundress, countryside, natural beauty",
    "blondie woman, lab coat, modern laboratory, professional scientist",
]

def load_base_workflow():
    """Load the base ComfyUI workflow"""
    with open('blondie_lora_workflow.json', 'r') as f:
        return json.load(f)

def queue_generation(workflow, description=""):
    """Queue a generation in ComfyUI"""
    payload = {"prompt": workflow, "client_id": f"batch_{int(time.time())}"}

    try:
        response = requests.post(f"{COMFYUI_URL}/prompt", json=payload, timeout=10)
        if response.status_code == 200:
            prompt_id = response.json().get('prompt_id')
            print(f"  ✅ Queued: {description} (ID: {prompt_id[:8]}...)")
            return prompt_id
        else:
            print(f"  ❌ Failed: {description}")
            return None
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return None

def test_checkpoints(variations=5):
    """Phase 1: Test all checkpoint versions"""
    print("\n" + "="*60)
    print("PHASE 1: Testing All Checkpoints")
    print("="*60)

    checkpoints = [
        "blondie_lora-step00000250.safetensors",
        "blondie_lora-step00000500.safetensors",
        "blondie_lora-step00000750.safetensors",
        "blondie_lora-step00001000.safetensors",
        "blondie_lora-step00001250.safetensors",
        "blondie_lora-step00001500.safetensors",
        "blondie_lora.safetensors",
    ]

    workflow = load_base_workflow()
    base_prompt = TEST_PROMPTS["portrait"]

    total = len(checkpoints) * variations
    count = 0

    for checkpoint in checkpoints:
        step = checkpoint.split("step")[1].split(".")[0] if "step" in checkpoint else "final"
        print(f"\n📊 Testing Checkpoint: {step} steps")

        for i in range(variations):
            workflow["2"]["inputs"]["lora_name"] = checkpoint
            workflow["3"]["inputs"]["text"] = base_prompt
            workflow["6"]["inputs"]["seed"] = int(time.time()) + i
            workflow["8"]["inputs"]["filename_prefix"] = f"test_checkpoint_{step}_{i+1:02d}"

            queue_generation(workflow, f"{step} steps (variation {i+1})")
            count += 1

            # Wait between generations
            time.sleep(60)
            print(f"  Progress: {count}/{total} ({count*100//total}%)")

    print(f"\n✅ Phase 1 Complete! Generated {total} images")
    print("📁 Review images and pick the best checkpoint")

def test_strengths(checkpoint, variations=5):
    """Phase 2: Test different LoRA strengths"""
    print("\n" + "="*60)
    print(f"PHASE 2: Testing LoRA Strengths (Checkpoint: {checkpoint})")
    print("="*60)

    strengths = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    workflow = load_base_workflow()
    base_prompt = TEST_PROMPTS["portrait"]

    lora_file = f"blondie_lora-step{checkpoint:08d}.safetensors" if checkpoint != "final" else "blondie_lora.safetensors"

    total = len(strengths) * variations
    count = 0

    for strength in strengths:
        print(f"\n📊 Testing Strength: {strength}")

        for i in range(variations):
            workflow["2"]["inputs"]["lora_name"] = lora_file
            workflow["2"]["inputs"]["strength_model"] = strength
            workflow["2"]["inputs"]["strength_clip"] = strength
            workflow["3"]["inputs"]["text"] = base_prompt
            workflow["6"]["inputs"]["seed"] = int(time.time()) + i
            workflow["8"]["inputs"]["filename_prefix"] = f"test_strength_{int(strength*10)}_{i+1:02d}"

            queue_generation(workflow, f"Strength {strength} (variation {i+1})")
            count += 1

            time.sleep(60)
            print(f"  Progress: {count}/{total} ({count*100//total}%)")

    print(f"\n✅ Phase 2 Complete! Generated {total} images")
    print("📁 Review and pick the best strength")

def test_prompts(checkpoint, strength, variations=10):
    """Phase 3: Test different prompt scenarios"""
    print("\n" + "="*60)
    print(f"PHASE 3: Testing Different Prompts")
    print(f"  Checkpoint: {checkpoint}, Strength: {strength}")
    print("="*60)

    workflow = load_base_workflow()
    lora_file = f"blondie_lora-step{checkpoint:08d}.safetensors" if checkpoint != "final" else "blondie_lora.safetensors"

    workflow["2"]["inputs"]["lora_name"] = lora_file
    workflow["2"]["inputs"]["strength_model"] = strength
    workflow["2"]["inputs"]["strength_clip"] = strength

    total = len(TEST_PROMPTS) * variations
    count = 0

    for category, prompt in TEST_PROMPTS.items():
        print(f"\n📊 Testing Category: {category}")

        for i in range(variations):
            workflow["3"]["inputs"]["text"] = prompt
            workflow["6"]["inputs"]["seed"] = int(time.time()) + i
            workflow["8"]["inputs"]["filename_prefix"] = f"test_prompt_{category}_{i+1:02d}"

            queue_generation(workflow, f"{category} (variation {i+1})")
            count += 1

            time.sleep(60)
            print(f"  Progress: {count}/{total} ({count*100//total}%)")

    print(f"\n✅ Phase 3 Complete! Generated {total} images")
    print("📁 Review and pick your favorite prompt styles")

def mass_generate(checkpoint, strength, batch_size=20):
    """Phase 4: Generate hundreds of images with best settings"""
    print("\n" + "="*60)
    print(f"PHASE 4: Mass Generation")
    print(f"  Checkpoint: {checkpoint}, Strength: {strength}")
    print(f"  Prompts: {len(MASS_GENERATION_PROMPTS)}")
    print(f"  Variations per prompt: {batch_size}")
    print(f"  Total: {len(MASS_GENERATION_PROMPTS) * batch_size} images")
    print("="*60)

    workflow = load_base_workflow()
    lora_file = f"blondie_lora-step{checkpoint:08d}.safetensors" if checkpoint != "final" else "blondie_lora.safetensors"

    workflow["2"]["inputs"]["lora_name"] = lora_file
    workflow["2"]["inputs"]["strength_model"] = strength
    workflow["2"]["inputs"]["strength_clip"] = strength

    total = len(MASS_GENERATION_PROMPTS) * batch_size
    count = 0

    for prompt_idx, prompt in enumerate(MASS_GENERATION_PROMPTS, 1):
        print(f"\n📸 Prompt {prompt_idx}/{len(MASS_GENERATION_PROMPTS)}")
        print(f"   {prompt[:70]}...")

        for i in range(batch_size):
            workflow["3"]["inputs"]["text"] = prompt
            workflow["6"]["inputs"]["seed"] = int(time.time()) + i
            workflow["8"]["inputs"]["filename_prefix"] = f"batch_p{prompt_idx:02d}_v{i+1:03d}"

            queue_generation(workflow, f"Variation {i+1}/{batch_size}")
            count += 1

            time.sleep(60)

            if count % 10 == 0:
                print(f"\n  🎯 Overall Progress: {count}/{total} ({count*100//total}%)\n")

    print(f"\n✅ Phase 4 Complete! Generated {total} images")
    print("🎉 You now have hundreds of images to choose from!")

def main():
    parser = argparse.ArgumentParser(description="Systematic LoRA Testing")
    parser.add_argument("--test-checkpoints", action="store_true", help="Phase 1: Test all checkpoints")
    parser.add_argument("--test-strengths", action="store_true", help="Phase 2: Test LoRA strengths")
    parser.add_argument("--test-prompts", action="store_true", help="Phase 3: Test different prompts")
    parser.add_argument("--mass-generate", action="store_true", help="Phase 4: Generate hundreds of images")
    parser.add_argument("--checkpoint", type=int, default=750, help="Checkpoint step to use")
    parser.add_argument("--strength", type=float, default=0.7, help="LoRA strength (0.5-1.0)")
    parser.add_argument("--variations", type=int, default=5, help="Variations per test")
    parser.add_argument("--batch-size", type=int, default=20, help="Variations per prompt in mass generation")

    args = parser.parse_args()

    if args.test_checkpoints:
        test_checkpoints(args.variations)
    elif args.test_strengths:
        test_strengths(args.checkpoint, args.variations)
    elif args.test_prompts:
        test_prompts(args.checkpoint, args.strength, args.variations)
    elif args.mass_generate:
        mass_generate(args.checkpoint, args.strength, args.batch_size)
    else:
        print("Please specify a phase: --test-checkpoints, --test-strengths, --test-prompts, or --mass-generate")

if __name__ == "__main__":
    main()
