BLONDIE LORA - DOWNLOAD PACKAGE
================================

This package contains everything you need to use your trained LoRA in ComfyUI.

FILES INCLUDED:
---------------
1. blondie_lora_workflow.json - ComfyUI workflow (drag & drop this)
2. blondie_lora.safetensors - Final trained LoRA (1500 steps)
3. blondie_lora_750steps.safetensors - 750-step checkpoint (often better quality)

HOW TO USE:
-----------
1. Copy ONE of the .safetensors files to: ComfyUI/models/loras/
   - Try the 750-step version first (usually more photorealistic)
   - Or use the 1500-step version

2. Make sure you have an SDXL base model in: ComfyUI/models/checkpoints/
   - RealVisXL (recommended)
   - Or any SDXL checkpoint

3. Open ComfyUI in your browser

4. DRAG AND DROP the blondie_lora_workflow.json file onto the ComfyUI canvas

5. If your checkpoint isn't named "realvisxl.safetensors":
   - Click the checkpoint loader node
   - Select your SDXL checkpoint from the dropdown

6. Click "Queue Prompt" to generate!

SETTINGS IN THE WORKFLOW:
------------------------
- LoRA Strength: 0.7 (adjust 0.5-1.0 for different results)
- Resolution: 1024x1024
- Steps: 30
- CFG Scale: 7.5
- Sampler: DPM++ 2M Karras
- Trigger word: "blondie woman"

TIPS:
-----
- Lower LoRA strength (0.5-0.6) = more photorealistic
- Higher LoRA strength (0.8-1.0) = more face accuracy
- Try both checkpoint versions to see which looks better
- Add photorealistic keywords: "8k uhd, dslr, professional photography"

TRAINING DETAILS:
-----------------
- Base Model: RealVisXL (SDXL)
- Training Method: Kohya LoRA
- Dataset: 30 face-swapped images with captions
- Learning Rate: 1e-4
- Steps: 1500 (with checkpoints every 250)
- LoRA Rank: 16

Need help? Check claude.md for full training documentation.
