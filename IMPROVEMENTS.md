# kawpowminer Improvements Draft

This branch tracks proposed improvements to the forked kawpowminer (from RavenCommunity/kawpowminer ~1.2.4).

## High-Priority Fixes

### 1. Eliminate duplicate shares
On nodes/pools that re-issue the same work under a new job ID after an accepted share, the current miner restarts nonce search from a low startNonce, causing ~11% refused shares (observed on Quai KawPoW nodes).

**Ready-to-apply change in `libethash-cuda/CUDAMiner.cpp`:**

1. Add `#include <random>` near the top of the file.
2. In `CUDAMiner::workLoop()`, replace the call to `search(...)` with the following:

```cpp
// Randomize starting nonce on every new job to avoid duplicate shares
// when pools/nodes re-issue the same work under a new job ID.
uint64_t start_nonce = current.startNonce;
static thread_local std::mt19937_64 rng{std::random_device{}()};
std::uniform_int_distribution<uint64_t> dist;
start_nonce = dist(rng);

// Eventually start searching
search(current.header.data(), upper64OfBoundary, start_nonce, w);
```

A unified diff is also available in `patches/nonce-randomization.patch`.

This matches the approach used by the Rust quai-kawpow-miner which reports zero refused shares on the same workload.

### 2. CPU verification of every share
Before submitting a share, verify it on the CPU using the same ProgPoW/KawPoW implementation. Discard GPU bugs instead of sending them.

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
