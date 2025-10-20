# Claude Development Notes

## Face-Swap Script Updates (2025-10-20)

### AWS S3 Integration
Replaced freeimage.host with AWS S3 for image hosting due to rate limits.

**Changes Made:**
- Added boto3 dependency for AWS SDK
- Added S3 upload function to script
- Configured AWS credentials in .env file
- Updated both image upload locations (enhanced target and source face) to use S3

**AWS Configuration:**
- Bucket: `modelcrew`
- Region: `us-east-2`
- Images stored in: `faceswap/YYYYMMDD/` folder structure

---

## Face-Swap Script Fixes (2025-10-19)

### Issues Fixed in `face-swap-with-caption.sh`

When working with the MaxStudio AI API, encountered several issues that required corrections:

#### 1. Face Detection Response Key
**Problem:** Script was looking for `faces` key in response, but API returns `detectedFaces`

**Fix:**
```python
# WRONG:
faces = detect_resp.json().get('faces', [])

# CORRECT:
faces = detect_resp.json().get('detectedFaces', [])
```

**Location:** Line 136 in face-swap-with-caption.sh

---

#### 2. Face Swap Endpoint
**Problem:** Script was using wrong endpoint `/faceswap` which returns 404

**Fix:**
```python
# WRONG:
'https://api.maxstudio.ai/faceswap'

# CORRECT:
'https://api.maxstudio.ai/swap-image'
```

**Location:** Line 170 in face-swap-with-caption.sh

---

#### 3. Face Swap Status Check Endpoint
**Problem:** Status check endpoint also needed to match the correct endpoint

**Fix:**
```python
# WRONG:
f'https://api.maxstudio.ai/faceswap/{swap_job_id}'

# CORRECT:
f'https://api.maxstudio.ai/swap-image/{swap_job_id}'
```

**Location:** Line 192 in face-swap-with-caption.sh

---

### Summary
The MaxStudio AI API documentation shows:
- Face detection: `/detect-face-image` → returns `detectedFaces` array
- Face swap: `/swap-image` → NOT `/faceswap`
- Status check: `/swap-image/{jobId}` → matches the swap endpoint

These changes allow the face-swap workflow to run successfully with proper face detection and swapping.

---

## Product Roadmap (2025-10-20)

### Vision
Build an automated AI model content generation platform:
1. Upload face + body photo zip
2. Auto face-swap + enhance + caption
3. Train custom LoRA model
4. Generate unlimited content
5. Schedule social media posts
6. Track analytics & performance

### Phase 1: Terminal Scripts (Weeks 1-4) ← **CURRENT PHASE**

**Week 1: Complete Training Pipeline**
- ✅ Face swap + caption generation (completed)
- ✅ AWS S3 organized structure (completed)
- 🔄 LoRA training setup (in progress - RunPod)
- Test trained model quality in ComfyUI
- Generate 10-20 test images with different prompts
- Iterate on training settings if needed

**Week 2: Build Generation & Export Tools**
- Script to generate images from trained LoRA
- Batch generation (100+ images overnight)
- Auto-resize for IG (1080x1350), TikTok (1080x1920)
- Add watermarks/branding options

**Week 3: Process 2-3 More Models**
- Process Sarah dataset through full pipeline
- Train 2-3 additional models
- Validate workflow scales properly
- Build library of 3-5 working models

**Week 4: Manual Social Testing**
- Post manually to IG/TikTok
- Test what content performs
- Track engagement manually
- Learn platform algorithms

### Phase 2: Web Interface (Weeks 5-7)

**Components to Build:**
```
Web Dashboard:
├── Upload Interface
│   ├── Drag & drop face image
│   ├── Drag & drop body photo zip
│   └── Enter model name + trigger word
├── Processing Pipeline (automated)
│   ├── Face swap batch processing
│   ├── Enhancement + caption generation
│   ├── AWS S3 upload
│   ├── Training job submission
│   └── Progress tracking dashboard
├── Model Management
│   ├── View all trained models
│   ├── Model quality metrics
│   └── Version history
├── Image Generation
│   ├── Text prompt input
│   ├── Batch generation queue
│   └── Preview & download
└── Export & Formatting
    ├── Auto-resize for platforms
    ├── Watermark application
    └── Metadata tagging
```

