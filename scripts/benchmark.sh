#!/bin/bash
# =============================================================================
# benchmark.sh - Run SGEMM at N=32,64,128,256 and report efficiency
# Usage: cd ~/vortex/build && ~/CS254A_Lab1/scripts/benchmark.sh [config_file]
# =============================================================================

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${1:-$LAB_DIR/configs/VX_config.toml}"
VORTEX_SGEMM="$HOME/vortex/build/tests/regression/sgemm"

# ---- Copy student files into Vortex ----
if [ -d "$LAB_DIR/sgemm" ] && [ -f "$LAB_DIR/sgemm/kernel.cpp" ]; then
    cp "$LAB_DIR/sgemm/kernel.cpp" "$VORTEX_SGEMM/"
    cp "$LAB_DIR/sgemm/common.h"   "$VORTEX_SGEMM/" 2>/dev/null
    cp "$LAB_DIR/sgemm/main.cpp"   "$VORTEX_SGEMM/" 2>/dev/null
fi

# ---- Read config ----
read_val() {
    grep -E "^$1\s*=" "$CONFIG_FILE" | head -1 | awk -F'=' '{print $2}' | tr -d ' "' | tr -d "'"
}

CONFIGS=""
if [ -f "$CONFIG_FILE" ]; then
    NUM_THREADS=$(read_val NUM_THREADS)
    NUM_WARPS=$(read_val NUM_WARPS)
    NUM_FPU_BLOCKS=$(read_val NUM_FPU_BLOCKS)
    NUM_ALU_BLOCKS=$(read_val NUM_ALU_BLOCKS)
    NUM_LSU_BLOCKS=$(read_val NUM_LSU_BLOCKS)
    ISSUE_WIDTH=$(read_val ISSUE_WIDTH)
    DCACHE_SIZE=$(read_val DCACHE_SIZE)
    SMEM_SIZE=$(read_val SMEM_SIZE)
    L2_ENABLE=$(read_val L2_ENABLE)

    [ -n "$NUM_THREADS" ]    && CONFIGS="$CONFIGS -DNUM_THREADS=$NUM_THREADS"
    [ -n "$NUM_WARPS" ]      && CONFIGS="$CONFIGS -DNUM_WARPS=$NUM_WARPS"
    [ -n "$NUM_FPU_BLOCKS" ] && CONFIGS="$CONFIGS -DNUM_FPU_BLOCKS=$NUM_FPU_BLOCKS"
    [ -n "$NUM_ALU_BLOCKS" ] && CONFIGS="$CONFIGS -DNUM_ALU_BLOCKS=$NUM_ALU_BLOCKS"
    [ -n "$NUM_LSU_BLOCKS" ] && CONFIGS="$CONFIGS -DNUM_LSU_BLOCKS=$NUM_LSU_BLOCKS"
    [ -n "$ISSUE_WIDTH" ]    && CONFIGS="$CONFIGS -DISSUE_WIDTH=$ISSUE_WIDTH"
    [ -n "$DCACHE_SIZE" ]    && CONFIGS="$CONFIGS -DDCACHE_SIZE=$DCACHE_SIZE"
    [ -n "$SMEM_SIZE" ]      && CONFIGS="$CONFIGS -DSMEM_SIZE=$SMEM_SIZE"
    [ "$L2_ENABLE" = "true" ] && CONFIGS="$CONFIGS -DL2_ENABLE"
fi

NUM_THREADS="${NUM_THREADS:-4}"
NUM_FPU_BLOCKS="${NUM_FPU_BLOCKS:-1}"
PEAK=$(( 2 * NUM_THREADS * NUM_FPU_BLOCKS ))

SIZES=(32 64 128 256)

echo "============================================================"
echo "  CS254A Lab 1 - SGEMM Benchmark"
echo "============================================================"
echo "  NUM_THREADS:    $NUM_THREADS"
echo "  NUM_FPU_BLOCKS: $NUM_FPU_BLOCKS"
echo "  Peak:           $PEAK flops/cycle"
echo "  50% target:     $(( PEAK / 2 )) flops/cycle"
echo "============================================================"
echo ""

declare -a R_N R_CYCLES R_FLOPS R_ACHIEVED R_EFF

for i in "${!SIZES[@]}"; do
    N=${SIZES[$i]}
    FLOPS=$(( 2 * N * N * N ))

    echo "------------------------------------------------------------"
    echo "  Running N=$N  (FLOPs = $FLOPS)"
    echo "------------------------------------------------------------"

    OUTPUT=$(CONFIGS="$CONFIGS" ./ci/blackbox.sh --driver=simx --cores=1 \
        --app=sgemm --args="-n$N" --rebuild=1 2>&1)

    if echo "$OUTPUT" | grep -q "PASSED"; then
        CYCLES=$(echo "$OUTPUT" | grep "^PERF:" | tail -1 | sed 's/.*cycles=\([0-9]*\).*/\1/')
        if [ -n "$CYCLES" ] && [ "$CYCLES" -gt 0 ]; then
            ACHIEVED=$(awk "BEGIN {printf \"%.4f\", $FLOPS / $CYCLES}")
            EFF=$(awk "BEGIN {printf \"%.2f\", ($FLOPS / $CYCLES) / $PEAK * 100}")
            R_N[$i]=$N; R_CYCLES[$i]=$CYCLES; R_FLOPS[$i]=$FLOPS
            R_ACHIEVED[$i]=$ACHIEVED; R_EFF[$i]=$EFF
            echo "  -> PASSED | cycles=$CYCLES | achieved=$ACHIEVED flops/cycle | efficiency=$EFF%"
        else
            R_N[$i]=$N; R_CYCLES[$i]="ERR"; R_FLOPS[$i]=$FLOPS
            R_ACHIEVED[$i]="ERR"; R_EFF[$i]="ERR"
            echo "  -> PASSED but could not parse cycles"
        fi
    else
        R_N[$i]=$N; R_CYCLES[$i]="FAIL"; R_FLOPS[$i]=$FLOPS
        R_ACHIEVED[$i]="FAIL"; R_EFF[$i]="FAIL"
        echo "  -> FAILED (kernel correctness error)"
    fi
    echo ""
done

echo ""
echo "============================================================"
echo "  BENCHMARK RESULTS"
echo "============================================================"
echo "  Peak: $PEAK flops/cycle"
echo "  (NUM_THREADS=$NUM_THREADS, NUM_FPU_BLOCKS=$NUM_FPU_BLOCKS)"
echo ""
printf "  %-6s %-12s %-14s %-16s %-10s\n" "N" "FLOPs" "Cycles" "Achieved(f/c)" "Eff(%)"
echo "  ---------------------------------------------------------------"
for i in "${!SIZES[@]}"; do
    printf "  %-6s %-12s %-14s %-16s %-10s\n" \
        "${R_N[$i]}" "${R_FLOPS[$i]}" "${R_CYCLES[$i]}" \
        "${R_ACHIEVED[$i]}" "${R_EFF[$i]}"
done
echo "  ---------------------------------------------------------------"
echo "  50% target: $(( PEAK / 2 )) flops/cycle"
echo "============================================================"
