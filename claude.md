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
