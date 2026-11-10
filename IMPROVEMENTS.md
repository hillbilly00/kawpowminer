# kawpowminer Improvements Draft

This branch tracks proposed improvements to the forked kawpowminer (from RavenCommunity/kawpowminer ~1.2.4).

## High-Priority Fixes

### 1. Eliminate duplicate shares
On nodes/pools that re-issue the same work under a new job ID after an accepted share, the current miner restarts nonce search from a low startNonce, causing ~11% refused shares (observed on Quai KawPoW nodes).

**CUDA:** See `patches/nonce-randomization.patch` and the code snippet below.

**OpenCL:** See `patches/opencl-nonce-randomization.patch`.

Ready-to-apply change in `libethash-cuda/CUDAMiner.cpp` (workLoop):

```cpp
// Randomize starting nonce on every new job to avoid duplicate shares
uint64_t start_nonce = current.startNonce;
static thread_local std::mt19937_64 rng{std::random_device{}()};
std::uniform_int_distribution<uint64_t> dist;
start_nonce = dist(rng);

search(current.header.data(), upper64OfBoundary, start_nonce, w);
```

Equivalent change in `libethash-cl/CLMiner.cpp` (when header changes):

```cpp
static thread_local std::mt19937_64 rng{std::random_device{}()};
std::uniform_int_distribution<uint64_t> dist;
startNonce = dist(rng);
```

This matches the approach used by the Rust quai-kawpow-miner which reports zero refused shares on the same workload.

### 2. CPU verification of every share
Before calling `Farm::f().submitProof(...)` (in both CUDAMiner::search and CLMiner::workLoop), verify the solution on the CPU.

Full patch sketch: `patches/cpu-share-verification.patch`

It uses the existing `progpow::hash` / `progpow::verify` API (from the ethash/ProgPoW library already in the tree) to discard any GPU solution that fails CPU verification. The Farm already has a `noEval` flag that can optionally skip this check.

The patch is intentionally a sketch (commented blocks) so the exact boundary conversion and epoch-context access can be adjusted to the current code. The goal is to drop invalid shares instead of sending them to the pool.

### 3. Modern CUDA architecture support
Update NVRTC flags and device detection for compute capability 8.0+ (Ampere) and 8.9/9.0 (Ada). Improve defaults for RTX 30/40 series and LHR cards.

### 4. Build system modernization
Reduce reliance on outdated Hunter; improve CMake for Ubuntu 22.04+/24.04 and current CUDA toolkits.

## Modern Ubuntu Build Notes (22.04 / 24.04+)

The original 1.2.4-era code does **not** compile cleanly on Ubuntu 24.04 (or later) out of the box. The main blockers are:

- Outdated Hunter package manager (v0.23.214) that often fails to fetch/build dependencies.
- NVRTC / CUDA library path changes (Ubuntu 20.04+ places libs under `/usr/lib/x86_64-linux-gnu` or versioned CUDA paths).
- Newer GCC (13+ on 24.04) being stricter than the compilers the code was tested with.
- Hard-coded older compute capabilities and `find_library` calls that no longer locate `libnvrtc` / `libcuda`.

### Recommended approach

**Most reliable path today:** Use the Rust `quai-kawpow-miner` instead. It only needs the NVIDIA driver + NVRTC at runtime and builds cleanly with a modern Rust toolchain.

If you still want to build this C++ fork:

1. Prefer **Ubuntu 22.04** + CUDA 11.x or 12.x. 24.04 is possible but requires more manual fixes.
2. Install base packages:
   ```bash
   sudo apt update
   sudo apt install build-essential cmake git libboost-all-dev \
     ocl-icd-opencl-dev mesa-common-dev \
     nvidia-driver-XXX cuda-toolkit-XX   # match your card / desired CUDA
   ```
3. **NVRTC library workaround** (common failure point). In `libethash-cuda/CMakeLists.txt`, replace the two `find_library` lines with something more permissive:
   ```cmake
   # More tolerant lookup for modern Ubuntu / multi-version CUDA
   find_library(CUDA_nvrtc_LIBRARY NAMES nvrtc
     PATHS ${CUDA_TOOLKIT_ROOT_DIR} /usr/lib/x86_64-linux-gnu /usr/local/cuda/lib64
     PATH_SUFFIXES lib64 lib lib/x64 lib64/stubs lib/x64/stubs
     NO_DEFAULT_PATH)
   find_library(CUDA_cuda_LIBRARY NAMES cuda
     PATHS ${CUDA_TOOLKIT_ROOT_DIR} /usr/lib/x86_64-linux-gnu /usr/local/cuda/lib64
     PATH_SUFFIXES lib64 lib lib/x64 lib64/stubs lib/x64/stubs
     NO_DEFAULT_PATH)
   # Fallback if still not found
   if(NOT CUDA_nvrtc_LIBRARY)
     find_library(CUDA_nvrtc_LIBRARY NAMES nvrtc)
   endif()
   if(NOT CUDA_cuda_LIBRARY)
     find_library(CUDA_cuda_LIBRARY NAMES cuda)
   endif()
   ```
   Alternatively, some users simply hard-link with `-lnvrtc -lcuda` after ensuring the libs are on the default search path (`ldconfig`).

4. If Hunter fails, try system packages where possible or temporarily disable Hunter packages that already exist on the system (Boost, jsoncpp).
5. For CUDA 12+ / compute capability 8.6–9.0 cards, you may also want to extend the `-gencode` list in the same `CMakeLists.txt` (add `sm_89`, `sm_90`, etc.).

### Known historical fixes
- Ubuntu 20.04 NVRTC path issues were discussed in RavenCommunity/kawpowminer PR #37 and related comments.
- Binary releases existed for Ubuntu 18.04 / 20.04 + CUDA 11, but nothing official for 22.04+ or 24.04.

After applying the nonce-randomization patches, rebuild and test share acceptance on your target pool/node before relying on it for production.

## Longer-term
- Prometheus metrics and better API stats
- Optional systemd service example
- Consider a host-side rewrite in Rust while keeping the CUDA kernels (see quai-kawpow-miner for a working reference)

---
Authored / coordinated by hillbilly00
