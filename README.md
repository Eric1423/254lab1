# CS254A Lab 1: SGEMM Roofline Analysis on Vortex GPGPU

## Objective

Optimize SGEMM (Single-precision General Matrix Multiply) on the [Vortex](https://github.com/vortexgpgpu/vortex) RISC-V GPGPU through software-hardware co-optimization. Your goal is to achieve **≥50% of peak performance on a single core**.

**Peak performance:**
```
Peak = 2 × NUM_THREADS × NUM_FPU_BLOCKS  (flops/cycle)
```

---

## Repository Structure

```
CS254A_Lab1/
├── sgemm/                  ← YOUR WORKSPACE (edit these)
│   ├── kernel.cpp          ← SGEMM kernel (optimize this)
│   ├── main.cpp            ← Host code (modify for shared memory)
│   └── common.h            ← Block/grid size defines
├── configs/
│   └── VX_config.toml      ← Hardware config (edit this)
├── baseline/               ← Original copies (DO NOT EDIT)
│   ├── kernel.cpp
│   ├── main.cpp
│   ├── common.h
│   └── VX_config.toml
├── scripts/
│   ├── setup.sh            ← One-time setup
│   ├── run_sgemm.sh        ← Run single test
│   └── benchmark.sh        ← Run N=32,64,128,256
```

---

## Environment Requirements

Vortex requires **x86_64 Linux**. The RISC-V toolchain only provides x86_64 prebuilt binaries.

| Your Machine | What to Do |
|---|---|
| Windows (Intel/AMD) | Install WSL2: PowerShell Admin → `wsl --install -d Ubuntu-22.04`, restart |
| Mac (Apple Silicon) | Install Docker Desktop, then: `docker run -it --platform linux/amd64 --name vortex ubuntu:22.04 /bin/bash` |
| Mac (Intel) | Docker or native Ubuntu VM |
| Linux (x86_64) | You're ready |

> To re-enter Docker later: `docker start -i vortex`

## Setup

### 1. Extract and setup
Extract the provided `CS254A_Lab1.zip` inside your Linux environment:
```bash
unzip CS254A_Lab1.zip
cd CS254A_Lab1
chmod +x scripts/*.sh
./scripts/setup.sh
```

This clones Vortex, installs the RISC-V toolchain, builds the simulator, copies the baseline SGEMM files into `sgemm/` and `baseline/`, and runs a baseline test. Takes ~10-20 minutes.

### 2. Source toolchain (every new terminal)
```bash
source ~/vortex/build/ci/toolchain_env.sh
```

---

## Running SGEMM

### Single run
```bash
cd ~/vortex/build
~/CS254A_Lab1/scripts/run_sgemm.sh ~/CS254A_Lab1/configs/VX_config.toml
```

### Benchmark (N=32, 64, 128, 256)
```bash
cd ~/vortex/build
~/CS254A_Lab1/scripts/benchmark.sh ~/CS254A_Lab1/configs/VX_config.toml
```

### Direct run (no config file, Vortex defaults)
```bash
cd ~/vortex/build
./ci/blackbox.sh --driver=simx --cores=1 --app=sgemm --args="-n64"
```

**How it works:** `run_sgemm.sh` copies your files from `sgemm/` into Vortex, reads hardware config from `VX_config.toml`, and calls `blackbox.sh`.

---

## What You Can Modify

| File | Purpose |
|------|---------|
| `sgemm/kernel.cpp` | Optimize the SGEMM algorithm (tiling, shared memory, etc.) |
| `sgemm/main.cpp` | Modify if needed for shared memory allocation / kernel launch |
| `sgemm/common.h` | Change `BLOCK_SIZE_X/Y/Z`, `GRID_SIZE_X/Y/Z` |
| `configs/VX_config.toml` | Hardware: `NUM_THREADS`, `NUM_WARPS`, `NUM_FPU_BLOCKS`, caches |

**Do NOT modify** any other Vortex source files.

**Fixed parameters (do not change):** `cores = 1`, `driver = simx`

---

## Calculating Performance

From the `PERF:` output line:

```
flops      = 2 × N³
achieved   = flops / cycles          (flops/cycle)
peak       = 2 × NUM_THREADS × NUM_FPU_BLOCKS
efficiency = (achieved / peak) × 100%
```

**Baseline example** (defaults, N=64):
```
flops    = 2 × 64³ = 524,288
cycles   = ~1,659,217
achieved = 524,288 / 1,659,217 ≈ 0.316 flops/cycle
peak     = 2 × 4 × 1 = 8
efficiency = 0.316 / 8 ≈ 3.95%
```

---

## Optimization Hints

1. **Tiling with shared memory** — Load tiles into local memory. See `tests/regression/sgemm2x/` in Vortex for a reference.
2. **Match block size to warp size** — Set `BLOCK_SIZE` to match `NUM_THREADS`.
3. **Increase FPU blocks** — More `NUM_FPU_BLOCKS` raises peak, but requires enough independent FP ops.
4. **Tune cache sizes** — Larger `DCACHE_SIZE` / `SMEM_SIZE` reduces memory stalls.
5. **Balance warps and threads** — More warps hide memory latency; more threads increase parallelism.

---

## Deliverables

Submit a **zip file** containing:

1. `sgemm/kernel.cpp` — Your optimized kernel
2. `sgemm/main.cpp` — Your modified host code (if changed)
3. `sgemm/common.h` — Your block/grid size configuration
4. `configs/VX_config.toml` — Your hardware configuration
5. **Benchmark output** — Copy-paste the output of `benchmark.sh`
6. **Report (PDF, 2-4 pages):**
   - Baseline results (efficiency % at N=32, 64, 128, 256)
   - Optimized results (efficiency % at N=32, 64, 128, 256)
   - What you changed and why
   - Roofline plot (baseline vs. optimized)
   - Analysis: compute-bound or memory-bound?

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `riscv32-unknown-elf-gcc: No such file` | `source ~/vortex/build/ci/toolchain_env.sh` |
| `Syntax error: "(" unexpected` | You're on ARM — need x86_64 Linux |
| blackbox.sh prints usage only | Use `--cores` not `--core` |
| `FAILED` | Kernel correctness bug — check your code |
| Simulator rebuilds every run | Expected when config changes |
| Need to restore baseline | Copy files from `baseline/` to `sgemm/` |
