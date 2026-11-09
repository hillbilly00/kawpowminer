# kawpowminer Improvements Draft

This branch tracks proposed improvements to the forked kawpowminer (from RavenCommunity/kawpowminer ~1.2.4).

## High-Priority Fixes

### 1. Eliminate duplicate shares
On nodes/pools that re-issue the same work under a new job ID after an accepted share, the current miner restarts nonce search from a low startNonce, causing ~11% refused shares (observed on Quai KawPoW nodes).

**Proposed change in `libethash-cuda/CUDAMiner.cpp` (workLoop / search):**

When a new WorkPackage arrives, randomize the starting nonce instead of always using `w.startNonce`:

```cpp
// In workLoop(), before calling search():
uint64_t randomized_start = w.startNonce;
if (w.jobChanged || /* detect new job */) {
    // Use a random 64-bit offset so we don't re-search the same nonce space
    std::random_device rd;
    std::mt19937_64 gen(rd());
    std::uniform_int_distribution<uint64_t> dis;
    randomized_start = dis(gen);
}
search(current.header.data(), upper64OfBoundary, randomized_start, w);
```

Also track recently submitted nonces per header/job to skip them. This matches the approach used by the Rust quai-kawpow-miner which reports zero refused shares on the same workload.

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