**Tech Stack:**
- Backend: Node.js or Python FastAPI
- Frontend: Next.js / React
- Queue: Bull/Redis (background jobs)
- Storage: AWS S3 (already configured)
- Database: PostgreSQL (models, jobs, analytics)

### Phase 3: Social Media Integration (Weeks 8-9)

**Scheduling & Posting:**
- Integrate Buffer or Later API ($10-20/mo)
- Calendar interface for scheduling
- Multi-platform support (IG, TikTok, etc.)
- Auto-caption generation
- Hashtag optimization

**Why Use Buffer Instead of Building:**
- Save 2+ months dev time
- Proven platform with API
- Handles rate limits & platform quirks
- Focus on content, not infrastructure

### Phase 4: Video & Analytics (Weeks 10-12)

**Reels/Video Generation:**
- Integrate RunwayML or Pika API
- Auto-generate reels from prompts
- Batch video processing
- Audio/music integration

**Analytics Dashboard:**
- Engagement tracking per model
- Performance metrics (likes, comments, shares)
- Content performance insights
- A/B testing framework
- Trend analysis with AI

**Advanced Features:**
- AI trend detector (what's popping)
- Competitor analysis
- Content recommendation engine
- Auto-optimize posting times

### Why This Timeline?

**Terminal First (Don't Build UI Yet):**
1. Workflow will change - settings, formats, quality tuning
2. Web dev takes 2-3 weeks - time better spent processing models
3. Terminal faster for iteration - one line change vs full UI update
4. Don't know what works yet - might pivot training approach

**Web UI After Proven Workflow:**
1. Know exactly what to automate
2. Have 5+ trained models as proof
3. Understand social performance
4. UI built around actual needs, not guesses

## Training Success - Kohya SDXL LoRA (2025-10-20 11pm)

**Status: ✅ TRAINING IN PROGRESS**

### What's Training
- **Method**: Kohya_ss SDXL LoRA Training
- **Base Model**: RealVisXL (2GB SDXL checkpoint from Civitai)
- **Training Type**: LoRA (Low-Rank Adaptation)
- **Output**: 20-50MB adapter file
- **Duration**: 15-20 minutes (~1500 steps)
- **Trigger Word**: "blondie woman"

### Dataset Structure (Kohya Format)
```
/workspace/kohya_dataset/blondie/
└── 30_blondie_woman/          ← folder name = "30 repeats" + "trigger word"
    ├── 30 images (.jpg)
    └── 30 captions (.txt)
    = 900 training steps (30 images × 30 repeats)
```

### Training Settings
```yaml
Resolution: 1024x1024         # SDXL native resolution
Learning Rate: 0.0001         # Moderate learning speed
LoRA Rank: 16                 # Network complexity
LoRA Alpha: 16                # Output strength
Batch Size: 1                 # One image per step
Optimizer: AdamW8bit          # Memory-efficient
Mixed Precision: bf16         # Speed optimization
Gradient Checkpointing: Yes   # VRAM saving
Checkpoints: Every 250 steps  # Can test intermediate versions
```

### How LoRA Training Works

**The Process:**
1. Base model (RealVisXL) stays frozen - not modified
2. LoRA creates small "adapter" weights that sit on top
3. For each step:
   - Show image: "blondie woman, black dress, studio"
   - Model generates prediction
   - Compare to real image
   - Adjust only LoRA weights (not base model)
4. After 1500 steps, LoRA knows "blondie woman" = specific face

**Why LoRA vs Full Fine-tune:**
- ✅ Faster: 20 mins vs 4+ hours
- ✅ Smaller: 20MB vs 2GB
- ✅ Preserves base model knowledge
- ✅ Can stack multiple LoRAs
- ✅ Easy to share/distribute

### Training Commands

**Dataset Preparation:**
```bash
mkdir -p /workspace/kohya_dataset/blondie/30_blondie_woman
cp /workspace/datasets/blondie/images/*.jpg /workspace/kohya_dataset/blondie/30_blondie_woman/
cp /workspace/datasets/blondie/captions/*.txt /workspace/kohya_dataset/blondie/30_blondie_woman/
```

**Training Command:**
```bash
cd /workspace/kohya_ss/sd-scripts
python3 train_network.py \
  --pretrained_model_name_or_path=/workspace/ComfyUI/models/checkpoints/realvisxl.safetensors \
  --train_data_dir=/workspace/kohya_dataset/blondie \
  --resolution=1024,1024 \
  --output_dir=/workspace/output/blondie_lora \
  --output_name=blondie_lora \
  --save_model_as=safetensors \
  --max_train_steps=1500 \
  --learning_rate=1e-4 \
  --optimizer_type=AdamW8bit \
  --network_dim=16 \
  --network_alpha=16 \
  --train_batch_size=1 \
  --caption_extension=.txt \
  --enable_bucket \
  --xformers \
  --mixed_precision=bf16 \
  --cache_latents \
  --gradient_checkpointing \
  --save_every_n_steps=250
```

**Monitor Progress:**
```bash
tail -f /workspace/training.log
```

### Output Files
```
/workspace/output/blondie_lora/
├── blondie_lora.safetensors           # Final model
├── blondie_lora-000250.safetensors    # Checkpoint 1
├── blondie_lora-000500.safetensors    # Checkpoint 2
├── blondie_lora-000750.safetensors    # Checkpoint 3
├── blondie_lora-001000.safetensors    # Checkpoint 4
├── blondie_lora-001250.safetensors    # Checkpoint 5
└── blondie_lora-001500.safetensors    # Final checkpoint
```

### How to Use the Trained LoRA

**In ComfyUI:**
1. Copy LoRA: `cp /workspace/output/blondie_lora/blondie_lora.safetensors /workspace/ComfyUI/models/loras/`
2. Load in SDXL workflow
3. Prompt: `"blondie woman, red dress, beach sunset, professional photo"`
4. LoRA Strength: 0.7-1.0

**In Other Tools:**
- Automatic1111: Place in `models/Lora/`
- Forge: Same as A1111
- Online (Replicate, etc.): Upload .safetensors file

### Training Timeline
- Steps 1-250: Learning basic facial features
- Steps 250-500: Refining face structure
- Steps 500-1000: Learning expressions/angles
- Steps 1000-1500: Fine-tuning consistency

**Testing Checkpoints:**
- If overfit (exact copies): Use earlier checkpoint (500-750)
- If underfit (doesn't match): Use later checkpoint (1250-1500)
- Sweet spot usually: 750-1000 steps

### Files to Keep vs Delete

**Keep:**
- ✅ `/workspace/output/blondie_lora/*.safetensors` - Trained models
- ✅ `/workspace/kohya_dataset/` - Organized dataset for future training
- ✅ `/workspace/datasets/blondie/` - Original dataset
- ✅ `/workspace/kohya_ss/` - Training framework
- ✅ `/workspace/training.log` - Training history

**Can Delete After Success:**
- ❌ `/workspace/ai-toolkit/` - Didn't use this path
- ❌ `/workspace/train_blondie.py` - Failed script attempts
- ❌ `/workspace/train_blondie.sh` - Failed script attempts
- ❌ `/workspace/train_blondie_final.py` - Failed script attempts

### What We Learned Tonight

**HuggingFace Auth Workarounds:**
- AI Toolkit → Requires HF (blocked)
- Flux models → Require HF (blocked)
- ComfyUI FluxTrainer → Dependency issues
- **Kohya_ss** → ✅ Works offline with local models!

**Key Insight:** Download models from Civitai (no auth needed), use Kohya for training

### Next Steps (After Training Completes)

1. Test LoRA in ComfyUI with various prompts
2. Generate 10-20 test images
3. Evaluate quality (face accuracy, style consistency)
4. If good → Process Sarah dataset same way
5. If needs improvement → Adjust settings and retrain
