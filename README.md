# AI Model Training Image Generator

Automatically create training datasets by swapping your AI model's face onto multiple body images using MaxStudio API.

## 🎯 What This Does

Takes one face (your AI model) + multiple body images → Creates high-quality training images with your model's face swapped onto each body.

**Each image goes through:**
1. ✨ Enhancement (improve quality)
2. 🔍 Face Detection (find where the face is)
3. 🔄 Face Swap (replace with your model's face)
4. ✨ Final Enhancement (maximum quality)

## 📁 Folder Structure

```
models/
├── Paris/                    # Your model folder (use any name)
│   ├── source.jpg           # Your AI model's face
│   └── targets/             # Body images to swap onto
│       ├── image1.jpg
│       ├── image2.jpg
│       ├── image3.jpg
│       └── ... (add 20-25 images)
│
├── Paris_Training/          # Output (auto-created)
│   ├── README.txt          # Processing summary
│   ├── image1_final.jpg
│   ├── image2_final.jpg
│   └── ...
│
└── face-swap-batch.sh      # The script
```

## 🚀 Quick Start

### 1. Setup Your Model Folder

```bash
# Create folders
mkdir -p Paris/targets

# Add your images:
# - Paris/source.jpg ← Your AI model's face
# - Paris/targets/*.jpg ← All the body images (20-25 images)
```

### 2. Run the Script

```bash
./face-swap-batch.sh Paris
```

### 3. Get Results

All processed images will be in `Paris_Training/` ready for AI model training!

## 📝 Typical Workflow with Claude

Since you'll often upload images and ask Claude to organize them:

### Option 1: Upload and Ask Claude
1. Upload all your images to GitHub
2. Tell Claude: "Organize these into Paris folder structure"
3. Claude will move files to correct locations
4. Run: `./face-swap-batch.sh Paris`

### Option 2: Manual Setup
```bash
# Create structure
mkdir -p Paris/targets

# Move your face image
mv my-model-face.jpg Paris/source.jpg

# Move body images
mv body*.jpg Paris/targets/

# Run processing
./face-swap-batch.sh Paris
```

## 💡 Examples

### Single Model
```bash
./face-swap-batch.sh Paris
# Creates: Paris_Training/ with all processed images
```

### Multiple Models
```bash
# Model 1
./face-swap-batch.sh Paris
# Creates: Paris_Training/

# Model 2
./face-swap-batch.sh Luna
# Creates: Luna_Training/

# Model 3
./face-swap-batch.sh Alex
# Creates: Alex_Training/
```

## 📊 Output

### Training Images
- High quality (typically 1-2MB each)
- Face-swapped and enhanced twice
- Named: `originalname_final.jpg`

### README.txt
Each output folder includes a summary:
- When processed
- How many images succeeded/failed
- What was done to each image

## 🔧 Requirements

- Python 3 with `requests` and `boto3` libraries
- MaxStudio API key
- AWS S3 account with credentials
- Internet connection

### Setup Credentials

1. **MaxStudio API**: Update `API_KEY` in scripts
2. **AWS S3**: Create `.aws-credentials` file (see `.aws-credentials.example`):
   ```bash
   AWS_ACCESS_KEY_ID=your_key_here
   AWS_SECRET_ACCESS_KEY=your_secret_here
   AWS_BUCKET_NAME=your_bucket
   AWS_REGION=us-east-2
   ```
3. Load credentials: `source .aws-credentials && export $(cat .aws-credentials | grep -v '^#' | xargs)`

## 🐛 Troubleshooting

### "No faces detected"
- Make sure target images have clear, visible faces
- Faces should be well-lit and not obscured
- Try a different target image

### "Upload failed"
- Check internet connection
- Image might be too large (>5MB)
- Try again (temporary service issue)

### "Enhancement failed"
- Usually temporary API issue
- Script will continue with non-enhanced version
- You can re-run for that specific image

## 📋 File Types Supported

- JPG/JPEG
- PNG
- Case-insensitive (jpg, JPG, jpeg, JPEG, etc.)

## 🎨 Best Practices

### Source Face (Your Model)
- High resolution
- Clear, front-facing
- Good lighting
- Neutral expression works best

### Target Bodies
- 20-25 images recommended
- Variety of poses/outfits
- Clear faces in target images
- Good lighting
- Resolution: 1000x1000px or higher

## 🚫 What NOT to Do

- ❌ Don't use obscured faces (masks, sunglasses)
- ❌ Don't use images >5MB (compress first)
- ❌ Don't use very low resolution (<500px)
- ❌ Don't use images with multiple faces (script uses first detected)

## 🔐 API Key

The MaxStudio API key is embedded in `face-swap-batch.sh` for testing.

For production, set it as an environment variable:
```bash
export MAXSTUDIO_API_KEY="your-key-here"
# Then update script to use: os.environ.get('MAXSTUDIO_API_KEY')
```

## 📦 What's Included

- `face-swap-batch.sh` - Main batch processing script
- `face-swap.sh` - Single image testing script (for development)
- `index.html` - Web interface (requires Vercel proxy)
- `api/` - Vercel serverless functions (for web version)
- `worker.js` - Cloudflare Worker proxy (alternative)

## 🌐 Web Version (Optional)

There's also a web interface at `index.html` but it requires deploying the Vercel proxy functions. The command-line version is simpler and works immediately.

## 💬 Common Questions

**Q: Can I process multiple models at once?**
A: Run the script separately for each model. It's safer and you can monitor each one.

**Q: How long does it take?**
A: ~2-3 minutes per image (enhancement, detection, swap, final enhancement). For 25 images: ~50-75 minutes.

**Q: Can I pause and resume?**
A: No, but you can organize targets into batches. Process 10 at a time if needed.

**Q: What if I want to re-process one image?**
A: Put just that image in targets/ and re-run. It won't duplicate existing files.

## 📞 Support

If something breaks:
1. Check the error message in terminal
2. Look at `ModelName_Training/README.txt` for details
3. Re-run the script (it's safe to retry)
4. Ask Claude for help with the error message

## 🎉 Success!

When done, you'll have a clean `ModelName_Training/` folder with:
- All processed images ready for AI training
- README.txt with full details
- Terminal confirmation message

Upload the entire `ModelName_Training/` folder to your AI training service!

---

**Generated with MaxStudio API** | [GitHub](https://github.com/atlasreach/models)
