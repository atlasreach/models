#!/bin/bash
# Quick progress checker for RunPod checkpoint testing

echo "🔍 CHECKPOINT TESTING PROGRESS"
echo "================================"
echo ""

# Check if process is running
if pgrep -f "batch_test_lora.py" > /dev/null; then
    echo "✅ Status: RUNNING"
else
    echo "⏸️  Status: NOT RUNNING (paused or completed)"
fi

echo ""
echo "📊 Images Generated:"
cd /workspace/ComfyUI/output/
echo "   250 steps: $(ls test_checkpoint_00000250_*.png 2>/dev/null | wc -l)/5"
echo "   500 steps: $(ls test_checkpoint_00000500_*.png 2>/dev/null | wc -l)/5"
echo "   750 steps: $(ls test_checkpoint_00000750_*.png 2>/dev/null | wc -l)/5"
echo "  1000 steps: $(ls test_checkpoint_00001000_*.png 2>/dev/null | wc -l)/5"
echo "  1250 steps: $(ls test_checkpoint_00001250_*.png 2>/dev/null | wc -l)/5"
echo "  1500 steps: $(ls test_checkpoint_00001500_*.png 2>/dev/null | wc -l)/5"
echo " Final step: $(ls test_checkpoint_final_*.png 2>/dev/null | wc -l)/5"

TOTAL=$(ls test_checkpoint_*.png 2>/dev/null | wc -l)
echo ""
echo "📈 Total Progress: $TOTAL/35 images ($(( TOTAL * 100 / 35 ))%)"

echo ""
echo "📝 Latest Log Lines:"
tail -10 /workspace/checkpoint_test.log 2>/dev/null || echo "   (log file not found)"

echo ""
echo "================================"
echo "💡 Commands:"
echo "   Watch live:  tail -f /workspace/checkpoint_test.log"
echo "   List images: ls -lh /workspace/ComfyUI/output/test_checkpoint_*.png"
echo "   View images: Open ComfyUI at port 8188"
