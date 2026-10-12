# Where to post

Open: **https://github.com/PCSX2/pcsx2/issues/new?template=feature_request.yaml**

# Title

```
[Feature Request]: Ultrawide (21:9) aspect ratio option + automatic 21:9 widescreen patch application
```

---

# Field: Description

I'd like native ultrawide support, consisting of three opt-in pieces (working implementation attached below):

1. **New aspect ratio option `Ultrawide (21:9)`** in Graphics > Display (enum `R21_9`, ini value `"21:9"`), wired through the draw-rect calculation, display AR for capture, screenshot x-scale, and the AR cycle hotkey.

2. **New checkbox `Apply Ultrawide (21:9) Patches`** (`EmuCore/EnableUltrawidePatches`) next to `Apply Widescreen Patches`. It reuses the existing name-based auto-activation mechanism, matching patch sections named exactly `Widescreen 21:9`. When both checkboxes are on, 21:9 takes precedence, because 16:9/21:9 sections write the same addresses and would fight each other.

3. **Automatic 21:9 synthesis from existing 16:9 patches** (runs only when the new checkbox is enabled): when a game has a `Widescreen 16:9` section but no native 21:9 one, a `Widescreen 21:9` group is synthesized at patch load by rescaling only bit-recognizable aspect constants (`0.75 -> 4/7`, `0.5625 -> 9/21`, `16/9 -> 21/9`, `4/3 -> 7/4`, plus the MIPS `lui` upper-half pattern). Strict whitelist - zoom/FOV/code values pass through untouched, and if nothing was rescaled the synthetic group is discarded entirely. Hand-tuned native 21:9 sections always win.

Step by step, as a user:
1. Set Aspect Ratio to `Ultrawide (21:9)`.
2. Tick `Apply Ultrawide (21:9) Patches`.
3. Any game with a 21:9 pnach section - or with a convertible 16:9 one - renders in 21:9; everything else letterboxes as usual. Default behavior with both options off is completely unchanged.

Working patch against current master (0f71e66), build-tested with the CMake/clang-cl Windows CI configuration:
https://github.com/berlint-hub/TEST-2/blob/arena/7efa07ef-test-2/pc/0001-pcsx2-ultrawide-21-9.patch

I'm happy to open this as a PR (whole, split, or without item 3 if the heuristic is unwanted).

# Field: Reason

- Ultrawide monitors are common now, and PCSX2 only offers Stretch/4:3/16:9/10:7 - 21:9 users must distort the image or letterbox.
- The widescreen patch archive already contains the per-game geometry hacks needed; their constants rescale cleanly to 21:9 (the few hand-made 21:9 pnachs around do exactly this by hand). Item 3 makes the existing archive usable on 21:9 displays without duplicating hundreds of pnach files.
- `gsaspectratio=21:9` in pnach + Auto already displays correctly today, but there is no explicit display option and no auto-apply path like 16:9 has, so each game needs a hand-made pnach.

# Field: Examples

- Dolphin exposes arbitrary aspect ratios plus per-game widescreen codes.
- RPCS3 offers a 21:9 "Aspect ratio override".
- Verified on Enthusia Professional Racing (SLUS-20967, CRC 81D233DC): the synthesized values match the community hand-made 21:9 patch exactly (`0x3F400000 -> 0x3F124925` at `0x383708`/`0x383728`), rendering correct 21:9 geometry.
