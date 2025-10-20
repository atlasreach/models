#!/usr/bin/env python3
"""
Simple script to generate images with trained LoRA using Diffusers
"""
import torch
from diffusers import StableDiffusionXLPipeline
from pathlib import Path

# Paths
BASE_MODEL = "/workspace/ComfyUI/models/checkpoints/realvisxl.safetensors"
LORA_PATH = "/workspace/ComfyUI/models/loras/blondie_lora.safetensors"
OUTPUT_DIR = "/workspace/generated_images"

# Test prompts
PROMPTS = [
    "blondie woman, red dress, beach sunset, professional photography, high quality, detailed face, soft lighting, golden hour",
    "blondie woman, black leather jacket, city street at night, neon lights, professional photo, cinematic",
    "blondie woman, business suit, office, confident pose, professional headshot, studio lighting",
    "blondie woman, white summer dress, flower garden, natural lighting, happy smile, professional photo",
    "blondie woman, elegant evening gown, luxury ballroom, glamorous, professional fashion photography"
]

NEGATIVE_PROMPT = "ugly, deformed, blurry, low quality, distorted face, bad anatomy, text, watermark, duplicate"

def main():
    print("🚀 Loading SDXL model...")

    # Load SDXL pipeline
    pipe = StableDiffusionXLPipeline.from_single_file(
        BASE_MODEL,
        torch_dtype=torch.float16,
        use_safetensors=True
    ).to("cuda")

    print("✅ Model loaded")
    print(f"📦 Loading LoRA: {LORA_PATH}")

    # Load LoRA weights
    pipe.load_lora_weights(LORA_PATH)

    print("✅ LoRA loaded")

    # Create output directory
    Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

    print(f"\n🎨 Generating {len(PROMPTS)} images...")
    print(f"📁 Output: {OUTPUT_DIR}\n")

    # Generate images
    for i, prompt in enumerate(PROMPTS, 1):
        print(f"{'='*60}")
        print(f"[{i}/{len(PROMPTS)}] Generating...")
        print(f"Prompt: {prompt[:60]}...")
        print('='*60)

        # Generate
        image = pipe(
            prompt=prompt,
            negative_prompt=NEGATIVE_PROMPT,
            num_inference_steps=30,
            guidance_scale=7.5,
            width=1024,
            height=1024,
        ).images[0]

        # Save
        output_path = f"{OUTPUT_DIR}/blondie_test_{i:02d}.png"
        image.save(output_path)

        print(f"✅ Saved: {output_path}\n")

    print(f"\n{'='*60}")
    print(f"✅ Done! Generated {len(PROMPTS)} images")
    print(f"📁 Location: {OUTPUT_DIR}")
    print('='*60)

if __name__ == "__main__":
    main()
