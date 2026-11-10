#!/usr/bin/env bash
# XMR-style dependency builder for kawpowminer
# Downloads and builds selected libraries into ./deps so CMake can find them
# without Hunter.
#
# Usage:
#   chmod +x scripts/build_deps.sh
#   ./scripts/build_deps.sh
#   cd build && cmake .. -DHUNTER_ENABLED=OFF -DCMAKE_PREFIX_PATH=../deps
#
# Extend this script with Boost, jsoncpp, etc. as needed.

set -euo pipefail

DEPS_DIR="$(cd "$(dirname "$0")/.." && pwd)/deps"
BUILD_DIR="/tmp/kawpow-deps-build"
mkdir -p "$DEPS_DIR" "$BUILD_DIR"

echo "Building dependencies into: $DEPS_DIR"

# Example: modern ethash / progpow (adjust tag as desired)
if [ ! -d "$BUILD_DIR/ethash" ]; then
  echo "Cloning ethash..."
  git clone --depth 1 --branch v1.0.1 https://github.com/chfast/ethash.git "$BUILD_DIR/ethash" || \
    git clone --depth 1 https://github.com/chfast/ethash.git "$BUILD_DIR/ethash"
fi

cd "$BUILD_DIR/ethash"
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS_DIR"
cmake --build build --parallel "$(nproc)"
cmake --install build

echo ""
echo "Done. ethash installed to $DEPS_DIR"
echo ""
echo "Next steps:"
echo "  1. Install system packages for the rest (Boost, jsoncpp, OpenCL):"
echo "     sudo apt install libboost-all-dev libjsoncpp-dev ocl-icd-opencl-dev"
echo "  2. Configure kawpowminer with Hunter disabled:"
echo "     mkdir -p build && cd build"
echo "     cmake .. -DHUNTER_ENABLED=OFF -DCMAKE_PREFIX_PATH=../deps"
echo "  3. Build as usual."
echo ""
echo "To add more libraries, extend this script following the ethash pattern."
