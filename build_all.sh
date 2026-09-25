#!/usr/bin/env bash
# VK-only bundle (nxvk). The switch-mesa OpenGL path was removed: the bundle
# ships a single emulator binary (NetherSX2_nx_vk.nro).
set -euo pipefail
export DEVKITPRO=${DEVKITPRO:-/opt/devkitpro}
export DEVKITARM=$DEVKITPRO/devkitARM
export DEVKITA64=$DEVKITPRO/devkitA64
JOBS=${JOBS:-18}
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "JOBS must be a positive integer." >&2; exit 1; }

APP="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$APP")"
CORES_DIR="${CORES_DIR:-$ROOT}"
# nxvk SDK: staged `switch/build/pkg` from PalindromicBreadLoaf/nxvk
# (include/vulkan/ + lib/libnvk.a + lib/libnvk_support.a). Empty =
# nxvk installed as a devkitPro portlib.
NXVK_SDK_ROOT="${NXVK_SDK_ROOT:-$APP/nxvk-sdk}"

# Use local patched core from repo root (uploaded as libemucore_PATCHED_4248.so)
LOCAL_CORE="$APP/libemucore_PATCHED_4248.so"
LOCAL_ASSETS="$APP/NetherSX2-v2.2n-4248/assets"
if [[ ! -f "$LOCAL_CORE" ]]; then
  echo "Missing local core: $LOCAL_CORE" >&2
  exit 1
fi
# GameIndex.yaml is required - try local, then fall back to extracting from tarball if provided
if [[ -d "$LOCAL_ASSETS" && -f "$LOCAL_ASSETS/GameIndex.yaml" ]]; then
  echo "Using local assets: $LOCAL_ASSETS"
else
  # Fallback: require tarball with assets
  if [[ -z "${CORES_TARBALL_URL:-}" ]]; then
    echo "No local assets and no CORES_TARBALL_URL provided" >&2
    exit 1
  fi
  mkdir -p "$APP/cores-in"
  curl -fL --retry 3 -o /tmp/cores.tgz "$CORES_TARBALL_URL"
  tar -xzf /tmp/cores.tgz -C "$APP/cores-in"
  LOCAL_ASSETS="$APP/cores-in/NetherSX2-v2.2n-4248/assets"
fi

required=(
  "$LOCAL_CORE"
  "$LOCAL_ASSETS/GameIndex.yaml"
)
if [[ -n "$NXVK_SDK_ROOT" ]]; then
  required+=(
    "$NXVK_SDK_ROOT/include/vulkan/vulkan_core.h"
    "$NXVK_SDK_ROOT/lib/libnvk.a"
    "$NXVK_SDK_ROOT/lib/libnvk_support.a"
  )
fi
for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "Missing build input: $file" >&2; exit 1; }
done
command -v cmake >/dev/null || { echo "cmake is required." >&2; exit 1; }
command -v ninja >/dev/null || { echo "ninja is required." >&2; exit 1; }

DEPS_BUILD="$APP/launcher/dependencies/build"
if [[ -f "$DEPS_BUILD/CMakeCache.txt" ]] &&
   ! grep -q '^CMAKE_GENERATOR:INTERNAL=Ninja$' "$DEPS_BUILD/CMakeCache.txt"; then
  cmake -E rm -rf "$DEPS_BUILD"
fi

echo "==== launcher storage dependencies ===="
deps_args=(
  -S "$APP/launcher/dependencies"
  -B "$DEPS_BUILD"
  -G Ninja
  -DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/Switch.cmake"
  -DCMAKE_BUILD_TYPE=Release
)
if [[ -n "${LIBSMB2_SOURCE:-}" ]]; then
  deps_args+=( -DFETCHCONTENT_SOURCE_DIR_LIBSMB2="$LIBSMB2_SOURCE" )
fi
if [[ -n "${LIBUSBHSFS_SOURCE:-}" ]]; then
  deps_args+=( -DFETCHCONTENT_SOURCE_DIR_LIBUSBHSFS="$LIBUSBHSFS_SOURCE" )
fi
cmake "${deps_args[@]}"
cmake --build "$DEPS_BUILD" --parallel "$JOBS"

echo "==== emulator: Vulkan (nxvk) ===="
cd "$APP"
export NXVK_SDK_ROOT
# TEMP debug phase: Vulkan call tracing to /switch/nethersx2/nethersx2-vulkan.log
# + Mesa log. Revert to unset once the black-screen issue is diagnosed.
export NETHERSX2_VK_DIAGNOSTIC=1
make clean >/dev/null 2>&1
make -j"$JOBS"
EMU_NRO="$(ls -t ./*.nro | head -n 1)"
cp -f "$EMU_NRO" NetherSX2_nx_vk.nro

echo "==== bundle single core + emulator binary into the launcher romfs ===="
mkdir -p "$APP/launcher/romfs/cores" "$APP/launcher/romfs/emu"
cp -f "$LOCAL_CORE" "$APP/launcher/romfs/cores/emucore_4248.so"
cp -f "$APP/NetherSX2_nx_vk.nro" "$APP/launcher/romfs/emu/NetherSX2_nx_vk.nro"

echo "==== bundle resources into the launcher romfs ===="
rd="$APP/launcher/romfs/res/4248"
rm -rf "$rd"; mkdir -p "$rd"
cp -rf "$LOCAL_ASSETS/." "$rd/"
rm -rf "$rd/dexopt"

echo "==== forwarder stub (built in-tree from launcher/fwd/) ===="
make -C "$APP/launcher/fwd" clean >/dev/null 2>&1
make -j"$JOBS" -C "$APP/launcher/fwd"

echo "==== launcher (SDL2 addon) ===="
cd "$APP/launcher"
make clean >/dev/null 2>&1
make -j"$JOBS"

mv -f "$APP/launcher/NetherSX2.nro" "$APP/NetherSX2.nro"
rm -f "$APP/NetherSX2_nx.nro" "$APP/NetherSX2_nx_vk.nro"

echo
echo "Done. The only file to copy:"
ls -la "$APP/NetherSX2.nro"
echo
echo "SD layout: sdmc:/switch/NetherSX2.nro + sdmc:/switch/nethersx2/"