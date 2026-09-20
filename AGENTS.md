# NetherSX2_nx fork (berlint-hub/TEST-2) — agent instructions

Upstream is NaGaa95/NetherSX2_nx. This fork lives at berlint-hub/TEST-2.
Work here, push `main` to `fork` (TEST-2). Keep `origin` as upstream reference.

## What this project is
- Switch port / wrapper of NetherSX2. Loads closed `libemucore.so` (4248 + 3668),
  patches it, runs inside minimal Android-like env. Ships as single `NetherSX2.nro`
  (cores + OpenGL + Vulkan/NVK), extracts to `/switch/nethersx2/.emu/` at launch.
- You improve the Switch wrapper only: SDL cover-art launcher, so-loader,
  Vulkan/NVK + LSFG, USB/SMB mounting, cheats (`/switch/nethersx2/cheats/<CRC>.pnach`),
  `build_all.sh`, devkitA64 CMake. NEVER modify `libemucore.so` itself.
- Constraints: no applet/album mode — needs full-memory game override (hold R on title).
  Toolchain `Switch.cmake`, devkitA64 + portlibs. MIT except `third_party/lsfg-vk` (GPL-3.0).

## How we work (Nemotron + Spark)
- `plan` agent = Nemotron (architect). Use it first for analysis: SDL launcher,
  USB/SMB mounting, L+R+Plus quick menu, cover loading. Output to `PLAN.md`
  with concrete steps, files, risks.
- `build` agent = Muse Spark (coder, default). Implements steps from `PLAN.md`
  in C++/CMake/libnx. Long agentic tasks OK, minimal tool calls.
- `fast` subagent = Nemotron Lightning for quick fixes: `build_all.sh`, CMake errors.
- Flow: plan writes/updates `PLAN.md` -> build implements step by step ->
  fast fixes build breaks. Don't skip planning for launcher/storage/Vulkan changes.

## Build
- Deps: `pacman -S devkitA64 switch-tools libnx switch-sdl2 switch-sdl2_ttf switch-sdl2_image switch-curl switch-mesa switch-libdrm_nouveau switch-ntfs-3g`, CMake, Ninja.
- Cores via sibling `NetherSX2-v2.2n-4248` / `-3668` or `CORES_DIR`, Mesa NVK under `vulkan/`.
- `./build_all.sh` (builds VK NRO + GL NRO + launcher -> `NetherSX2.nro`).
- SD layout: `sdmc:/switch/NetherSX2.nro` + `sdmc:/switch/nethersx2/bios/` (user BIOS).
