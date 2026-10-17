# libemucore-ci — vlastní `libemucore.so` přes GitHub Actions

**Odpověď na otázku „jde z PCSX2 postavit vlastní `libemucore.so` pro NetherSX2-classic?": ANO — ale ne z upstream PCSX2.** Správným zdrojem je **AetherSX2 LGPL drop** (PCSX2 fork s Android můstkem), který Tahlreth zveřejnil kvůli LGPL licenci. Tento repozitář kolem něj staví kompletní CI pipeline.

```
Trixarian/AetherSX2 (LGPL drop od Tahlretha)
  ├── aethersx2/                    # PCSX2 jádro + Android CMake build
  │     └── pcsx2/libAetherSX2.a    # uzavřená část (JNI můstek, Vulkan, kousky AArch64 recompileru)
  └── app-release-unsigned.apk      # kostra APK bez nativní knihovny
        │
        ▼  cmake + Android NDK (arm64-v8a, android-26, NDK r23b)
  libemucore.so                     ← přesně ta knihovna, kterou app načítá
        │
        ▼  zip -0 + zipalign -p 4 + apksigner
  NetherSX2-classic APK s vlastním jádrem
```

## Proč to nejde vzít z upstream PCSX2?

- Upstream [PCSX2/pcsx2](https://github.com/PCSX2/pcsx2) **nemá Android build target** (oficiálně desktop x86-64) a neobsahuje JNI rozhraní aplikace.
- NetherSX2-classic (stejně jako AetherSX2) zavádí knihovnu `libemucore.so` a volá JNI metody třídy **`xyz.aethersx2.android.NativeLibrary`** (33 nativních metod + `JNI_OnLoad`/`JNI_OnUnload`). Rozhraní je definované v uzavřeném `libAetherSX2.a`, který se při buildu jen přelinkuje (LGPL „re-linking" model) — výsledný `.so` tak má **garantovaně správné exporty** pro app.
- Chcete-li v app modernější jádro z PCSX2 2.x, je to samostatný velký projekt (přepsat JNI můstek a portovat jádro) — viz kapitola „Co dál".

## Obsah repozitáře

| soubor | popis |
|---|---|
| `.github/workflows/build-libemucore.yml` | GitHub Actions workflow (build + verifikace + volitelné zabalení APK) |
| `libemucore-ci/scripts/expected_exports.txt` | očekávané JNI exporty (vygenerováno z `libAetherSX2.a`) |
| `libemucore-ci/scripts/verify_so.py` | kontrola, že build produkuje korektní AArch64 `.so` s ABI shodným s app |
| `libemucore-ci/scripts/inject_and_sign.sh` | vložení `.so` do APK + zipalign + podpis (postup dle Tahlrethova README) |

## Jak sestavit

1. **GitHub → Actions → „Build libemucore.so" → Run workflow** (nebo: `gh workflow run "Build libemucore.so"`).
2. Vstupy (vše volitelné, výchozí hodnoty fungují):
   - `source_repo` / `source_ref` — odkud brát LGPL zdrojáky (default `Trixarian/AetherSX2@main`; lze pinovat na SHA pro reprodukovatelnost),
   - `build_type` — default `Release`,
   - `nethersx2_tag` — pokud vyplníte tag release v [Trixarian/NetherSX2-classic](https://github.com/Trixarian/NetherSX2-classic/releases) (např. `2.2n`), workflow navíc stáhne APK, vloží do něj váš core, podepíše a nahrát ho jako artifact.
3. Výsledek: artifact **`libemucore-so`** (a případně **`nethersx2-custom-core-apk`**).

Push do branchů `main`/`arena/**` se změnou těchto souborů buildne `.so` automaticky (bez repack kroku).

Poznámky k buildu (ověřeno na oficiálním dropu):
- Android větve CMake je soběstačná — všechny knihovny jsou vendorované v `3rdparty/`, host potřebuje jen CMake + NDK + ninja/make.
- Použitý NDK je pinované na **r23b (23.1.7779620)** — přesně konfigurace, se kterou Tahlreth ověřil reprodukovatelnost (jiná konfigurace nemá záruku funkčnosti).
- Submoduly se **neinicializují** — obsah je v repu přímo.
- Výstup je `build-android/pcsx2/libemucore.so` (`OUTPUT_NAME "emucore"`).

## Instalace APK s vlastním jádrem

APK je podepsané jiným klíčem než originál → **nejdřív odinstalujte** stávající NetherSX2-classic, pak nainstalujte artifact (uložené stavy jsou v `Android/data/...`, takže si je předem zazálohujte). Pro stabilní podpis vložte vlastní keystore (`KEYSTORE`/`KEYSTORE_PASS`/`KEY_ALIAS` v `inject_and_sign.sh`).

## Omezení a co je dobré vědět

1. **Starší vývojová linie.** LGPL drop odpovídá dřívějšímu kódu, než je build 3668/4248 v NetherSX2 — vlastní `.so` tedy není identické s originálem (méně fixů). **Vulkan renderer přítomen je** (zařízení `GSDeviceVK` je uvnitř `libAetherSX2.a`, i když zdrojáky GS Vulkanu v dropu nejsou).
2. **Anti-tamper / hex patche.** Patch skripty NetherSX2 (`Hackify.bat`) přepisují stock `.so` na pevných offsetech (kontrola podpisu APK, „BIOS type check") — ty platí jen pro originální binářky. V `libAetherSX2.a` (LGPL linie) jsem žádný kód kontroly podpisu APK nenašel (žádné PackageManager/cert řetězce), takže vlastní sestavené jádro ho nejspíš nemá a nepotřebuje patch. „BIOS type check" je v otevřeném `pcsx2/ps2/BiosTools.cpp` (`IsBIOS`) — pokud by bylo potřeba ho vypnout, patchuje se pohodlně přímo ve zdrojích.
3. **Licence.** Jádro je LGPL (přelinkování a vlastní build je v pořádku). Ne-LGPL části (uzavřený `libAetherSX2.a`, APK frontend) jsou pod **CC BY-NC-ND 4.0** — vlastní build pro osobní použití je v pohodě, ale **nepublikujte** upravené APK ani z toho nevydělávejte (Tahlrethova výslovná podmínka). BIOS/ROM soubory do repozitáře nepatří.
4. **Není to „novější PCSX2".** Postavené `.so` = AetherSX2 jádro (PCSX2 ~1.7 linie). Aktuální funkce z PCSX2 2.x v něm nejsou.

## Co dál (možná rozšíření)

- **Pinování commitu** `source_ref` na konkrétní SHA + cache pro opakované buildy.
- **Patch `BiosTools.cpp`** před buildem (odstranění BIOS restrikce místo hex patchování).
- **Port moderního PCSX2 jádra** — vyžaduje nový JNI můstek implementující `Java_xyz_aethersx2_android_NativeLibrary_*` (nebo rovnou nový frontend); podobnou věcí je projekt ARMSX2. Rozsahem je to ale samostatný projekt, ne „zabalení PCSX2 do .so".
- **Test na zařízení** — v CI lze doplnit krok s emulátorem, reálně ale stačí ruční instalace artifactu.

## Odkazy

- [Trixarian/AetherSX2](https://github.com/Trixarian/AetherSX2) — LGPL drop + oficiální build instrukce
- [Trixarian/NetherSX2-classic](https://github.com/Trixarian/NetherSX2-classic) — cílová app (AetherSX2 3668 + patche)
- [PCSX2/pcsx2](https://github.com/PCSX2/pcsx2) — upstream emulátor (desktop; zdroj jádra)
