#!/bin/bash

# Batch Face Swap Processing with Parallel Execution
# Usage: ./batch-process-model.sh <model_name> <source_face> <targets_dir> [parallel_jobs]

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <model_name> <source_face> <targets_dir> [parallel_jobs]"
    echo ""
    echo "Arguments:"
    echo "  model_name    - Name of the model (e.g., 'blondie', 'sarah', 'alex')"
    echo "  source_face   - Path to source face image"
    echo "  targets_dir   - Directory containing target body images"
    echo "  parallel_jobs - Number of parallel processes (default: 3)"
    echo ""
    echo "Example:"
    echo "  ./batch-process-model.sh blondie source/blondie-1.png targets/ 3"
    echo ""
    echo "Features:"
    echo "  - Processes all .jpg, .jpeg, .png images in targets_dir"
    echo "  - Runs multiple processes in parallel for faster processing"
    echo "  - Automatically skips already processed files (resume capability)"
    echo "  - Creates organized folder structure: {model_name}/outputs/"
    echo "  - Generates captions and metadata in dataset/{model_name}/"
    exit 1
fi

MODEL_NAME="$1"
SOURCE_FACE="$2"
TARGETS_DIR="$3"
PARALLEL_JOBS="${4:-3}"

# Validate inputs
if [ ! -f "$SOURCE_FACE" ]; then
    echo "Error: Source face file not found: $SOURCE_FACE"
    exit 1
fi

if [ ! -d "$TARGETS_DIR" ]; then
    echo "Error: Targets directory not found: $TARGETS_DIR"
    exit 1
fi

# Create log directory
LOG_DIR="logs/${MODEL_NAME}"
mkdir -p "$LOG_DIR"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Batch Face Swap Processing                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Model Name:       $MODEL_NAME"
echo "Source Face:      $SOURCE_FACE"
echo "Targets Dir:      $TARGETS_DIR"
echo "Parallel Jobs:    $PARALLEL_JOBS"
echo "Log Directory:    $LOG_DIR"
echo ""

# Find all target images
TARGET_FILES=$(find "$TARGETS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | sort)
TOTAL_COUNT=$(echo "$TARGET_FILES" | wc -l)

if [ "$TOTAL_COUNT" -eq 0 ]; then
    echo "Error: No image files found in $TARGETS_DIR"
    exit 1
fi

echo "Found $TOTAL_COUNT target image(s)"
echo ""

# Check for already processed files
PROCESSED_COUNT=0
TO_PROCESS=()

while IFS= read -r target_file; do
    if [ -z "$target_file" ]; then
        continue
    fi

    basename=$(basename "$target_file" | sed 's/\.[^.]*$//')
    output_file="${MODEL_NAME}/outputs/faceswapped/${basename}_swapped.jpg"

    if [ -f "$output_file" ]; then
        ((PROCESSED_COUNT++))
        echo "  ✓ Already processed: $(basename "$target_file")"
    else
        TO_PROCESS+=("$target_file")
    fi
done <<< "$TARGET_FILES"

REMAINING_COUNT=${#TO_PROCESS[@]}

echo ""
echo "Status:"
echo "  Already processed: $PROCESSED_COUNT"
echo "  Remaining:         $REMAINING_COUNT"
echo ""

if [ "$REMAINING_COUNT" -eq 0 ]; then
    echo "All files already processed! ✨"
    exit 0
fi

read -p "Process $REMAINING_COUNT file(s) with $PARALLEL_JOBS parallel jobs? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Starting batch processing..."
echo "════════════════════════════════════════════════════════════"
echo ""

# Track start time
START_TIME=$(date +%s)

# Process files in parallel using GNU parallel or xargs
process_file() {
    local target_file="$1"
    local model_name="$2"
    local source_face="$3"
    local log_dir="$4"

    local basename=$(basename "$target_file" | sed 's/\.[^.]*$//')
    local log_file="${log_dir}/${basename}.log"

    echo "[$(date '+%H:%M:%S')] Processing: $(basename "$target_file")"

    # Run face-swap-model.sh and capture output
    ./face-swap-model.sh "$model_name" "$source_face" "$target_file" > "$log_file" 2>&1

    if [ $? -eq 0 ]; then
        echo "[$(date '+%H:%M:%S')] ✓ Success: $(basename "$target_file")"
        return 0
    else
        echo "[$(date '+%H:%M:%S')] ✗ Failed: $(basename "$target_file") (see $log_file)"
        return 1
    fi
}

export -f process_file
export MODEL_NAME SOURCE_FACE LOG_DIR

# Check if GNU parallel is available
if command -v parallel &> /dev/null; then
    echo "Using GNU Parallel for processing..."
    echo ""

    printf '%s\n' "${TO_PROCESS[@]}" | \
        parallel -j "$PARALLEL_JOBS" --line-buffer \
        process_file {} "$MODEL_NAME" "$SOURCE_FACE" "$LOG_DIR"

    EXIT_CODE=$?
else
    echo "GNU Parallel not found, using xargs..."
    echo "Tip: Install parallel for better progress reporting: sudo apt-get install parallel"
    echo ""

    # Fallback to xargs
    printf '%s\n' "${TO_PROCESS[@]}" | \
        xargs -I {} -P "$PARALLEL_JOBS" bash -c 'process_file "$@"' _ {} "$MODEL_NAME" "$SOURCE_FACE" "$LOG_DIR"

    EXIT_CODE=$?
fi

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Batch Processing Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Total files:      $TOTAL_COUNT"
echo "Already done:     $PROCESSED_COUNT"
echo "Just processed:   $REMAINING_COUNT"
echo "Duration:         ${MINUTES}m ${SECONDS}s"
echo ""
echo "Output location:"
echo "  Images:         ${MODEL_NAME}/outputs/faceswapped/"
echo "  Captions:       dataset/${MODEL_NAME}/captions/"
echo "  Metadata:       dataset/${MODEL_NAME}/meta/meta.jsonl"
echo "  Logs:           ${LOG_DIR}/"
echo ""

# Check for failures
FAILED_COUNT=$(grep -l "✗" "$LOG_DIR"/*.log 2>/dev/null | wc -l)
if [ "$FAILED_COUNT" -gt 0 ]; then
    echo "⚠️  Warning: $FAILED_COUNT file(s) failed to process"
    echo "Check logs in $LOG_DIR/ for details"
    echo ""
fi

exit $EXIT_CODE
