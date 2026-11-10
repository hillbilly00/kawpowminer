#!/usr/bin/env bash
# XMR-style dependency builder for kawpowminer
# Downloads and builds selected libraries into ./deps so CMake can find them
# without Hunter.
#
# Usage:
#   chmod +x scripts/build_deps.sh
#   ./scripts/build_deps.sh
#   cd build && cmake .. -DHUNTER_ENABLED=OFF -DCMAKE_PREFIX_PATH=../deps -DETHASHCUDA=OFF -DETHASHCL=ON
#
# Extend this script with Boost, jsoncpp, etc. as needed.

set -euo pipefail

DEPS_DIR="$(cd "$(dirname "$0")/.." && pwd)/deps"
BUILD_DIR="/tmp/kawpow-deps-build"
mkdir -p "$DEPS_DIR" "$BUILD_DIR"

echo "Building dependencies into: $DEPS_DIR"

# Compatible ethash (v0.6.0 has progpow.hpp expected by this miner)
if [ ! -d "$BUILD_DIR/ethash" ]; then
  echo "Cloning ethash v0.6.0..."
  git clone --depth 1 --branch v0.6.0 https://github.com/chfast/ethash.git "$BUILD_DIR/ethash"
fi

cd "$BUILD_DIR/ethash"
# Disable tests/benchmarks so Hunter is not pulled in
sed -i '/add_subdirectory(test)/s/^/#/' CMakeLists.txt || true
sed -i '/add_subdirectory(benchmarks)/s/^/#/' CMakeLists.txt || true
sed -i '/add_subdirectory(benchmark)/s/^/#/' CMakeLists.txt || true

cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"
cmake --build build --parallel "$(nproc)"
cmake --install build

# Place a compatible CLI11 single header (v1.9.1) where the code expects it
mkdir -p "$DEPS_DIR/include/CLI"
if [ ! -f "$DEPS_DIR/include/CLI/CLI.hpp" ]; then
  echo "Downloading CLI11 v1.9.1 single header..."
  curl -L https://github.com/CLIUtils/CLI11/releases/download/v1.9.1/CLI11.hpp \
    -o "$DEPS_DIR/include/CLI/CLI.hpp"
fi

echo ""
echo "Done. ethash + CLI11 installed to $DEPS_DIR"
echo ""
echo "Next steps:"
echo "  1. Install system packages:"
echo "     sudo apt install build-essential cmake git libboost-all-dev libjsoncpp-dev ocl-icd-opencl-dev"
echo "     # Also create the jsoncpp include symlink if needed:"
echo "     sudo ln -sf /usr/include/jsoncpp/json /usr/include/json"
echo "  2. Configure (OpenCL only example):"
echo "     mkdir -p build && cd build"
echo "     cmake .. -DHUNTER_ENABLED=OFF -DCMAKE_PREFIX_PATH=../deps -DETHASHCUDA=OFF -DETHASHCL=ON"
echo "  3. Build: make -j\$(nproc)"
echo ""
echo "To add more libraries, extend this script following the ethash pattern."
