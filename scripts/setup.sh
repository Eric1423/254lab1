#!/bin/bash
# =============================================================================
# setup.sh - One-time setup for CS254A Lab 1
# =============================================================================

set -e

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VORTEX_DIR="$HOME/vortex"
SGEMM_SRC="$VORTEX_DIR/build/tests/regression/sgemm"

echo "============================================="
echo "  CS254A Lab 1 - Environment Setup"
echo "============================================="
echo "  Lab repo: $LAB_DIR"
echo ""

# ---- Detect sudo ----
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
elif command -v sudo &> /dev/null; then
    SUDO="sudo"
else
    SUDO=""
    echo "WARNING: No sudo available. Skipping system package install."
    echo "Make sure build-essential, cmake, ccache, verilator, git, wget are installed."
    echo ""
    SKIP_INSTALL=true
fi

# ---- Step 1: Install system dependencies ----
if [ "$SKIP_INSTALL" != "true" ]; then
    echo "[1/7] Installing system dependencies..."
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq \
        build-essential binutils python3 uuid-dev \
        git wget cmake ccache verilator
else
    echo "[1/7] Skipping system dependencies (no sudo)..."
fi

# ---- Step 2: Clone Vortex ----
echo ""
echo "[2/7] Cloning Vortex repository..."
if [ -d "$VORTEX_DIR" ]; then
    echo "  Vortex directory already exists at $VORTEX_DIR, skipping clone."
else
    git clone --depth=1 --recursive https://github.com/vortexgpgpu/vortex.git "$VORTEX_DIR"
fi

# ---- Step 3: Configure build ----
echo ""
echo "[3/7] Configuring build..."
cd "$VORTEX_DIR"
if [ ! -d "build" ]; then
    mkdir build
fi
cd build
../configure --xlen=32 --tooldir=$HOME/tools

# ---- Step 4: Install toolchain ----
echo ""
echo "[4/7] Installing RISC-V toolchain..."
./ci/toolchain_install.sh --all

# ---- Step 5: Source environment and build ----
echo ""
echo "[5/7] Building Vortex..."
source ./ci/toolchain_env.sh
make -s

# Add toolchain env to bashrc
if ! grep -q "toolchain_env.sh" ~/.bashrc 2>/dev/null; then
    echo "source $VORTEX_DIR/build/ci/toolchain_env.sh" >> ~/.bashrc
    echo "  Added toolchain_env.sh to ~/.bashrc"
fi

# ---- Step 6: Copy SGEMM baseline files ----
echo ""
echo "[6/7] Copying SGEMM files..."

# Copy to baseline/ (reference, don't touch)
cp "$SGEMM_SRC/kernel.cpp" "$LAB_DIR/baseline/"
cp "$SGEMM_SRC/main.cpp"   "$LAB_DIR/baseline/"
cp "$SGEMM_SRC/common.h"   "$LAB_DIR/baseline/"
cp "$LAB_DIR/configs/VX_config.toml" "$LAB_DIR/baseline/"
echo "  Copied baseline files to $LAB_DIR/baseline/"

# Copy to sgemm/ (student workspace)
cp "$SGEMM_SRC/kernel.cpp" "$LAB_DIR/sgemm/"
cp "$SGEMM_SRC/main.cpp"   "$LAB_DIR/sgemm/"
cp "$SGEMM_SRC/common.h"   "$LAB_DIR/sgemm/"
echo "  Copied working files to $LAB_DIR/sgemm/"

# ---- Step 7: Run baseline test ----
echo ""
echo "[7/7] Running baseline SGEMM test..."
./ci/blackbox.sh --driver=simx --cores=1 --app=sgemm --args="-n64"

echo ""
echo "============================================="
echo "  Setup complete!"
echo ""
echo "  Vortex:          $VORTEX_DIR/build"
echo "  Your workspace:  $LAB_DIR/sgemm/"
echo "    - kernel.cpp   (optimize this)"
echo "    - main.cpp     (modify if needed for shared memory)"
echo "    - common.h     (change BLOCK_SIZE, GRID_SIZE)"
echo "  HW config:       $LAB_DIR/configs/VX_config.toml"
echo "  Baseline copies: $LAB_DIR/baseline/"
echo ""
echo "  To run after editing:"
echo "    cd $VORTEX_DIR/build"
echo "    $LAB_DIR/scripts/run_sgemm.sh $LAB_DIR/configs/VX_config.toml"
echo ""
echo "  To benchmark:"
echo "    $LAB_DIR/scripts/benchmark.sh $LAB_DIR/configs/VX_config.toml"
echo "============================================="
