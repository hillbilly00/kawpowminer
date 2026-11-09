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

## Longer-term
- Prometheus metrics and better API stats
- Optional systemd service example
- Consider a host-side rewrite in Rust while keeping the CUDA kernels (see quai-kawpow-miner for a working reference)

---
Authored / coordinated by hillbilly00
