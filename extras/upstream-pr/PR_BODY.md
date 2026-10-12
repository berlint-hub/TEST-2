# PR title

```
Add Ultrawide (21:9) aspect ratio option with automatic 21:9 patch application
```

# PR body (paste below)

## Description of Changes

This PR adds first-class ultrawide (21:9) support in three opt-in pieces:

1. **New aspect ratio option: `Ultrawide (21:9)`** (`AspectRatioType::R21_9`, ini name `"21:9"`)
   - Added to the Display tab combo box and to the aspect-ratio cycle hotkey.
   - Wired through `CalculateDrawDstRect()`, `GetCurrentAspectRatioFloat()` (display/capture) and the screenshot x-scale in `VMManager`.

2. **New toggle: `Apply Ultrawide (21:9) Patches`** (`EmuCore/EnableUltrawidePatches`)
   - Mirrors the existing `Apply Widescreen Patches` mechanism: name-based auto-activation of patch sections named exactly `Widescreen 21:9`.
   - Takes precedence over `Apply Widescreen Patches` when both are enabled, since 16:9 and 21:9 sections typically write the same addresses and would otherwise fight each other every vsync.
   - Per-game settings migrate the value into the per-game patch enable/disable lists, same as the WS/NI checkboxes do.

3. **Automatic 21:9 synthesis from existing 16:9 patches** (only when the new toggle is enabled)
   - When a game has a `Widescreen 16:9` section but no native `Widescreen 21:9` one, a 21:9 group is synthesized at patch load by rescaling only bit-recognizable aspect constants:
     - `0.75 -> 4/7` (x-compress), `0.5625 -> 9/21` (inverse AR), `16/9 -> 21/9` (AR), `4/3 -> 7/4` (x-stretch)
     - plus the MIPS `lui` pattern carrying the float's upper half in the immediate.
   - Strict whitelist: zoom/FOV/code values pass through unchanged; if nothing was rescaled the synthetic group is discarded entirely (no half-converted patches). Groups containing `bytes` commands or dynamic patches are skipped.
   - The synthesized group sets `override_aspect_ratio = 21/9`, so it also behaves correctly with `Auto 4:3/3:2`.

## Rationale

Ultrawide monitors are common now, and the widescreen patch archive already contains per-game geometry hacks whose constants rescale cleanly to 21:9 (the handful of hand-made 21:9 pnachs floating around do exactly this by hand). This makes the existing archive usable on 21:9 displays without duplicating hundreds of pnach files, while still preferring hand-tuned native `Widescreen 21:9` sections wherever they exist.

Default behavior is completely unchanged: both the aspect ratio option and the toggle are opt-in, and the synthesis only runs when the toggle is on.

## Known limitations

- Geometry culling tuned for the original frustum can cause edge pop-in in some titles at 21:9; that is inherent to widening beyond what the game renders and can only be fixed by hand-tuned patches (which this PR prefers when present).
- The synthesis whitelist intentionally covers only the common x-scale conventions; games with unconventional FOV code patches simply stay 16:9.

If the synthesis heuristic (item 3) is not wanted, I am happy to drop it and keep only the aspect ratio option and the name-based toggle, or split this into separate PRs.

## Testing

- Built with the CMake/MSVC (clang-cl, Ninja) Windows x64 configuration mirroring this repo's CI; no new warnings.
- Verified the constant conversion against the known-good hand-made 21:9 values for Enthusia Professional Racing (SLUS-20967, CRC 81D233DC): synthesized values match the hand-made ones (`0x3F400000 -> 0x3F124925` at `0x383708`/`0x383728`).
- Tested display geometry with `R21_9` selected (letterboxed on 16:9 displays, full-width on 21:9), screenshot aspect, and the AR cycle hotkey.

---

# How to submit (steps for the fork owner)

1. Fork https://github.com/PCSX2/pcsx2 in the browser (Fork button).
2. Locally:

   ```sh
   git clone https://github.com/<your-user>/pcsx2
   cd pcsx2
   git checkout -b ultrawide-21-9
   git apply /path/to/0001-pcsx2-ultrawide-21-9.patch
   git add -A
   git commit -m "Qt/GS/Patch: Add Ultrawide (21:9) aspect ratio and automatic 21:9 patch application"
   git push -u origin ultrawide-21-9
   ```

3. GitHub shows a "Compare & pull request" banner on your fork -- click it,
   use the title above and paste the body section.
