#!/usr/bin/env bash
# Build local dependencies (ethash + CLI11) into ./deps
# Replaces Hunter for Ubuntu builds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS="${ROOT}/deps"
mkdir -p "${DEPS}"
cd "${ROOT}"

echo "=== Building ethash ==="
if [ ! -d ethash ]; then
  git clone --depth 1 https://github.com/chfast/ethash.git
fi
mkdir -p ethash/build
cd ethash/build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${DEPS}" -DETHASH_BUILD_TESTS=OFF -DETHASH_BUILD_GLOBAL_CONTEXT=OFF
cmake --build . -j"$(nproc)"
cmake --install .
cd "${ROOT}"

echo "=== Installing CLI11 (header-only) ==="
mkdir -p "${DEPS}/include"
if [ ! -f "${DEPS}/include/CLI/CLI.hpp" ]; then
  curl -fsSL -o /tmp/CLI11.hpp https://github.com/CLIUtils/CLI11/releases/download/v2.4.2/CLI11.hpp
  mkdir -p "${DEPS}/include/CLI"
  mv /tmp/CLI11.hpp "${DEPS}/include/CLI/CLI.hpp"
fi

# Also create a simple CMake config so find_package(CLI11) works if needed
mkdir -p "${DEPS}/share/cmake/CLI11"
cat > "${DEPS}/share/cmake/CLI11/CLI11Config.cmake" << 'EOF'
add_library(CLI11::CLI11 INTERFACE IMPORTED)
set_target_properties(CLI11::CLI11 PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../../../include"
)
EOF

echo "=== Done ==="
echo "Dependencies installed to: ${DEPS}"
echo ""
echo "Configure kawpowminer with:"
echo "  cmake .. -DHUNTER_ENABLED=OFF -DCMAKE_PREFIX_PATH=${DEPS}"
