# kawpowminer Improvements Draft

This branch tracks proposed improvements to the forked kawpowminer (from RavenCommunity/kawpowminer ~1.2.4).

## Verified Ubuntu OpenCL Build (22.04+)

The following steps produce a working OpenCL binary on Ubuntu 22.04 after a fresh clone of this branch. Tested November 2026.

```bash
git clone -b improve-nonce-randomization --recursive https://github.com/hillbilly00/kawpowminer.git
cd kawpowminer

# System packages
sudo apt update
sudo apt install build-essential cmake git libboost-all-dev libjsoncpp-dev ocl-icd-opencl-dev

# jsoncpp header location fix (Ubuntu puts it under jsoncpp/)
sudo ln -sf /usr/include/jsoncpp/json /usr/include/json

# Build compatible ethash + CLI11 into deps/
chmod +x scripts/build_deps.sh
./scripts/build_deps.sh

# Configure and build (OpenCL only; CUDA disabled)
mkdir -p build && cd build
cmake .. -DHUNTER_ENABLED=OFF -DCMAKE_PREFIX_PATH=../deps -DETHASHCUDA=OFF -DETHASHCL=ON
make -j$(nproc)
```

Binary: `build/kawpowminer/kawpowminer`

### Notes from the successful build
- Hunter is disabled.
- ethash v0.6.0 is used (provides `progpow.hpp` and the expected API).
- CLI11 v1.9.1 single header is placed at `deps/include/CLI/CLI.hpp`.
- `jsoncpp_lib_static` was changed to system `jsoncpp` in `libpoolprotocols/CMakeLists.txt`.
- `find_package(CLI11)` and `CLI11::CLI11` link were removed; the header-only include is used instead.
- Boost placeholders (`_1`) require `using namespace boost::placeholders;` on modern Boost (already noted for EthGetworkClient.cpp).

OpenCL runtime (AMD) is still required at runtime (`amdgpu-pro` OpenCL, ROCm, or Mesa). `clinfo` must show a platform before the miner will detect GPUs.

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

### 3. Modern CUDA architecture support
Update NVRTC flags and device detection for compute capability 8.0+ (Ampere) and 8.9/9.0 (Ada).

### 4. Build system modernization
Reduce reliance on outdated Hunter; improve CMake for Ubuntu 22.04+/24.04 and current CUDA toolkits. See the verified OpenCL recipe above.

## Replacing Hunter

Hunter is the main source of build pain on modern Ubuntu. The verified path above uses Option B (deps script).

### Option A — Disable Hunter and use system packages
### Option B — XMR-style deps script (used in the verified recipe)
### Option C — CMake FetchContent (long-term)
### Option D — Update Hunter (not recommended)

## Console / Output Improvements

See `patches/compact-gpu-status.patch` for a sketch of a cleaner per-GPU status line.

## Longer-term
- Prometheus metrics and better API stats
- Optional systemd service example
- Consider a host-side rewrite in Rust while keeping the CUDA kernels

---
Authored / coordinated by hillbilly00
