# Improved Face Swap Workflow

This workflow supports **dynamic model naming**, **batch processing with parallelization**, **resume capability**, and **organized AWS S3 structure**.

## Features

✨ **Dynamic Model Support** - Process multiple models (blondie, sarah, alex, etc.)
⚡ **Parallel Processing** - Process 3+ images simultaneously
🔄 **Resume Capability** - Automatically skip already processed files
📁 **Organized Structure** - Clean folder organization per model
☁️ **AWS S3 Sync** - Upload datasets to S3 with model-specific folders

---

## Folder Structure

```
.
├── {model-name}/
│   ├── source/               # Source face images
│   │   └── {model}-1.png
│   ├── targets/              # Target body images
│   │   ├── image1.jpg
│   │   └── image2.jpg
│   └── outputs/
│       └── faceswapped/      # Final swapped images
│           ├── image1_swapped.jpg
│           └── image2_swapped.jpg
│
├── dataset/
│   └── {model-name}/
│       ├── captions/         # Generated captions
│       │   ├── image1_swapped.txt
│       │   └── image2_swapped.txt
│       ├── prompts/          # Photography prompts
│       │   ├── image1_swapped.prompt.txt
│       │   └── image2_swapped.prompt.txt
│       └── meta/
│           └── meta.jsonl    # Complete metadata
│
└── logs/
    └── {model-name}/         # Processing logs
```

### AWS S3 Structure

```
s3://modelcrew/
├── blondie/
│   ├── outputs/faceswapped/  # Swapped images
│   ├── captions/             # Caption files
│   ├── meta/meta.jsonl       # Metadata
│   └── temp/                 # Temporary processing files
├── sarah/
│   ├── outputs/faceswapped/
│   └── ...
└── alex/
    └── ...
```

---

## Scripts

### 1. `face-swap-model.sh` - Single Image Processing

Process a single image with face swap + enhancement + caption generation.

**Usage:**
```bash
./face-swap-model.sh <model_name> <source_face> <target_body>
```

**Example:**
```bash
./face-swap-model.sh blondie blondie/source/blondie-1.png blondie/targets/img1.jpg
```

**Features:**
- Dynamic model naming (trigger token in captions)
- Resume capability (skips if output exists)
- Creates organized folder structure
- Generates captions with model-specific trigger tokens
- Saves metadata to `dataset/{model-name}/meta/meta.jsonl`

---

### 2. `batch-process-model.sh` - Batch Processing (Parallel)

Process multiple images in parallel for faster processing.

**Usage:**
```bash
./batch-process-model.sh <model_name> <source_face> <targets_dir> [parallel_jobs]
```

**Arguments:**
- `model_name` - Name of the model (e.g., 'blondie', 'sarah')
- `source_face` - Path to source face image
- `targets_dir` - Directory containing target body images
- `parallel_jobs` - Number of parallel processes (default: 3)

**Example:**
```bash
# Process all images in targets/ directory with 3 parallel jobs
./batch-process-model.sh blondie blondie/source/blondie-1.png blondie/targets/ 3

# Process with 5 parallel jobs for faster processing
./batch-process-model.sh sarah sarah/source/sarah-1.png sarah/targets/ 5
```

**Features:**
- Processes all .jpg, .jpeg, .png files in the target directory
- Runs multiple processes in parallel (default 3, configurable)
- Shows progress with real-time status updates
- Automatically skips already processed files
- Creates detailed logs for each processed image
- Displays summary with success/failure counts

**Performance:**
- 1 parallel job: ~8-12 min per image
- 3 parallel jobs: Process 3 images simultaneously
- 5 parallel jobs: Process 5 images simultaneously (if API limits allow)

---

### 3. `sync-model-to-s3.js` - Sync to AWS S3

Upload processed dataset to AWS S3 with organized structure.

**Usage:**
```bash
node sync-model-to-s3.js <model_name>
```

**Example:**
```bash
# Sync blondie dataset to S3
node sync-model-to-s3.js blondie

# Sync sarah dataset to S3
node sync-model-to-s3.js sarah
```

**What it does:**
1. Deletes existing files for the model in S3 (clean slate)
2. Uploads all processed images from `{model}/outputs/faceswapped/`
3. Uploads all captions from `dataset/{model}/captions/`
4. Uploads metadata from `dataset/{model}/meta/meta.jsonl`
5. Shows progress and upload status

**S3 Structure Created:**
```
s3://modelcrew/{model-name}/
├── outputs/faceswapped/*.jpg
├── captions/*.txt
└── meta/meta.jsonl
```

---

## Complete Workflow Example

### Step 1: Setup Your Model Structure

```bash
# Create folders for a new model
mkdir -p sarah/source
mkdir -p sarah/targets

# Add your source face image
cp path/to/sarah-face.png sarah/source/sarah-1.png

# Add target body images
cp path/to/body-images/*.jpg sarah/targets/
```

### Step 2: Process Images in Batch

```bash
# Process all target images with 3 parallel jobs
./batch-process-model.sh sarah sarah/source/sarah-1.png sarah/targets/ 3
```

**Output:**
```
╔════════════════════════════════════════════════════════════╗
║         Batch Face Swap Processing                         ║
╚════════════════════════════════════════════════════════════╝

Model Name:       sarah
Source Face:      sarah/source/sarah-1.png
Targets Dir:      sarah/targets/
Parallel Jobs:    3

Found 30 target image(s)

Status:
  Already processed: 0
  Remaining:         30

Process 30 file(s) with 3 parallel jobs? (y/n) y

[12:30:15] Processing: image1.jpg
[12:30:16] Processing: image2.jpg
[12:30:17] Processing: image3.jpg
[12:38:45] ✓ Success: image1.jpg
[12:38:47] ✓ Success: image2.jpg
...
```

### Step 3: Sync to AWS S3

```bash
# Upload dataset to S3
node sync-model-to-s3.js sarah
```

**Output:**
```
🚀 Starting S3 sync...
   Model: sarah
   Bucket: modelcrew
   Region: us-east-2

🗑️  Deleting existing files for model 'sarah' in S3...
✅ Deleted 0 existing files from S3

📂 Collecting files to upload...
   Found 30 .jpg images
   Found 30 caption .txt files
   Found meta.jsonl

📤 Uploading 61 files to S3...
   [1/61] Uploading image1_swapped.jpg... ✅
   ...

==================================================
📊 Sync Complete!
==================================================
Model: sarah
✅ Successfully uploaded: 61 files
📍 S3 Location: s3://modelcrew/sarah/
==================================================
```

---

## Resume Capability

If processing is interrupted, simply run the batch script again:

```bash
./batch-process-model.sh blondie blondie/source/blondie-1.png blondie/targets/ 3
```

**Output:**
```
Status:
  Already processed: 15
  Remaining:         15

Process 15 file(s) with 3 parallel jobs? (y/n)
```

Only the remaining 15 files will be processed! ✨

---

## Processing Multiple Models

You can process multiple models by running separate commands:

```bash
# Process blondie
./batch-process-model.sh blondie blondie/source/blondie-1.png blondie/targets/ 3

# Process sarah
./batch-process-model.sh sarah sarah/source/sarah-1.png sarah/targets/ 3

# Process alex
./batch-process-model.sh alex alex/source/alex-1.png alex/targets/ 3

# Sync all to S3
node sync-model-to-s3.js blondie
node sync-model-to-s3.js sarah
node sync-model-to-s3.js alex
```

Each model will have its own organized structure in both local storage and S3.

---

## Configuration

All scripts use environment variables from `.env`:

```env
# MaxStudio API
API_KEY=your_maxstudio_api_key

# Anthropic API (for captions)
ANTHROPIC_API_KEY=your_anthropic_api_key

# AWS S3
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
AWS_S3_BUCKET=modelcrew
AWS_REGION=us-east-2

# Optional overrides
TRIGGER_TOKEN=blondie    # Override default (uses model name)
CLASS_TOKEN=woman        # Default class token
```

---

## Logs and Debugging

Each processed image creates a log file:

```bash
# View logs for a specific image
cat logs/blondie/image1.log

# Check for failed images
grep -l "✗" logs/blondie/*.log
```

---

## Tips for Best Performance

1. **Parallel Jobs**: Start with 3 parallel jobs, increase if API limits allow
2. **Image Quality**: Higher quality target images = better results
3. **Resume**: If interrupted, just run again - already processed files are skipped
4. **Batch Size**: Process 20-50 images at a time for manageable batches
5. **S3 Sync**: Only sync after all processing is complete

---

## Comparison: Old vs New Workflow

| Feature | Old Workflow | New Workflow |
|---------|-------------|--------------|
| Model Support | Hardcoded "Blondie" | Dynamic (any model) |
| Batch Processing | Manual one-by-one | Parallel (3+ at once) |
| Resume | No | Yes, automatic |
| Folder Structure | Mixed/unclear | Organized per model |
| S3 Structure | Flat/mixed | Model-specific folders |
| Processing Speed | ~8-12 min/image | Same, but 3x parallel |
| Multi-model | Difficult | Easy |

---

## Questions?

- **How do I add a new model?** Just create the folder structure and run the scripts with the new model name
- **Can I process multiple models at once?** Yes, open separate terminal windows for each
- **What if processing fails?** Check the logs in `logs/{model-name}/`, fix the issue, and run again (resume will skip completed files)
- **How do I change the number of parallel jobs?** Pass the number as the 4th argument: `./batch-process-model.sh model src targets 5`
